//
//  updateData.swift
//  Rise and Shine
//
//  Created by loren on 1/21/24.
//

import Foundation

func updateData(date: Date) async {

    let dateString = formattedDateString(date: date)
//    let date = fetchDate() // Make sure this function exists
    
    do {
        try await APIManager.fetchSunData(latitude: UserDefaults.standard.currentLatitude, longitude: UserDefaults.standard.currentLongitude, startDate: dateString, missingDate: false)
        if let sunDataArray = AppDataManager.loadFile(fileName: Constants.sunDataFileName, type: [SunData].self) {
            calculateScheduleForSunData(sunDataArray)
            
        } else {
            print("Sunrise time not found for date: \(date)")
        }
    } catch {
        print("Error fetching sun data: \(error)")
    }
}
