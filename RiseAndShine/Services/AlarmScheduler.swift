import Foundation
@preconcurrency import AlarmKit
import ActivityKit
import SwiftUI
import RiseCore

/// Keeps the system's AlarmKit alarms in sync with the computed plan.
///
/// One fixed-date alarm is scheduled per active morning inside the horizon. The mapping
/// from day to alarm UUID is persisted so stale alarms can be cancelled after settings
/// or location change. Alarms live in the system, so they survive app termination
/// and device restarts; the app only needs to run occasionally to extend the horizon.
@Observable
final class AlarmScheduler {

    enum Authorization: Equatable {
        case notDetermined, authorized, denied
    }

    private(set) var authorization: Authorization = .notDetermined
    private(set) var lastSyncError: String?
    private(set) var scheduledCount = 0

    /// The one-off test alarm, kept out of the day registry so a routine sync doesn't
    /// cancel it as "unwanted" before it gets a chance to ring.
    private var testAlarmID: UUID? {
        get { store.load(UUID.self, from: AppGroup.testAlarmFile) }
        set {
            if let newValue { try? store.save(newValue, to: AppGroup.testAlarmFile) } else { store.delete(AppGroup.testAlarmFile) }
        }
    }

    /// Ids handed to `manager.schedule` but not yet recorded in `registry`/`testAlarmID`.
    /// The orphan sweep treats them as tracked so an overlapping sync can't cancel them.
    @ObservationIgnored private var inFlightIDs: Set<UUID> = []

    private let manager = AlarmManager.shared
    private let store = SharedStore.shared

    /// Day key → scheduled alarm id.
    private var registry: [String: UUID] {
        get { store.load([String: UUID].self, from: AppGroup.alarmRegistryFile) ?? [:] }
        set { try? store.save(newValue, to: AppGroup.alarmRegistryFile) }
    }

    /// Day key → when that day's alarm was set for. AlarmKit drops a stopped alarm and its
    /// schedule with it, so this is what lets a morning no transition was seen for still
    /// be recorded. Holds only days the registry holds.
    private var mornings: [String: ScheduledMorning] {
        get { store.load([String: ScheduledMorning].self, from: AppGroup.scheduledMorningsFile) ?? [:] }
        set { try? store.save(newValue, to: AppGroup.scheduledMorningsFile) }
    }

    /// Alarms iOS still knows about, refreshed from `alarmUpdates`. `nil` until the first
    /// update arrives.
    private(set) var liveAlarms: [UUID: Alarm]?

    /// What happened on past mornings, derived from alarm state transitions.
    private(set) var history: WakeHistory = SharedStore.shared.load(WakeHistory.self, from: AppGroup.wakeHistoryFile) ?? WakeHistory()

    /// Fired whenever history changes here, so it can be mirrored outward — to iCloud
    /// and to the watch. History used to reach the watch only when a *setting* changed,
    /// which meant a morning could sit unmirrored for days.
    var onHistoryChanged: ((WakeHistory) -> Void)?
    private var updatesTask: Task<Void, Never>?

    init() {
        refreshAuthorization()
        observeUpdates()
    }

    /// iOS removes a fixed-date alarm once the user stops it, and tells us through
    /// `alarmUpdates`. Mirroring that keeps the registry honest without a full sync, and
    /// is the hook a wake history will hang off later.
    private func observeUpdates() {
        updatesTask?.cancel()
        updatesTask = Task { [weak self] in
            for await alarms in AlarmManager.shared.alarmUpdates {
                guard let self, !Task.isCancelled else { return }
                self.apply(alarms)
            }
        }
    }

    private func apply(_ alarms: [Alarm]) {
        let previous = liveAlarms
        liveAlarms = Dictionary(alarms.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        record(previous: previous, current: liveAlarms ?? [:])
        var registry = registry
        var mornings = mornings
        let before = (registry, mornings)
        remember(liveAlarms ?? [:], registry: registry, in: &mornings)
        // Before the registry forgets them: these are the alarms that went without a trace.
        recordUnobserved(mornings, registry: registry, live: liveAlarms ?? [:])
        registry = registry.filter { liveAlarms?[$0.value] != nil }
        mornings = mornings.filter { registry[$0.key] != nil }
        if registry != before.0 {
            self.registry = registry
            scheduledCount = registry.count
        }
        if mornings != before.1 { self.mornings = mornings }
        if let id = testAlarmID, liveAlarms?[id] == nil {
            testAlarmID = nil
        }
    }

    /// Turns state transitions of our day alarms into wake records. Only the transitions
    /// carry information: an alarm that is simply "scheduled" says nothing yet.
    /// AlarmKit's state, in the vocabulary `WakeHistory` understands. `nil` means the
    /// alarm is not in that snapshot: not scheduled yet, or gone because it was stopped.
    private func phase(_ state: Alarm.State?) -> AlarmPhase {
        switch state {
        case .scheduled: .scheduled
        case .countdown: .countdown
        case .alerting: .alerting
        case .paused: .paused
        default: .absent
        }
    }

    private func record(previous: [UUID: Alarm]?, current: [UUID: Alarm]) {
        guard let previous else { return }   // first snapshot: nothing to compare against
        let now = Date()
        var history = history
        var changed = false

        for (key, id) in registry {
            guard let day = DateKey(string: key) else { continue }
            let before = previous[id]?.state
            let after = current[id]?.state

            // Fire date for a new record.
            func scheduledDate() -> Date {
                if case .fixed(let d)? = (current[id] ?? previous[id])?.schedule { return d }
                return now
            }

            // When the alarm alerted, which is not when we noticed. `alarmUpdates` only
            // delivers while the app runs, and the user is asleep when the alarm fires:
            // the transition is usually first seen at the next launch, so stamping `now`
            // recorded the launch time as the ring time. AlarmKit alerts exactly on the
            // schedule, so derive it instead — plus the pre-alarm countdown, which the
            // schedule is deliberately shifted earlier by (see `scheduleDate(for:)`).
            func rangDate() -> Date {
                let alarm = current[id] ?? previous[id]
                guard case .fixed(let d)? = alarm?.schedule else { return now }
                return d.addingTimeInterval(alarm?.countdownDuration?.preAlert ?? 0)
            }

            if history.record(from: phase(before), to: phase(after), day: day,
                              scheduled: scheduledDate(), rangAt: rangDate(), now: now) {
                changed = true
            }

        }

        if changed {
            let cutoff = DateKey(date: now.addingTimeInterval(-Double(WakeHistory.retentionDays) * 86_400))
            history.prune(before: cutoff)
            persist(history)
        }
    }

    /// Fills in when each tracked alarm is set for, from the alarms themselves. `sync` notes
    /// it on scheduling; this covers alarms scheduled before that was kept.
    private func remember(_ alarms: [UUID: Alarm], registry: [String: UUID], in mornings: inout [String: ScheduledMorning]) {
        for (key, id) in registry where mornings[key] == nil {
            guard let alarm = alarms[id], case .fixed(let d)? = alarm.schedule else { continue }
            mornings[key] = ScheduledMorning(scheduled: d, alertsAt: d.addingTimeInterval(alarm.countdownDuration?.preAlert ?? 0))
        }
    }

    /// Records the mornings `record` cannot: the alarm rang and was stopped, then AlarmKit
    /// dropped it before any snapshot saw it go, because the app was not running. It rang
    /// on schedule; when it was stopped is unknown.
    private func recordUnobserved(_ mornings: [String: ScheduledMorning], registry: [String: UUID], live: [UUID: Alarm]) {
        var tracked: [DateKey: ScheduledMorning] = [:]
        var liveDays: Set<DateKey> = []
        for (key, id) in registry {
            guard let day = DateKey(string: key), let morning = mornings[key] else { continue }
            tracked[day] = morning
            if live[id] != nil { liveDays.insert(day) }
        }
        let now = Date()
        var history = history
        guard history.recordUnobserved(tracked, live: liveDays, now: now) else { return }
        let cutoff = DateKey(date: now.addingTimeInterval(-Double(WakeHistory.retentionDays) * 86_400))
        history.prune(before: cutoff)
        persist(history)
    }

    /// Replace history with a copy merged elsewhere (iCloud). Not `record`'s job: this
    /// is adoption of an outside truth, not an observation of this device's alarms.
    func adopt(_ merged: WakeHistory) {
        guard merged != history else { return }
        history = merged
        try? store.save(merged, to: AppGroup.wakeHistoryFile)
    }

    private func persist(_ new: WakeHistory) {
        history = new
        try? store.save(new, to: AppGroup.wakeHistoryFile)
        onHistoryChanged?(new)
    }

    /// Attach a Health sleep figure to a completed record.
    func setSleep(_ minutes: Int, for day: DateKey) {
        guard var record = history[day], record.sleepMinutes != minutes else { return }
        record.sleepMinutes = minutes
        var updated = history
        updated[day] = record
        persist(updated)
    }

    func clearHistory() {
        history = WakeHistory()
        store.delete(AppGroup.wakeHistoryFile)
        onHistoryCleared?()
    }

    /// Separate from `onHistoryChanged` because a clear must propagate as a clear: a
    /// pushed empty history would just be merged away by the next device to sync.
    var onHistoryCleared: (() -> Void)?

    enum LiveState: Equatable { case ringing, snoozing, paused }

    /// What one of our alarms is doing right now, if anything. Lets Home say "ringing" or
    /// "snoozing" instead of pointing at the next morning as if nothing happened.
    var liveState: LiveState? {
        guard let liveAlarms else { return nil }
        let ours = Set(registry.values).union(testAlarmID.map { [$0] } ?? [])
        for alarm in liveAlarms.values where ours.contains(alarm.id) {
            switch alarm.state {
            case .alerting: return .ringing
            case .countdown: return .snoozing
            case .paused: return .paused
            default: continue
            }
        }
        return nil
    }

    func refreshAuthorization() {
        authorization = map(manager.authorizationState)
    }

    @discardableResult
    func requestAuthorization() async -> Authorization {
        do {
            let state = try await manager.requestAuthorization()
            authorization = map(state)
        } catch {
            lastSyncError = error.localizedDescription
        }
        return authorization
    }

    private func map(_ state: AlarmManager.AuthorizationState) -> Authorization {
        switch state {
        case .authorized: .authorized
        case .denied: .denied
        case .notDetermined: .notDetermined
        @unknown default: .notDetermined
        }
    }

    /// Reconciles system alarms with `plan`. Safe to call often; it only touches alarms
    /// whose time changed, plus orphans no registry entry tracks.
    func sync(plan: [PlannedDay], settings: AlarmSettings) async {
        refreshAuthorization()
        guard authorization == .authorized else { return }

        var registry = registry
        var mornings = mornings
        var errors: [String] = []
        var scheduled: Set<UUID> = []
        defer { inFlightIDs.subtract(scheduled) }

        // What the system currently has, keyed by id.
        let existing: [UUID: Alarm]
        do {
            existing = Dictionary(uniqueKeysWithValues: try manager.alarms.map { ($0.id, $0) })
        } catch {
            lastSyncError = error.localizedDescription
            return
        }

        remember(existing, registry: registry, in: &mornings)
        recordUnobserved(mornings, registry: registry, live: existing)

        let now = Date()
        let wanted = plan.filter { $0.isActive && ($0.alarmTime ?? .distantPast) > now }
        let wantedKeys = Set(wanted.map { $0.date.description })

        // 1. Cancel alarms for days no longer wanted (skipped, weekday off, past, out of horizon).
        for (key, id) in registry where !wantedKeys.contains(key) {
            if existing[id] != nil {
                do { try manager.cancel(id: id) } catch { errors.append("cancel \(key): \(error.localizedDescription)") }
            }
            registry.removeValue(forKey: key)
            mornings.removeValue(forKey: key)
        }

        // 1b. Cancel orphans: alarms the system holds that no registry entry points at. They
        // appear when the registry is lost (an App Group change, a failed save) and would
        // otherwise ring alongside the fresh set with no way to cancel them from the app.
        errors += cancelOrphans(in: existing.keys, keeping: registry)

        // 2. Schedule or reschedule the wanted ones.
        for day in wanted {
            // No sunrise is not a reason to skip: in polar night the clamp still yields a
            // fire date and the plan calls the day active, so the alarm has to exist.
            guard let fireDate = day.alarmTime else { continue }
            let key = day.date.description

            if let id = registry[key], let alarm = existing[id],
               case .fixed(let date)? = alarm.schedule,
               abs(date.timeIntervalSince(scheduleDate(for: fireDate, settings: settings))) < 1 {
                continue // unchanged
            }

            if let old = registry[key], existing[old] != nil {
                try? manager.cancel(id: old)
            }

            let id = UUID()
            scheduled.insert(id)
            inFlightIDs.insert(id)
            do {
                let configuration = makeConfiguration(fireDate: fireDate, day: day, settings: settings)
                _ = try await manager.schedule(id: id, configuration: configuration)
                registry[key] = id
                mornings[key] = ScheduledMorning(scheduled: scheduleDate(for: fireDate, settings: settings), alertsAt: fireDate)
            } catch {
                errors.append("schedule \(key): \(error.localizedDescription)")
            }
        }

        self.registry = registry
        self.mornings = mornings.filter { registry[$0.key] != nil }
        scheduledCount = registry.count
        lastSyncError = errors.isEmpty ? nil : errors.joined(separator: "\n")
    }

    /// Removes every alarm this app owns.
    func cancelAll() {
        for (_, id) in registry { try? manager.cancel(id: id) }
        registry = [:]
        mornings = [:]
        scheduledCount = 0
        cancelTest()
        if let alarms = try? manager.alarms {
            _ = cancelOrphans(in: alarms.map(\.id), keeping: [:])
        }
    }

    /// Cancels every alarm in `ids` that is not in `registry`, the test alarm, or `inFlightIDs`.
    /// `AlarmManager` only reports this app's alarms, so anything untracked is ours and lost.
    private func cancelOrphans(in ids: some Sequence<UUID>, keeping registry: [String: UUID]) -> [String] {
        let tracked = Set(registry.values).union([testAlarmID].compactMap { $0 }).union(inFlightIDs)
        var errors: [String] = []
        for id in ids where !tracked.contains(id) {
            do { try manager.cancel(id: id) } catch { errors.append("cancel orphan \(id): \(error.localizedDescription)") }
        }
        return errors
    }

    func cancelTest() {
        if let id = testAlarmID { try? manager.cancel(id: id) }
        testAlarmID = nil
    }

    /// Fires a one-off alarm shortly, so the user can hear the sound and see the alert.
    func scheduleTest(in seconds: TimeInterval = 10, settings: AlarmSettings) async throws {
        guard await requestAuthorization() == .authorized else { return }
        // With a pre-alarm countdown on, the test starts that countdown now and rings when
        // it ends, which is also how to verify the countdown semantics on a device.
        let preAlert = TimeInterval(max(settings.preAlarmMinutes, 0) * 60)
        let fire = Date().addingTimeInterval(seconds + preAlert)
        let metadata = SunriseAlarmMetadata(dateKey: "test", sunrise: fire,
                                            offsetDescription: "Test alarm",
                                            locationName: settings.location?.name ?? "",
                                            alarmTime: fire)
        let configuration = makeConfiguration(fireDate: fire, metadata: metadata, title: "Test alarm", settings: settings)
        cancelTest()
        let id = UUID()
        inFlightIDs.insert(id)
        defer { inFlightIDs.remove(id) }
        _ = try await manager.schedule(id: id, configuration: configuration)
        testAlarmID = id
    }

    // MARK: - Configuration

    /// The instant handed to AlarmKit for an alarm that should alert at `fireDate`.
    private func scheduleDate(for fireDate: Date, settings: AlarmSettings) -> Date {
        guard settings.preAlarmMinutes > 0 else { return fireDate }
        return fireDate.addingTimeInterval(-TimeInterval(settings.preAlarmMinutes * 60))
    }

    private func makeConfiguration(fireDate: Date, day: PlannedDay, settings: AlarmSettings) -> AlarmManager.AlarmConfiguration<SunriseAlarmMetadata> {
        let sunrise = day.solar.sunrise ?? day.solar.civilDawn
        let metadata = SunriseAlarmMetadata(
            dateKey: day.date.description,
            sunrise: sunrise,
            offsetDescription: day.isOverridden ? "Custom time" : day.wasClamped ? "Clamped to your wake window" : settings.profile(for: day.date, calendar: settings.calendar).offsetDescription,
            locationName: settings.location?.name ?? "",
            alarmTime: fireDate
        )
        let title = sunrise.map { "Sunrise at \(Formatters.time($0, in: settings.timeZone))" } ?? "Rise and Shine"
        return makeConfiguration(fireDate: fireDate, metadata: metadata, title: title, settings: settings)
    }

    private func makeConfiguration(fireDate: Date, metadata: SunriseAlarmMetadata, title: String, settings: AlarmSettings) -> AlarmManager.AlarmConfiguration<SunriseAlarmMetadata> {
        let stop = AlarmButton(text: "Stop", textColor: .white, systemImageName: "stop.fill")
        let snooze = AlarmButton(text: "Snooze", textColor: .white, systemImageName: "zzz")

        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: title),
            stopButton: stop,
            secondaryButton: snooze,
            secondaryButtonBehavior: .countdown
        )
        // One title serves both the snooze countdown and the pre-alarm countdown.
        let countdown = AlarmPresentation.Countdown(
            title: "Until alarm",
            pauseButton: AlarmButton(text: "Pause", textColor: .white, systemImageName: "pause.fill")
        )
        let paused = AlarmPresentation.Paused(
            title: "Paused",
            resumeButton: AlarmButton(text: "Resume", textColor: .white, systemImageName: "play.fill")
        )
        let presentation = AlarmPresentation(alert: alert, countdown: countdown, paused: paused)

        let attributes = AlarmAttributes<SunriseAlarmMetadata>(
            presentation: presentation,
            metadata: metadata,
            tintColor: Theme.sunrise
        )

        let sound: AlertConfiguration.AlertSound = settings.soundFile.isEmpty ? .default : .named(settings.soundFile)

        // Pre-alarm: AlarmKit starts the `preAlert` countdown when the schedule fires and
        // alerts when it ends, so the schedule is moved earlier by the same amount and the
        // alert still lands on `fireDate`. (Verify on device: see TODO.)
        let preAlert: TimeInterval? = settings.preAlarmMinutes > 0 ? TimeInterval(settings.preAlarmMinutes * 60) : nil
        return AlarmManager.AlarmConfiguration(
            countdownDuration: Alarm.CountdownDuration(preAlert: preAlert, postAlert: TimeInterval(settings.snoozeMinutes * 60)),
            schedule: .fixed(scheduleDate(for: fireDate, settings: settings)),
            attributes: attributes,
            sound: sound
        )
    }
}
