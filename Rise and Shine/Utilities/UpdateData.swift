//
//  updateData.swift
//  Rise and Shine
//
//  Created by loren on 1/21/24.
//

import Foundation

func updateData(date: Date, locationManager: LocationManager) async {

    let dateString = DateFormatter.formattedDateString(date: date)
//    let date = fetchDate() // Make sure this function exists
    
    do {
        try await APIManager.fetchSunData(latitude: locationManager.currentLocation?.coordinate.latitude, longitude: locationManager.currentLocation?.coordinate.longitude, startDate: dateString, missingDate: false)
        if let sunDataArray = AppDataManager.loadFile(fileName: Constants.sunDataFileName, type: [SunData].self) {
            calculateScheduleForSunData(sunDataArray)
            
        } else {
            print("Sunrise time not found for date: \(date)")
        }
    } catch {
        print("Error fetching sun data: \(error)")
    }
}
