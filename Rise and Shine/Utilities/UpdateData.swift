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
        
        // Load sun data from file
        let sunDataArray = APIManager.loadSunDataFromFile() ?? []

        // Find sunrise time for the given date
        if let sunDataForDate = sunDataArray.first(where: { $0.date == date }) {
            let sunriseTime = sunDataForDate.sunrise

            Task {

                calculateBedTime(sunriseTimeNextDay: sunriseTime, hoursOfSleep: targetHoursOfSleep)
                print("targetHoursOfSleep \(targetHoursOfSleep)")

                calculateAlarmTime(sunriseTime: sunriseTime)
                
            }

        } else {
            print("Sunrise time not found for date: \(date)")
        }

    } catch {
        print("Error fetching sun data: \(error)")
    }


}
