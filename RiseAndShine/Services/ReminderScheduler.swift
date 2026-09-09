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
                schedule(id: Self.windDownPrefix + key, content: content, at: windDown)
            }

            if bedtime > now {
                let content = UNMutableNotificationContent()
                content.title = "Bedtime"
                content.body = "Lights out now for \(sleepGoal) of sleep. Alarm at \(Formatters.time(alarm, in: settings.timeZone))."
                content.sound = .default
                content.interruptionLevel = .timeSensitive
                content.threadIdentifier = "sleep"
                schedule(id: Self.bedtimePrefix + key, content: content, at: bedtime)
            }
        }
    }

    private func schedule(id: String, content: UNNotificationContent, at date: Date) {
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    func cancelAll() async {
        let pending = await center.pendingNotificationRequests()
        let ours = pending.map(\.identifier).filter {
            $0.hasPrefix(Self.windDownPrefix) || $0.hasPrefix(Self.bedtimePrefix)
        }
        center.removePendingNotificationRequests(withIdentifiers: ours)
    }
}
