//
//  APIManager.swift
//  Rise and Shine
//
//  Created by loren on 1/18/24.
//

import Foundation


struct APIManager {
    
    
    static func fetchSunData(latitude: Double?, longitude: Double?, startDate: String, missingDate: Bool) async throws {
        
        let currentCity = UserDefaults.standard.currentCity

        // Check if a new file is needed or if it's a new location, and missingDate is false
        let needsNewFile = AppDataManager.loadFile(fileName: Constants.sunDataFileName, type: [SunData].self) == nil || (currentCity != UserDefaults.standard.lastCity)
        
        if needsNewFile || missingDate {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let urlBase = Constants.sunDataAPIBaseURL

            guard let startDateVal = dateFormatter.date(from: startDate) else {
                throw SunDataError.invalidDateFormat
            }

            guard let endDate = Calendar.current.date(byAdding: .day, value: 30, to: startDateVal) else {
                throw SunDataError.endDateCalculationError
            }

            let endDateString = dateFormatter.string(from: endDate)
            guard let lat = latitude, let lng = longitude,
                  let url = URL(string: "\(urlBase)?lat=\(lat)&lng=\(lng)&date_start=\(startDate)&date_end=\(endDateString)") else {
                throw SunDataError.invalidURL
            }

            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(SunApiResponse.self, from: data)

            // Depending on conditions, either save new data or append to existing file
            if needsNewFile {

                AppDataManager.saveDataToFile(data: decoded.results, fileName: Constants.sunDataFileName)
                UserDefaults.standard.lastCity = currentCity
                print("API Call Success. New JSON sun data created for location.")
            } else {
                AppDataManager.appendSunDataToFile(newSunData: decoded.results)
                print("Missing SunData Added to JSON")
            }
            
        }

        else {
            print("Sunrise data is already up to date.")
        }
    }
    
}

enum SunDataError: Error {
    case invalidDateFormat
    case invalidURL
    case endDateCalculationError
}


