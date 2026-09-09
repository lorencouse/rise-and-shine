import Foundation
import SwiftUI
import RiseCore

/// The single source of truth for the UI. Owns settings, the computed plan and the
/// services that mirror the plan into the system.
@Observable
final class AppModel {

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

    private let store = SharedStore.shared
    private var syncTask: Task<Void, Never>?

    // MARK: Init

    init(settings: AlarmSettings? = nil) {
        self.settings = settings ?? SharedStore.shared.loadSettings() ?? AlarmSettings()
        recompute()
    }

    // MARK: Derived

    var today: PlannedDay? {
        let key = DateKey(date: .now)
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
        let start = Calendar.current.startOfDay(for: .now)
        return plan.filter { $0.date.startOfDay() >= start }
    }

    var hasLocation: Bool { settings.location != nil }

    /// A preview of what the alarm would be for a given day under hypothetical settings.
    /// Used by onboarding and settings screens for live feedback.
    func preview(_ candidate: AlarmSettings, on date: Date = .now) -> PlannedDay? {
        guard let loc = candidate.location else { return nil }
        let day = SolarCalculator.solarDay(for: date, latitude: loc.latitude, longitude: loc.longitude)
        return AlarmPlanner.plan(settings: candidate, day: day)
    }

    // MARK: Actions

    /// Full refresh: update device location if following, recompute, sync with the system.
    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }

        if settings.location?.followsDevice ?? false {
            if let fresh = try? await location.currentLocation() {
                if fresh != settings.location { settings.location = fresh }
            }
        }
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

    func setLocation(_ location: SavedLocation) {
        settings.location = location
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
        await reminders.cancelAll()
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

    private func recompute() {
        guard let loc = settings.location else {
            plan = []
            return
        }
        // Start from yesterday so "tonight" and a bedtime that already passed still render.
        let start = Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now
        let days = SolarCalculator.solarDays(from: start,
                                             count: settings.horizonDays + 1,
                                             latitude: loc.latitude,
                                             longitude: loc.longitude)
        plan = AlarmPlanner.plan(settings: settings, days: days)
        try? store.save(plan, to: AppGroup.planFile)
        scheduleSync()
    }

    private func persistSettings() {
        do { try store.save(settings, to: AppGroup.settingsFile) } catch { lastError = error.localizedDescription }
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
        lastError = alarms.lastSyncError
        WidgetRefresher.reload()
    }
}
