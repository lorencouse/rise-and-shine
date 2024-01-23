//
//  AlarmManager.swift
//  Rise and Shine
//
//  Created by loren on 1/21/24.
//

import Foundation


    
    func calculateAlarmTime(sunriseTime: String) {
        let alarmOffsetMinutes = UserDefaults.standard.wakeUpOffsetMinutes
        let alarmOffsetHours = UserDefaults.standard.wakeUpOffsetHours
        let beforeSunrise = UserDefaults.standard.beforeSunrise
        var alarmOffset = alarmOffsetMinutes + (alarmOffsetHours * 60)
        alarmOffset = beforeSunrise ? -alarmOffset : alarmOffset
        
        
        
        // Step 1: Convert sunriseTime string to Date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "h:mm:ss a"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX") // Set the locale to ensure proper parsing
        
        guard let sunriseDate = dateFormatter.date(from: sunriseTime) else {
            fatalError("Invalid date format for sunriseTime")
        }
        
        // Step 2: Add alarmOffsetMinutes to get alarm time
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

    func calculateBedTime(sunriseTimeNextDay: String, hoursOfSleep: Int) {
        // Step 1: Convert sunriseTime string to Date datatype
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "h:mm:ss a"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        guard let sunriseAsDate = dateFormatter.date(from: sunriseTimeNextDay) else {
            // Handle invalid date format gracefully
            return
        }
        
        // Step 2: Subtract hours of sleep from converted Date
        if let bedTime = Calendar.current.date(byAdding: .hour, value: -hoursOfSleep, to: sunriseAsDate) {
            UserDefaults.standard.bedTime = "\(bedTime)"
        } else {
            // Handle error if unable to calculate sleep time
            return
        }
    }
