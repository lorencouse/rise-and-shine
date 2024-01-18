//
//  APIManager.swift
//  Rise and Shine
//
//  Created by loren on 1/18/24.
//

import Foundation

struct APIManager {
    
    static func fetchSunDataFromAPI(latitude: Double?, longitude: Double?, startDate: String) async throws -> [SunData]? {
        guard let latitude = latitude, let longitude = longitude else {
            return nil
        }

        // Calculate endDate by adding 30 days to startDate
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

        let url = URL(string: "\(urlBase)?lat=\(latitude)&lng=\(longitude)&date_start=\(startDate)&date_end=\(endDateString)")!
        print(url)

        let (data, _) = try await URLSession.shared.data(from: url)

        let decoded = try JSONDecoder().decode(SunApiResponse.self, from: data)

        return decoded.results
    }
}
