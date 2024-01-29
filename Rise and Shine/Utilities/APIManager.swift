//
//  APIManager.swift
//  Rise and Shine
//
//  Created by loren on 1/18/24.
//

import Foundation


struct APIManager {
    

    static func fetchSunDataFromAPI(latitude: Double?, longitude: Double?, startDate: String) async throws{

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

        let fileName = "sunData-\(startDate)-lat=\(String(describing: latitude))&lng=\(String(describing: longitude)).json"
        
        
        if AppDataManager.loadSunDataFile() == nil || fileName != UserDefaults.standard.sunriseJSONFileName {
            
            guard let url = URL(string: "\(urlBase)?lat=\(String(describing: latitude))&lng=\(String(describing: longitude))&date_start=\(startDate)&date_end=\(endDateString)") else { print("Not a valid url.")
                return }

            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(SunApiResponse.self, from: data)

            AppDataManager.saveSunDataToFile(sunData: decoded.results, fileName: fileName)
            UserDefaults.standard.sunriseJSONFileName = fileName
            print("API Call Sucess")
        }
        else {
            print("Sunrise data is already up to date.")
        }
        

    }
    
//    private static func saveSunDataToFile(sunData: [SunData], fileName: String) {
//        do {
//            let filePath = getDocumentsDirectory().appendingPathComponent("\(fileName)")
//            let data = try JSONEncoder().encode(sunData)
//            try data.write(to: filePath, options: .atomicWrite)
//        } catch {
//            print("Error saving sun data to file: \(error)")
//        }
//    }
//
//    static func loadSunDataFromFile() -> [SunData]? {
//        let filePath = getDocumentsDirectory().appendingPathComponent(UserDefaults.standard.sunriseJSONFileName)
//        do {
//            let data = try Data(contentsOf: filePath)
//            let sunData = try JSONDecoder().decode([SunData].self, from: data)
//            return sunData
//        } catch {
//            print("Error loading sun data from file: \(error)")
//            return nil
//        }
//    }
//    
//    static func clearAndDeleteSunData() {
//        let filePath = getDocumentsDirectory().appendingPathComponent(UserDefaults.standard.sunriseJSONFileName)
//        
//        do {
//            // Remove the file from the file system
//            try FileManager.default.removeItem(at: filePath)
//            
//            print("SunData file deleted successfully.")
//        } catch {
//            print("Error deleting SunData file: \(error)")
//        }
//    }
//
//
//    private static func getDocumentsDirectory() -> URL {
//        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
//        return paths[0]
//    }
}


