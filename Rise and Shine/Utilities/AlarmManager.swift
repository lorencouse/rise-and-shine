//
//  AlarmManager.swift
//  Rise and Shine
//
//  Created by loren on 1/21/24.
//

import Foundation


    
    func calculateAlarmTime() {
        let userDefaults = UserDefaults.standard
        let alarmOffset = userDefaults.wakeUpOffsetMinutes + (userDefaults.wakeUpOffsetHours * 60)
        let beforeSunrise = userDefaults.beforeSunrise
        
        
        if let sunData: [SunData] = APIManager.loadSunDataFromFile() {
            
            // Step 1: Convert sunriseTime string to Date
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "h:mm:ss a"
            dateFormatter.locale = Locale(identifier: "en_US_POSIX") // Set the locale to ensure proper parsing
            
            guard let sunriseDate = dateFormatter.date(from: sunData[0].sunrise) else {
                fatalError("Invalid date format for sunriseTime")
            }
            
            // Calculate and store the alarm time
            let adjustedAlarmOffset = beforeSunrise ? -alarmOffset : alarmOffset
            guard let alarmTime = Calendar.current.date(byAdding: .minute, value: adjustedAlarmOffset, to: sunriseDate) else {
                fatalError("Error calculating alarm time")
            }
            
            guard let bedTime = Calendar.current.date(byAdding: .hour, value: -userDefaults.targetHoursOfSleep, to: alarmTime) else {
                fatalError("Error calculating bed time")
            }
            
            guard let windDownTimer = Calendar.current.date(byAdding: .minute, value: -userDefaults.windDownTime, to: bedTime) else {
                fatalError("Error calculating bed time")
            }
            
            userDefaults.alarmTime = dateFormatter.string(from: alarmTime)
            userDefaults.bedTime = dateFormatter.string(from: bedTime)
            userDefaults.windDownTimeReminder = dateFormatter.string(from: windDownTimer)
        }
        else {
            userDefaults.alarmTime = "No sunrise data."
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


    


