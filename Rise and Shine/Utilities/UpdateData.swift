//
//  updateData.swift
//  Rise and Shine
//
//  Created by loren on 1/21/24.
//

import Foundation

func updateData() async {
    // Retrieve user settings
    let targetHoursOfSleep = UserDefaults.standard.targetHoursOfSleep
    let latitude = UserDefaults.standard.currentLatitude
    let longitude = UserDefaults.standard.currentLongitude
    
    // Get current date
    let date = fetchDate()

    
    // Call SunAPI and update sunData
    do {
        try await APIManager.fetchSunDataFromAPI(latitude: latitude, longitude: longitude, startDate: date)
        let sunDataArray = UserDefaults.standard.array(forKey: "sunriseTimeArray") ?? []
        // Load sun data from file


        // Find sunrise time for the given date
        if let sunDataForDate = sunDataArray.first {
            Task {
                calculateAlarmTime()
//                calculateBedTime()
//                calculateWindDownReminder()
//              Calculate Bedtime
                calculateTime(for: "alarmTime", adjustment: .hour(UserDefaults.standard.targetHoursOfSleep), resultKey: "bedTime")
//              Calculate winddown Timer
                calculateTime(for: "bedTime", adjustment: .minute(UserDefaults.standard.windDownTime), resultKey: "windDownTimer")
                print("targetHoursOfSleep \(targetHoursOfSleep)")
                
            }

        } else {
            print("Sunrise time not found for date: \(date)")
        }

    } catch {
        print("Error fetching sun data: \(error)")
    }


}
