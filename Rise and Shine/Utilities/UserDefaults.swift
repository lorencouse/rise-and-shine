//
//  UserDefaults.swift
//  Rise and Shine
//
//  Created by loren on 1/18/24.
//

import Foundation
import SwiftUI

extension UserDefaults {
    // Keys
    private enum Keys {
        static let wakeUpOffsetHours = "wakeUpOffsetHours"
        static let wakeUpOffsetMinutes = "wakeUpOffsetMinutes"
        static let beforeSunrise = "beforeSunrise"
        static let targetHoursOfSleep = "targetHoursOfSleep"
        static let windDownTime = "windDownTime"
        static let currentLongitude = "currentLongitude"
        static let currentLatitude = "currentLatitude"
        static let currentCity = "currentCity"
        static let bedTime = "bedTime"
        static let alarmTime = "alarmTime"
        // Add other keys as needed
    }

    // Properties
    var wakeUpOffsetHours: Int {
        get { integer(forKey: Keys.wakeUpOffsetHours) }
        set { set(newValue, forKey: Keys.wakeUpOffsetHours) }
    }

    var wakeUpOffsetMinutes: Int {
        get { integer(forKey: Keys.wakeUpOffsetMinutes) }
        set { set(newValue, forKey: Keys.wakeUpOffsetMinutes) }
    }

    var beforeSunrise: Bool {
        get { bool(forKey: Keys.beforeSunrise) }
        set { set(newValue, forKey: Keys.beforeSunrise) }
    }

    var targetHoursOfSleep: Int {
        get { integer(forKey: Keys.targetHoursOfSleep) }
        set { set(newValue, forKey: Keys.targetHoursOfSleep) }
    }

    var windDownTime: Int {
        get { integer(forKey: Keys.windDownTime) }
        set { set(newValue, forKey: Keys.windDownTime) }
    }
    
    var currentLongitude: Double {
        get { double(forKey: Keys.currentLongitude) }
        set { set(newValue, forKey: Keys.currentLongitude) }
    }
    
    var currentLatitude: Double {
        get { double(forKey: Keys.currentLatitude) }
        set { set(newValue, forKey: Keys.currentLatitude) }
    }
    
    var currentCity: String {
        get { string(forKey: Keys.currentCity) ?? "Default City" }
        set { set(newValue, forKey: Keys.currentCity) }
    }
    
    var bedTime: String {
        get { string(forKey: Keys.bedTime) ?? "12:00" }
        set { set(newValue, forKey: Keys.bedTime) }
    }

    
    static func binding<T>(key: String, defaultValue: T) -> Binding<T> where T: Codable {
        Binding(
            get: {
                if let data = UserDefaults.standard.data(forKey: key),
                   let value = try? JSONDecoder().decode(T.self, from: data) {
                    return value
                }
                return defaultValue
            },
            set: {
                if let data = try? JSONEncoder().encode($0) {
                    UserDefaults.standard.set(data, forKey: key)
                }
            }
        )
    }

    // Add other properties as needed
}
