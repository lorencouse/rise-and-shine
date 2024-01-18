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

    func requestNotificationAuthorization() {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            // Handle authorization response
        }
    }

    func scheduleNotification(title: String, body: String, dateComponents: DateComponents) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        notificationCenter.add(request) { error in
            // Handle request completion
        }
    }
}
