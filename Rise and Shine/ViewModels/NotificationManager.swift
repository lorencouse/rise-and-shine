//
//  NotificationManager.swift
//  Rise and Shine
//
//  Created by loren on 1/18/24.
//

import Foundation
import UserNotifications
import EventKit

class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    private static let notificationCenter = UNUserNotificationCenter.current()
    private static let eventStore = EKEventStore() // Now static

    override init() {
        super.init()
        Self.notificationCenter.delegate = self // Access static property with Self
        setupNotificationCategories()
    }

    private func setupNotificationCategories() {
        let snoozeAction = UNNotificationAction(identifier: "SNOOZE_ACTION",
                                                title: "Snooze",
                                                options: [])
        let category = UNNotificationCategory(identifier: "ALARM_CATEGORY",
                                              actions: [snoozeAction],
                                              intentIdentifiers: [],
                                              options: [])
        Self.notificationCenter.setNotificationCategories([category])
    }

    static func scheduleNotification(at date: Date, title: String, body: String, soundName: String? = nil, identifier: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.categoryIdentifier = "ALARM_CATEGORY"
        if let soundName = soundName {
            content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: soundName))
        } else {
            content.sound = UNNotificationSound.default
        }

        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            }
        }
    }
    
    static func addEventToCalendar(title: String, startDate: Date, alarmOffset: TimeInterval, soundName: String, completion: @escaping (Bool, Error?) -> Void) {
        eventStore.requestAccess(to: .event) { granted, error in
            guard granted, error == nil else {
                DispatchQueue.main.async {
                    completion(false, error)
                }
                return
            }
            
            let event = EKEvent(eventStore: eventStore)
            event.title = title
            event.startDate = startDate
            event.endDate = startDate.addingTimeInterval(60 * 60) // For example, 1 hour long event
            event.calendar = eventStore.defaultCalendarForNewEvents
            
            let alarm = EKAlarm(relativeOffset: alarmOffset)
            event.alarms = [alarm]

            do {
                try eventStore.save(event, span: .thisEvent, commit: true)
                DispatchQueue.main.async {
                    completion(true, nil)
                }
            } catch {
                DispatchQueue.main.async {
                    completion(false, error)
                }
            }
        }
    }
    static func cancelAllScheduledNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        print("All Notifications Cleared")
    }
    
    static func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Error requesting notification authorization: \(error)")
                return
            }

            if granted {
                print("Notification permission granted.")
            } else {
                print("Notification permission denied.")
            }
        }
    }
    
    static func fetchScheduledNotifications(completion: @escaping ([UNNotificationRequest]) -> Void) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            completion(requests)
        }
    }
    
    
    

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let actionIdentifier = response.actionIdentifier
        
        if actionIdentifier == "SNOOZE_ACTION" {
            // Handle snooze action
            if let trigger = response.notification.request.trigger as? UNCalendarNotificationTrigger,
               let date = Calendar.current.date(from: trigger.dateComponents) {
                let snoozeDate = Date(timeInterval: 300, since: date) // 5 minutes snooze

                let soundName = UserDefaults.standard.alarmSound

                let snoozeIdentifier = UUID().uuidString

                NotificationManager.scheduleNotification(at: snoozeDate, title: response.notification.request.content.title, body: response.notification.request.content.body, soundName: soundName, identifier: snoozeIdentifier)
            }
        }

        completionHandler()
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Present the notification while the app is in the foreground.
        completionHandler([.banner, .sound])
    }
}


func scheduleAlarmNotifications(schedules: [AlarmSchedule]) {
    NotificationManager.cancelAllScheduledNotifications()
    
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "your_date_format_here"
    
    let sleepGoalHoursString = "\(UserDefaults.standard.integer(forKey: "targetHoursOfSleep")) hours"

    for schedule in schedules.prefix(15) {
        guard let windDownDate = dateFormatter.date(from: schedule.windDownTime),
              let bedTime = dateFormatter.date(from: schedule.bedTime),
              let alarmTime = dateFormatter.date(from: schedule.alarmTime) else { continue }

        let alarmSoundName = UserDefaults.standard.string(forKey: "alarmSound") ?? "defaultSound.mp3"

        // Schedule simple notifications for windDownDate and bedTime
        NotificationManager.scheduleNotification(at: windDownDate, title: "Time to start winding down.", body: "Go to bed in \(UserDefaults.standard.integer(forKey: "windDownTime")) minutes to reach your goal of \(sleepGoalHoursString) of sleep.", soundName: alarmSoundName, identifier: "windDownNotification")
        NotificationManager.scheduleNotification(at: bedTime, title: "Time for bed.", body: "Go to bed now to reach your \(sleepGoalHoursString) of sleep goal.", soundName: alarmSoundName, identifier: "bedTimeNotification")
        
        // Add calendar event for alarmTime
        NotificationManager.addEventToCalendar(title: "Rise and Shine!", startDate: alarmTime, alarmOffset: -5 * 60, soundName: alarmSoundName) { success, error in
            DispatchQueue.main.async {
                if success {
                    print("Alarm event successfully added to the calendar.")
                } else if let error = error {
                    // Handle the error, e.g., by showing an alert to the user
                    print("Failed to add alarm event to the calendar: \(error.localizedDescription)")
                }
            }
        }
    }
}

