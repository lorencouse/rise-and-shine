import Foundation
import UserNotifications
import RiseCore

/// Wind-down and bedtime reminders. These are ordinary (time-sensitive) notifications,
/// not alarms: they should respect a Sleep Focus that the user has deliberately turned on.
@Observable
final class ReminderScheduler {

    enum Authorization: Equatable { case notDetermined, authorized, denied }

    private(set) var authorization: Authorization = .notDetermined
    private let center = UNUserNotificationCenter.current()

    private static let windDownPrefix = "winddown-"
    private static let bedtimePrefix = "bedtime-"

    func refreshAuthorization() async {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: authorization = .authorized
        case .denied: authorization = .denied
        case .notDetermined: authorization = .notDetermined
        @unknown default: authorization = .notDetermined
        }
    }

    @discardableResult
    func requestAuthorization() async -> Authorization {
        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound, .timeSensitive])
        } catch {
            // fall through to refresh
        }
        await refreshAuthorization()
        return authorization
    }

    /// Replaces all reminders with the ones implied by `plan`.
    func sync(plan: [PlannedDay], settings: AlarmSettings) async {
        let pending = await center.pendingNotificationRequests()
        let ours = pending.map(\.identifier).filter {
            $0.hasPrefix(Self.windDownPrefix) || $0.hasPrefix(Self.bedtimePrefix)
        }
        center.removePendingNotificationRequests(withIdentifiers: ours)

        await refreshAuthorization()
        guard settings.remindersEnabled, authorization == .authorized else { return }

        let now = Date()
        let sleepGoal = Formatters.duration(minutes: settings.sleepGoalMinutes)

        for day in plan where day.isActive {
            guard let bedtime = day.bedtime, let windDown = day.windDownTime, let alarm = day.alarmTime else { continue }
            let key = day.date.description

            if windDown > now {
                let content = UNMutableNotificationContent()
                content.title = "Time to wind down"
                content.body = "Bed in \(settings.windDownMinutes) min to get \(sleepGoal) before your \(Formatters.time(alarm, in: settings.timeZone)) sunrise alarm."
                content.sound = .default
                content.interruptionLevel = .timeSensitive
                content.threadIdentifier = "sleep"
                schedule(id: Self.windDownPrefix + key, content: content, at: windDown, calendar: settings.calendar)
            }

            if bedtime > now {
                let content = UNMutableNotificationContent()
                content.title = "Bedtime"
                content.body = "Lights out now for \(sleepGoal) of sleep. Alarm at \(Formatters.time(alarm, in: settings.timeZone))."
                content.sound = .default
                content.interruptionLevel = .timeSensitive
                content.threadIdentifier = "sleep"
                schedule(id: Self.bedtimePrefix + key, content: content, at: bedtime, calendar: settings.calendar)
            }
        }
    }

    /// The trigger carries the location's zone explicitly. Without one, iOS evaluates the
    /// components in whatever zone the phone is in when the time comes, so a reminder set
    /// in Denver would fire at Lisbon wall-clock time after a flight.
    private func schedule(id: String, content: UNNotificationContent, at date: Date, calendar: Calendar) {
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        components.timeZone = calendar.timeZone
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    /// One-off "your alarm moved" notice after the followed location changed zone. Posted
    /// only when notifications are already allowed; a permission prompt mid-trip would be
    /// worse than silence.
    func postTravelNotice(from old: SavedLocation, to new: SavedLocation, nextAlarm: Date?, zone: TimeZone) async {
        await refreshAuthorization()
        guard authorization == .authorized else { return }
        let content = UNMutableNotificationContent()
        content.title = "Alarm updated for \(new.name)"
        if let nextAlarm {
            content.body = "Sunrise here is different. Your next alarm is \(Formatters.time(nextAlarm, in: zone)) local time."
        } else {
            content.body = "Sunrise here is different, so your alarm times have been recalculated."
        }
        content.sound = nil
        content.threadIdentifier = "travel"
        try? await center.add(UNNotificationRequest(identifier: "travel-\(new.name)", content: content, trigger: nil))
    }

    func cancelAll() async {
        let pending = await center.pendingNotificationRequests()
        let ours = pending.map(\.identifier).filter {
            $0.hasPrefix(Self.windDownPrefix) || $0.hasPrefix(Self.bedtimePrefix)
        }
        center.removePendingNotificationRequests(withIdentifiers: ours)
    }
}
