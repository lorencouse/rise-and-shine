import Foundation
import SwiftUI
import RiseCore

/// The single source of truth for the UI. Owns settings, the computed plan and the
/// services that mirror the plan into the system.
@Observable
final class AppModel {

    /// One instance for the process. The App owns it for the UI; App Intents, which run
    /// in this process without a scene, reach the same object here.
    static let shared = AppModel()

    // MARK: State

    var settings: AlarmSettings {
        didSet {
            guard settings != oldValue else { return }
            persistSettings()
            recompute()
        }
    }

    private(set) var plan: [PlannedDay] = []
    private(set) var isRefreshing = false
    private(set) var lastError: String?

    let alarms = AlarmScheduler()
    let reminders = ReminderScheduler()
    let location = LocationService()
    let calendar = CalendarSync()
    let health = HealthService()

    /// Minutes slept last night per Health, when enabled and available.
    private(set) var lastNightSleepMinutes: Int?

    private let store = SharedStore.shared
    private let cloud = CloudSettings()
    private var cloudHistory: CloudHistory?
    private var syncTask: Task<Void, Never>?

    // MARK: Init

    init(settings: AlarmSettings? = nil) {
        // Local file first; iCloud only fills in when this device has nothing of its own.
        let local = settings ?? SharedStore.shared.loadSettings()
        self.settings = local ?? cloud.remote()?.settings ?? AlarmSettings()
        recompute()
        // History syncs on its own key with its own rule: merged per morning, because
        // two devices usually hold different halves of the same one.
        let history = CloudHistory(local: { [weak self] in self?.alarms.history ?? WakeHistory() })
        cloudHistory = history
        history.onRemoteChange = { [weak self] merged in
            self?.alarms.adopt(merged)
            self?.mirrorHistory(merged)
        }
        alarms.onHistoryChanged = { [weak self] new in
            history.push(new)
            self?.mirrorHistory(new)
        }
        alarms.onHistoryCleared = { [weak self] in
            history.pushCleared()
            self?.mirrorHistory(WakeHistory())
        }
        history.reconcile()

        cloud.onRemoteChange = { [weak self] remote in
            guard let self else { return }
            // Keep this device's own location fix; take everything else from the other device.
            var merged = remote
            if let mine = self.settings.location, mine.followsDevice { merged.location = mine }
            self.applyingRemote = true
            self.settings = merged
            self.applyingRemote = false
        }
    }

    /// True while a remote change is being applied, so it isn't pushed straight back.
    private var applyingRemote = false

    // MARK: Derived

    /// The zone every displayed time belongs to: the location's, not the phone's.
    var timeZone: TimeZone { settings.timeZone }

    /// True when the phone's clock disagrees with the location's, so the UI can say so.
    var timeZoneDiffersFromDevice: Bool {
        timeZone.secondsFromGMT() != TimeZone.current.secondsFromGMT()
    }

    var today: PlannedDay? {
        let key = DateKey(date: .now, calendar: settings.calendar)
        return plan.first { $0.date == key }
    }

    var nextAlarm: PlannedDay? {
        AlarmPlanner.nextAlarm(in: plan, after: .now)
    }

    /// The evening plan to show right now: tonight's bedtime if it's still ahead,
    /// otherwise tomorrow night's.
    var tonight: PlannedDay? {
        plan.first { ($0.bedtime ?? .distantPast) > .now && $0.isActive }
    }

    var upcoming: [PlannedDay] {
        let calendar = settings.calendar
        let start = calendar.startOfDay(for: .now)
        return plan.filter { $0.date.startOfDay(in: calendar) >= start }
    }

    var hasLocation: Bool { settings.location != nil }

    /// Upcoming days the user has skipped, for the "skipped days" list.
    var skippedUpcoming: [PlannedDay] {
        upcoming.filter { $0.status == .skipped }
    }

    /// Upcoming mornings pinned to a fixed time.
    var overriddenUpcoming: [PlannedDay] {
        upcoming.filter { $0.isOverridden && $0.status == .active }
    }

    /// True when every remaining day in the horizon is paused, so Home can say why.
    var isFullyPaused: Bool {
        guard let until = settings.pausedUntil else { return false }
        return until > DateKey(date: .now, calendar: settings.calendar).adding(days: settings.horizonDays, in: settings.calendar)
    }

    /// The alarm marker to draw on today's arc: only while it's still ahead of us.
    var alarmMarkerForToday: Date? {
        guard let today, let t = today.alarmTime, t > .now else { return nil }
        return t
    }

    /// The stretch where a phone on the nightstand is a clock, not a phone: from an hour
    /// before you would need to be asleep, through to the end of the sunrise glow.
    /// Nightstand mode offers itself only inside it, so plugging in at lunchtime does
    /// nothing. Reckoned backwards from the next alarm rather than from tonight's
    /// bedtime, because after midnight tonight's bedtime has already passed and
    /// `tonight` has rolled on to the next evening.
    var isNightWindow: Bool {
        guard let alarm = nextAlarm?.alarmTime else { return false }
        let now = Date.now
        let opens = alarm.addingTimeInterval(-Double(settings.sleepGoalMinutes + 60) * 60)
        let closes = alarm.addingTimeInterval(Double(SunriseGlow.holdMinutes) * 60)
        return now >= opens && now <= closes
    }

    /// Today in the location's calendar.
    var todayKey: DateKey { DateKey(date: .now, calendar: settings.calendar) }

    /// The plan for any day, not just the scheduled horizon. Days inside the horizon come
    /// from `plan` (so they carry the real status); others are computed on the spot, which
    /// is what lets Home page back into last week or forward past the horizon.
    func plannedDay(for key: DateKey) -> PlannedDay? {
        if let cached = plan.first(where: { $0.date == key }) { return cached }
        guard let loc = settings.location else { return nil }
        let day = SolarCalculator.solarDay(for: key, latitude: loc.latitude, longitude: loc.longitude, timeZone: settings.timeZone)
        return AlarmPlanner.plan(settings: settings, day: day, calendar: settings.calendar)
    }

    /// "+2 min of daylight since yesterday" — the reason a sunrise alarm moves at all.
    var daylightDrift: String? { daylightDrift(for: todayKey) }

    /// Same, relative to the day before `key`.
    func daylightDrift(for key: DateKey) -> String? {
        let calendar = settings.calendar
        guard let day = plannedDay(for: key)?.solar.dayLength,
              let previous = plannedDay(for: key.adding(days: -1, in: calendar))?.solar.dayLength
        else { return nil }
        let deltaMinutes = Int(((day - previous) / 60).rounded())
        let than = key == todayKey ? "than yesterday" : "than the day before"
        guard deltaMinutes != 0 else { return "Same daylight \(than)" }
        let word = deltaMinutes > 0 ? "more" : "less"
        return "\(abs(deltaMinutes)) min \(word) daylight \(than)"
    }

    /// A preview of what the alarm would be for a given day under hypothetical settings.
    /// Used by onboarding and settings screens for live feedback.
    func preview(_ candidate: AlarmSettings, on date: Date = .now) -> PlannedDay? {
        guard let loc = candidate.location else { return nil }
        let day = SolarCalculator.solarDay(for: date,
                                           latitude: loc.latitude,
                                           longitude: loc.longitude,
                                           timeZone: candidate.timeZone)
        return AlarmPlanner.plan(settings: candidate, day: day, calendar: candidate.calendar)
    }

    // MARK: Actions

    /// Full refresh: update device location if following, recompute, sync with the system.
    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }

        if settings.location?.followsDevice ?? false {
            if let fresh = try? await location.currentLocation() {
                let old = settings.location
                if old?.isMeaningfullyDifferent(from: fresh) ?? true {
                    settings.location = fresh
                    // Crossing into a new zone is the one move worth telling the user about:
                    // it's when the alarm silently jumps by an hour or more.
                    if let old, old.timeZoneIdentifier != nil, old.timeZoneIdentifier != fresh.timeZoneIdentifier {
                        await reminders.postTravelNotice(from: old, to: fresh,
                                                         nextAlarm: nextAlarm?.alarmTime, zone: settings.timeZone)
                    }
                }
            }
        }
        await backfillTimeZone()
        cloudHistory?.reconcile()
        pruneSkippedDays()
        await refreshSleep()
        recompute()
        await syncNow()
        BackgroundRefresh.scheduleNext()
    }

    func toggleSkip(_ day: PlannedDay) {
        if settings.skippedDays.contains(day.date) {
            settings.skippedDays.remove(day.date)
        } else {
            settings.skippedDays.insert(day.date)
        }
    }

    /// Skip the next active morning and push the change to the system straight away.
    /// Used by Siri and the widget, which don't stick around for the debounce.
    func skipNext() async {
        guard let next = nextAlarm else { return }
        settings.skippedDays.insert(next.date)
        await flushSync()
    }

    func setOverride(_ day: DateKey, time: ClockTime) {
        settings.dayOverrides[day] = time
        settings.skippedDays.remove(day)   // a time set by hand means "do ring"
    }

    func clearOverride(_ day: DateKey) {
        settings.dayOverrides.removeValue(forKey: day)
    }

    func setLocation(_ location: SavedLocation) {
        settings.location = location
        if !location.followsDevice { settings.remember(location) }
    }

    func forgetPlace(_ place: SavedLocation) {
        settings.savedPlaces.removeAll { $0 == place }
    }

    func useDeviceLocation() async throws {
        let fresh = try await location.currentLocation()
        settings.location = fresh
    }

    func completeOnboarding() async {
        settings.onboardingCompleted = true
        await refresh()
    }

    func resetEverything() async {
        alarms.cancelAll()
        alarms.clearHistory()
        await reminders.cancelAll()
        calendar.removeAll()
        store.delete(AppGroup.planFile)
        store.delete(AppGroup.alarmRegistryFile)
        settings = AlarmSettings()
    }

    func testAlarm() async {
        do {
            try await alarms.scheduleTest(settings: settings)
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Available sound files bundled with the app.
    var availableSounds: [String] {
        (Bundle.main.urls(forResourcesWithExtension: "caf", subdirectory: nil) ?? [])
            .map(\.lastPathComponent)
            .sorted()
    }

    // MARK: Internals

    /// Locations saved before `timeZoneIdentifier` existed fall back to the device zone,
    /// which is wrong the moment the two differ. Resolve it once, in the background.
    private func backfillTimeZone() async {
        guard let loc = settings.location, loc.timeZoneIdentifier == nil else { return }
        guard let identifier = await location.timeZoneIdentifier(latitude: loc.latitude,
                                                                 longitude: loc.longitude) else { return }
        settings.location?.timeZoneIdentifier = identifier
    }

    /// Pull last night's sleep and fill in any completed wake records that lack one. Health
    /// is only asked for nights that already ended, so the numbers never change under the
    /// user during the day.
    func refreshSleep() async {
        guard settings.healthSleepEnabled else { lastNightSleepMinutes = nil; return }
        health.refreshAuthorization()
        guard health.authorization == .authorized else { lastNightSleepMinutes = nil; return }

        // Last night: ended at this morning's alarm if it has rung, else at "now" if it's
        // past a plausible wake time; otherwise the previous morning.
        let calendar = settings.calendar
        let today = todayKey
        let wakeEnd: Date
        if let t = plannedDay(for: today)?.alarmTime, t <= .now {
            wakeEnd = t
        } else if calendar.component(.hour, from: .now) >= 10 {
            wakeEnd = .now
        } else {
            wakeEnd = plannedDay(for: today.adding(days: -1, in: calendar))?.alarmTime
                ?? calendar.date(bySettingHour: 8, minute: 0, second: 0, of: today.adding(days: -1, in: calendar).startOfDay(in: calendar))
                ?? .now
        }
        lastNightSleepMinutes = await health.sleepForNight(endingAt: wakeEnd)

        for record in alarms.history.completed where record.sleepMinutes == nil {
            guard let stopped = record.stopped else { continue }
            if let minutes = await health.sleepForNight(endingAt: record.rang ?? stopped) {
                alarms.setSleep(minutes, for: record.date)
            }
        }
    }

    /// Skips are one-off, so once the morning has passed they are just clutter in the
    /// settings file. Drop everything before today in the location's calendar.
    private func pruneSkippedDays() {
        let today = DateKey(date: .now, calendar: settings.calendar)
        let stale = settings.skippedDays.filter { $0 < today }
        let staleOverrides = settings.dayOverrides.keys.filter { $0 < today }
        let pauseOver = settings.pausedUntil.map { $0 <= today } ?? false
        guard !stale.isEmpty || !staleOverrides.isEmpty || pauseOver else { return }
        settings.skippedDays.subtract(stale)
        for key in staleOverrides { settings.dayOverrides.removeValue(forKey: key) }
        if pauseOver { settings.pausedUntil = nil }
    }

    private func recompute() {
        guard let loc = settings.location else {
            plan = []
            return
        }
        // Everything is reckoned in the location's zone, not the phone's: "sunrise", the
        // wake window and the active weekdays are all statements about where you wake up.
        let calendar = settings.calendar
        // Start from yesterday so "tonight" and a bedtime that already passed still render.
        let start = calendar.date(byAdding: .day, value: -1, to: .now) ?? .now
        let days = SolarCalculator.solarDays(from: start,
                                             count: settings.horizonDays + 1,
                                             latitude: loc.latitude,
                                             longitude: loc.longitude,
                                             timeZone: settings.timeZone)
        plan = AlarmPlanner.plan(settings: settings, days: days, calendar: calendar)
        try? store.save(plan, to: AppGroup.planFile)
        scheduleSync()
    }

    private func persistSettings() {
        do { try store.save(settings, to: AppGroup.settingsFile) } catch { lastError = error.localizedDescription }
        if !applyingRemote { cloud.push(settings) }
        WatchBridge.shared.push(settings: settings, history: alarms.history)
    }

    /// A history change has to reach the watch and the widgets too. Previously only a
    /// *settings* save pushed history, so a morning could sit unmirrored for days.
    private func mirrorHistory(_ history: WakeHistory) {
        WatchBridge.shared.push(settings: settings, history: history)
        WidgetRefresher.reload()
    }

    /// Runs the pending sync now instead of after the debounce. For callers that end
    /// before the debounce would fire: an intent's `perform`, the background task.
    func flushSync() async {
        syncTask?.cancel()
        syncTask = nil
        await syncNow()
    }

    /// Debounced system sync so rapid picker changes don't hammer AlarmKit.
    private func scheduleSync() {
        syncTask?.cancel()
        syncTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            await self?.syncNow()
        }
    }

    private func syncNow() async {
        guard settings.onboardingCompleted else { return }
        await alarms.sync(plan: plan, settings: settings)
        await reminders.sync(plan: plan, settings: settings)
        calendar.sync(plan: plan, settings: settings)
        lastError = alarms.lastSyncError ?? calendar.lastError
        WidgetRefresher.reload()
    }
}
