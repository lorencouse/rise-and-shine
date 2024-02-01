//
//  AlarmManager.swift
//  Rise and Shine
//
//  Created by loren on 1/21/24.
//

import Foundation

    func calculateScheduleForSunData(_ sunDataArray: [SunData]) {
        var schedules = [AlarmSchedule]()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd h:mm:ss a"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")

        for sunData in sunDataArray {
            guard let sunriseDate = dateFormatter.date(from: "\(sunData.date) \(sunData.sunrise)") else {
                continue // Skip this entry if the date is invalid
            }
            guard let previousDate = Calendar.current.date(byAdding: .day, value: -1, to: sunriseDate) else {
                continue
            }
            let previousDateString = formattedDateString(date: previousDate)

            let userDefaults = UserDefaults.standard
            let alarmOffset = (userDefaults.wakeUpOffsetHours * 60) + userDefaults.wakeUpOffsetMinutes
            let adjustedAlarmOffset = userDefaults.beforeSunrise ? -alarmOffset : alarmOffset

            guard let alarmTime = Calendar.current.date(byAdding: .minute, value: adjustedAlarmOffset, to: sunriseDate),
                  let bedTime = Calendar.current.date(byAdding: .hour, value: -userDefaults.targetHoursOfSleep, to: alarmTime),
                  let windDownTime = Calendar.current.date(byAdding: .minute, value: -userDefaults.windDownTime, to: bedTime) else {
                continue // Skip this entry if calculation fails
            }

            let schedule = AlarmSchedule(date: previousDateString,
                                         sunriseTime: sunData.sunrise,
                                           alarmTime: dateFormatter.string(from: alarmTime),
                                           bedTime: dateFormatter.string(from: bedTime),
                                           windDownTime: dateFormatter.string(from: windDownTime))
            schedules.append(schedule)
        }

        
//      Write schedule to JSON file
        
        AppDataManager.saveDataToFile(data: schedules, fileName: Constants.alarmDataFileName)

    }


    


