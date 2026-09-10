import Foundation
import EventKit
import RiseCore

/// Opt-in mirror of the plan into Calendar: one "Sleep" event per active night, from bedtime
/// to the alarm, in a calendar of its own so it can be hidden or deleted wholesale. Full
/// access is needed because write-only access cannot find an event again to move or
/// remove it, and a sunrise alarm moves every day.
@Observable
final class CalendarSync {

    enum Authorization: Equatable { case notDetermined, authorized, denied }

    private(set) var authorization: Authorization = .notDetermined
    private(set) var lastError: String?

    private let store = EKEventStore()
    private let shared = SharedStore.shared
    private static let calendarTitle = "Rise and Shine"

    /// Day key → event identifier, so events can be updated in place and removed.
    private var registry: [String: String] {
        get { shared.load([String: String].self, from: AppGroup.calendarRegistryFile) ?? [:] }
        set { try? shared.save(newValue, to: AppGroup.calendarRegistryFile) }
    }

    init() { refreshAuthorization() }

    func refreshAuthorization() {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: authorization = .authorized
        case .denied, .restricted, .writeOnly: authorization = .denied
        case .notDetermined: authorization = .notDetermined
        @unknown default: authorization = .notDetermined
        }
    }

    @discardableResult
    func requestAuthorization() async -> Authorization {
        do { _ = try await store.requestFullAccessToEvents() } catch { lastError = error.localizedDescription }
        refreshAuthorization()
        return authorization
    }

    /// Reconcile events with the plan. With the feature off, removes everything we made.
    func sync(plan: [PlannedDay], settings: AlarmSettings) {
        refreshAuthorization()
        var registry = registry

        guard settings.calendarEventsEnabled, authorization == .authorized else {
            if !registry.isEmpty, authorization == .authorized {
                for (_, id) in registry { remove(id) }
                try? store.commit()
            }
            if authorization == .authorized || !settings.calendarEventsEnabled { self.registry = [:] }
            return
        }

        guard let calendar = ourCalendar() else { return }
        let now = Date()
        let wanted = plan.filter { $0.isActive && ($0.alarmTime ?? .distantPast) > now && $0.bedtime != nil }
        let wantedKeys = Set(wanted.map { $0.date.description })

        for (key, id) in registry where !wantedKeys.contains(key) {
            remove(id)
            registry.removeValue(forKey: key)
        }

        for day in wanted {
            guard let alarm = day.alarmTime, let bedtime = day.bedtime else { continue }
            let key = day.date.description
            let event = registry[key].flatMap { store.event(withIdentifier: $0) } ?? EKEvent(eventStore: store)
            event.calendar = calendar
            event.title = "Sleep · alarm \(Formatters.time(alarm, in: settings.timeZone))"
            event.startDate = bedtime
            event.endDate = alarm
            event.timeZone = settings.timeZone
            event.availability = .free
            event.notes = day.solar.sunrise.map { "Sunrise \(Formatters.time($0, in: settings.timeZone)). \(settings.offsetDescription)." }
            event.alarms = nil   // the app has its own reminders; don't double up
            do {
                try store.save(event, span: .thisEvent, commit: false)
                if let id = event.eventIdentifier { registry[key] = id }
            } catch {
                lastError = error.localizedDescription
            }
        }

        do { try store.commit() } catch { lastError = error.localizedDescription }
        self.registry = registry
    }

    func removeAll() {
        guard authorization == .authorized else { registry = [:]; return }
        for (_, id) in registry { remove(id) }
        try? store.commit()
        registry = [:]
    }

    // MARK: Internals

    private func remove(_ identifier: String) {
        guard let event = store.event(withIdentifier: identifier) else { return }
        try? store.remove(event, span: .thisEvent, commit: false)
    }

    /// Our own calendar, created on first use in the same account as the user's default.
    private func ourCalendar() -> EKCalendar? {
        if let existing = store.calendars(for: .event).first(where: { $0.title == Self.calendarTitle }) {
            return existing
        }
        let calendar = EKCalendar(for: .event, eventStore: store)
        calendar.title = Self.calendarTitle
        calendar.cgColor = CGColor(red: 0.98, green: 0.62, blue: 0.24, alpha: 1)
        guard let source = store.defaultCalendarForNewEvents?.source
            ?? store.sources.first(where: { $0.sourceType == .calDAV })
            ?? store.sources.first(where: { $0.sourceType == .local }) else { return nil }
        calendar.source = source
        do {
            try store.saveCalendar(calendar, commit: true)
            return calendar
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }
}
