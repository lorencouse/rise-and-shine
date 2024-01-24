//
//  APIManager.swift
//  Rise and Shine
//
//  Created by loren on 1/18/24.
//

import Foundation


struct APIManager {
    

    static func fetchSunDataFromAPI(latitude: Double?, longitude: Double?, startDate: String) async throws{
        guard let latitude = latitude, let longitude = longitude else {
            print("Could not fetch Lat and Long")
            return
        }

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

        let (data, _) = try await URLSession.shared.data(from: url)
        let decoded = try JSONDecoder().decode(SunApiResponse.self, from: data)
        
        var sunriseTimeArray = UserDefaults.standard.stringArray(forKey: "sunriseTimeArray") ?? [String]()

        for day in decoded.results {
            sunriseTimeArray.append(day.sunrise)
        }
        
        
        // Save the sun data to file
        UserDefaults.standard.set(sunriseTimeArray, forKey: "sunriseTimeArray")
        saveSunDataToFile(sunData: decoded.results)
    }
    
    private static func saveSunDataToFile(sunData: [SunData]) {
        do {
            let filePath = getDocumentsDirectory().appendingPathComponent("sunData.json")
            let data = try JSONEncoder().encode(sunData)
            try data.write(to: filePath, options: .atomicWrite)
        } catch {
            print("Error saving sun data to file: \(error)")
        }
    }

    static func loadSunDataFromFile() -> [SunData]? {
        let filePath = getDocumentsDirectory().appendingPathComponent("sunData.json")
        do {
            let data = try Data(contentsOf: filePath)
            let sunData = try JSONDecoder().decode([SunData].self, from: data)
            return sunData
        } catch {
            print("Error loading sun data from file: \(error)")
            return nil
        }
    }
    
    static func clearAndDeleteSunData() {
        let filePath = getDocumentsDirectory().appendingPathComponent("sunData.json")
        
        do {
            // Remove the file from the file system
            try FileManager.default.removeItem(at: filePath)
            
            print("SunData file deleted successfully.")
        } catch {
            print("Error deleting SunData file: \(error)")
        }
    }


    private static func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
}


