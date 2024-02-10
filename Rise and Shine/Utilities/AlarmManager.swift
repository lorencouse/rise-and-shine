//
//  AlarmManager.swift
//  Rise and Shine
//
//  Created by loren on 1/21/24.
//

import Foundation

    func calculateAlarms(_ sunDataArray: [SunData]) {
        var schedules = [AlarmSchedule]()
        let dateFormatter = DateFormatter.dateAndTime
 

        for sunData in sunDataArray {
            guard let sunriseDate = dateFormatter.date(from: "\(sunData.date) \(sunData.sunrise)"),
                  let previousDate = Calendar.current.date(byAdding: .day, value: -1, to: sunriseDate) else {
                continue }
            
            
            
            let previousDateString = DateFormatter.formattedDateString(date: previousDate)

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
        
        
        let today = DateFormatter.fetchDateString()
        let firstDateInArray = sunDataArray.first?.date ?? ""
        
        print("Today: \(today) First Day: \(firstDateInArray)")
        
        if today == firstDateInArray {
    //      Schedule Alarm Notifications
            NotificationManager.requestNotificationPermission()
            scheduleAlarmNotifications(schedules: schedules)
        }
    
        
//      Write schedule to JSON file
        
        AppDataManager.saveDataToFile(data: schedules, fileName: Constants.alarmDataFileName)

    }


func scheduleAlarmNotifications(schedules: [AlarmSchedule]) {
    NotificationManager.cancelAllScheduledNotifications()
    
    let dateFormatter = DateFormatter.dateAndTime
    let sleepGoalHoursString = "\(UserDefaults.standard.wakeUpOffsetHours) \(UserDefaults.standard.wakeUpOffsetHours > 1 ? "hours" : "hour")"

    
    var counter = 0
    for schedule in schedules {
        
        guard counter < 15 else {break}
        
        guard let windDownDate = dateFormatter.date(from: schedule.windDownTime),
              let bedTime = dateFormatter.date(from: schedule.bedTime),
              let alarmTime = dateFormatter.date(from: schedule.alarmTime) 
        else {
            continue
        }
        
        print("Winddown: \(windDownDate)")
        print("Bed Time: \(bedTime)")
        print("Alarm Time: \(alarmTime)")
        
        NotificationManager.scheduleNotification(at: windDownDate, title: "Time to start winding down.", body: "Go to bed in \(UserDefaults.standard.windDownTime) minutes to reach your goal of \(sleepGoalHoursString) of sleep.")
        NotificationManager.scheduleNotification(at: bedTime, title: "Time for bed.", body: "Go to bed now to reach your \(sleepGoalHoursString) of sleep goal.")
        NotificationManager.scheduleNotification(at: alarmTime, title: "Rise and Shine!", body: "Waking you up \(UserDefaults.standard.wakeUpOffsetHours) \(UserDefaults.standard.wakeUpOffsetHours > 1 ? "hours" : "hour") \(UserDefaults.standard.beforeSunrise ? "before" : "after") sunrise.")
        
        counter += 1
                
    }
    
}

    


