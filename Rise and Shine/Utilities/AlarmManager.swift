//
//  AlarmManager.swift
//  Rise and Shine
//
//  Created by loren on 1/21/24.
//

import Foundation


    
    func calculateAlarmTime() {
        let userDefaults = UserDefaults.standard
        let alarmOffsetMinutes = userDefaults.wakeUpOffsetMinutes
        let alarmOffsetHours = userDefaults.wakeUpOffsetHours
        var alarmOffset = alarmOffsetMinutes + (alarmOffsetHours * 60)
        let beforeSunrise = userDefaults.beforeSunrise
        let sunriseTimeArray = userDefaults.stringArray(forKey: "sunriseTimeArray") ?? []
        let sunriseTime = sunriseTimeArray[0]
        alarmOffset = beforeSunrise ? -alarmOffset : alarmOffset
        
        // Step 1: Convert sunriseTime string to Date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "h:mm:ss a"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX") // Set the locale to ensure proper parsing
        
        guard let sunriseDate = dateFormatter.date(from: sunriseTime) else {
            fatalError("Invalid date format for sunriseTime")
        }
        
        // Step 2: Add alarmOffsetMinutes to get alarm time
        let calendar = Calendar.current
        print("sunriseTime in String \(sunriseTime)")

        // Format the sunriseDate to String before printing
        let formattedSunriseTime = dateFormatter.string(from: sunriseDate)
        print("\(formattedSunriseTime)")
        if let alarmTime = calendar.date(byAdding: .minute, value: alarmOffset, to: sunriseDate) {
            let formattedAlarmTime = dateFormatter.string(from: alarmTime)
            UserDefaults.standard.alarmTime = "\(formattedAlarmTime)"
            print("\(UserDefaults.standard.alarmTime)")
        } else {
            fatalError("Error calculating alarm time")
        }
    }

    func calculateTime(for key: String, adjustment: TimeAdjustment, resultKey: String) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "h:mm:ss a"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")

        guard let timeString = UserDefaults.standard.string(forKey: key),
              let time = dateFormatter.date(from: timeString) else {
            fatalError("Invalid time string for key \(key).")
        }

        let adjustedTime: Date?
        switch adjustment {
        case .hour(let value):
            adjustedTime = Calendar.current.date(byAdding: .hour, value: -value, to: time)
        case .minute(let value):
            adjustedTime = Calendar.current.date(byAdding: .minute, value: -value, to: time)
        }

        if let adjustedTime = adjustedTime {
            let formattedTime = dateFormatter.string(from: adjustedTime)
            UserDefaults.standard.set(formattedTime, forKey: resultKey)
        } else {
            // Handle error if unable to calculate adjusted time
        }
    }

    enum TimeAdjustment {
        case hour(Int)
        case minute(Int)
    }


    


