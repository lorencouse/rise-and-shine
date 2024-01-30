//
//  APIManager.swift
//  Rise and Shine
//
//  Created by loren on 1/18/24.
//

import Foundation


struct APIManager {
    

    static func fetchSunDataFromAPI(latitude: Double?, longitude: Double?, startDate: String) async throws{
        
        let currentCity = UserDefaults.standard.currentCity
    
        
        if AppDataManager.loadSunDataFile() == nil || currentCity != UserDefaults.standard.lastCity {

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let urlBase = Constants.sunDataAPIBaseURL

        guard let startDateVal = dateFormatter.date(from: startDate) else {
            fatalError("Invalid date format for startDate")
        }

        guard let endDate = Calendar.current.date(byAdding: .day, value: 30, to: startDateVal) else {
            fatalError("Error calculating endDate")
        }

        let endDateString = dateFormatter.string(from: endDate)

            
            guard let url = URL(string: "\(urlBase)?lat=\(String(describing: latitude))&lng=\(String(describing: longitude))&date_start=\(startDate)&date_end=\(endDateString)") else { print("Not a valid url.")
                return }

            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(SunApiResponse.self, from: data)

            AppDataManager.saveSunDataToFile(sunData: decoded.results)
            UserDefaults.standard.lastCity = currentCity
            print("API Call Sucess")
        }
        
        else {
            print("Sunrise data is already up to date.")
        }

    }
    
    
    static func fetchMissingSunDataFromAPI(latitude: Double?, longitude: Double?, startDate: String) async throws{
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let urlBase = Constants.sunDataAPIBaseURL

        guard let startDateVal = dateFormatter.date(from: startDate) else {
            fatalError("Invalid date format for startDate")
        }

        guard let endDate = Calendar.current.date(byAdding: .day, value: 30, to: startDateVal) else {
            fatalError("Error calculating endDate")
        }

        let endDateString = dateFormatter.string(from: endDate)

            
            guard let url = URL(string: "\(urlBase)?lat=\(String(describing: latitude))&lng=\(String(describing: longitude))&date_start=\(startDate)&date_end=\(endDateString)") else { print("Not a valid url.")
                return }

            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(SunApiResponse.self, from: data)

            AppDataManager.appendSunDataToFile(newSunData: decoded.results)
            print("Missing SunData Added to JSON")
        
    }
    

}


