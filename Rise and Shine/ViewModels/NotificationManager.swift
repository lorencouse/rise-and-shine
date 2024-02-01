//
//  NotificationManager.swift
//  Rise and Shine
//
//  Created by loren on 1/18/24.
//

import Foundation
import UserNotifications

class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    private let notificationCenter = UNUserNotificationCenter.current()

    static func scheduleNotification(at date: Date, title: String, body: String, soundName: String? = nil) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        if let soundName = soundName {
            content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: soundName))
        }

        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
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
                // Handle the error here.
                print("Error requesting notification authorization: \(error)")
                return
            }

            if granted {
                // Permission was granted.
                print("Notification permission granted.")
            } else {
                // Permission was not granted.
                print("Notification permission denied.")
            }
        }
    }
    
    static func fetchScheduledNotifications(completion: @escaping ([UNNotificationRequest]) -> Void) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            completion(requests)
        }
    }

}

