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

    private let manager = AlarmManager.shared
    private let store = SharedStore.shared

    /// Day key → scheduled alarm id.
    private var registry: [String: UUID] {
        get { store.load([String: UUID].self, from: AppGroup.alarmRegistryFile) ?? [:] }
        set { try? store.save(newValue, to: AppGroup.alarmRegistryFile) }
    }

    init() {
        refreshAuthorization()
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
    /// whose time changed.
    func sync(plan: [PlannedDay], settings: AlarmSettings) async {
        refreshAuthorization()
        guard authorization == .authorized else { return }

        var registry = registry
        var errors: [String] = []

        // What the system currently has, keyed by id.
        let existing: [UUID: Alarm]
        do {
            existing = Dictionary(uniqueKeysWithValues: try manager.alarms.map { ($0.id, $0) })
        } catch {
            lastSyncError = error.localizedDescription
            return
        }

        let now = Date()
        let wanted = plan.filter { $0.isActive && ($0.alarmTime ?? .distantPast) > now }
        let wantedKeys = Set(wanted.map { $0.date.description })

        // 1. Cancel alarms for days no longer wanted (skipped, weekday off, past, out of horizon).
        for (key, id) in registry where !wantedKeys.contains(key) {
            if existing[id] != nil {
                do { try manager.cancel(id: id) } catch { errors.append("cancel \(key): \(error.localizedDescription)") }
            }
            registry.removeValue(forKey: key)
        }

        // 2. Schedule or reschedule the wanted ones.
        for day in wanted {
            guard let fireDate = day.alarmTime, let sunrise = day.solar.sunrise ?? day.solar.civilDawn else { continue }
            let key = day.date.description

            if let id = registry[key], let alarm = existing[id],
               case .fixed(let date)? = alarm.schedule,
               abs(date.timeIntervalSince(fireDate)) < 1 {
                continue // unchanged
            }

            if let old = registry[key], existing[old] != nil {
                try? manager.cancel(id: old)
            }

            let id = UUID()
            do {
                let configuration = makeConfiguration(fireDate: fireDate, sunrise: sunrise, day: day, settings: settings)
                _ = try await manager.schedule(id: id, configuration: configuration)
                registry[key] = id
            } catch {
                errors.append("schedule \(key): \(error.localizedDescription)")
            }
        }

        self.registry = registry
        scheduledCount = registry.count
        lastSyncError = errors.isEmpty ? nil : errors.joined(separator: "\n")
    }

    /// Removes every alarm this app owns.
    func cancelAll() {
        for (_, id) in registry { try? manager.cancel(id: id) }
        registry = [:]
        scheduledCount = 0
    }

    /// Fires a one-off alarm shortly, so the user can hear the sound and see the alert.
    func scheduleTest(in seconds: TimeInterval = 10, settings: AlarmSettings) async throws {
        guard await requestAuthorization() == .authorized else { return }
        let fire = Date().addingTimeInterval(seconds)
        let metadata = SunriseAlarmMetadata(dateKey: "test", sunrise: fire,
                                            offsetDescription: "Test alarm",
                                            locationName: settings.location?.name ?? "")
        let configuration = makeConfiguration(fireDate: fire, metadata: metadata, title: "Test alarm", settings: settings)
        _ = try await manager.schedule(id: UUID(), configuration: configuration)
    }

    // MARK: - Configuration

    private func makeConfiguration(fireDate: Date, sunrise: Date, day: PlannedDay, settings: AlarmSettings) -> AlarmManager.AlarmConfiguration<SunriseAlarmMetadata> {
        let metadata = SunriseAlarmMetadata(
            dateKey: day.date.description,
            sunrise: sunrise,
            offsetDescription: day.wasClamped ? "Clamped to your wake window" : settings.offsetDescription,
            locationName: settings.location?.name ?? ""
        )
        let title = "Sunrise at \(Formatters.time(sunrise))"
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
        let countdown = AlarmPresentation.Countdown(
            title: "Snoozing",
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

        return AlarmManager.AlarmConfiguration(
            countdownDuration: Alarm.CountdownDuration(preAlert: nil, postAlert: TimeInterval(settings.snoozeMinutes * 60)),
            schedule: .fixed(fireDate),
            attributes: attributes,
            sound: sound
        )
    }
}
