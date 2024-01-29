//
//  updateData.swift
//  Rise and Shine
//
//  Created by loren on 1/21/24.
//

import Foundation

func updateData() async {
    let targetHoursOfSleep = UserDefaults.standard.integer(forKey: "targetHoursOfSleep") // Ensure a default value
    let latitude = UserDefaults.standard.double(forKey: "currentLatitude") // Ensure a default value
    let longitude = UserDefaults.standard.double(forKey: "currentLongitude") // Ensure a default value
    
    let date = fetchDate() // Make sure this function exists
    
    do {
        try await APIManager.fetchSunDataFromAPI(latitude: latitude, longitude: longitude, startDate: date)
        if let sunDataArray = AppDataManager.loadSunDataFile() {
            calculateScheduleForSunData(sunDataArray)
            
        } else {
            print("Sunrise time not found for date: \(date)")
        }
    } catch {
        print("Error fetching sun data: \(error)")
    }
}
