//
//  CalandarManager.swift
//  Rise and Shine
//
//  Created by Loren Couse on 2024/2/15.
//

import Foundation
import EventKit
import UIKit

class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var eventStore = EKEventStore()
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Other setup code
        
        return true
    }
    
    func requestCalendarAccessIfNeeded() {
        eventStore.requestAccess(to: .event) { (granted, error) in
            DispatchQueue.main.async {
                if granted {
                    // Access was granted
                    print("Calendar access granted")
                } else {
                    // Access was denied or an error occurred
                    print("Calendar access denied or error occurred: \(String(describing: error))")
                }
            }
        }
    }
}


