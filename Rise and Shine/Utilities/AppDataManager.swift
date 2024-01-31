//
//  AppDataManager.swift
//  Rise and Shine
//
//  Created by loren on 1/18/24.
//

import Foundation
import CoreLocation

class AppDataManager {
    static let shared = AppDataManager()
    
    static func saveDataToFile<T: Encodable>(data: T, fileName: String) {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Documents directory not found.")
            return
        }
        
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        
        do {
            let encodedData = try JSONEncoder().encode(data)
            try encodedData.write(to: fileURL, options: .atomic)
        } catch {
            print("Error saving data to file: \(error)")
        }
    }
    
    static func loadFile<T: Decodable>(fileName: String, type: T.Type) -> T? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Documents directory not found.")
            return nil
        }
        
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decodedData = try JSONDecoder().decode(T.self, from: data)
            return decodedData
        } catch {
            print("Error reading data from file: \(error)")
            return nil
        }
    }
    
    static func appendSunDataToFile(newSunData: [SunData]) {
        let fileName = Constants.sunDataFileName
        do {
            let filePath = getDocumentsDirectory().appendingPathComponent(fileName)
            var existingData = loadFile(fileName: fileName, type: [SunData].self) ?? []
            
            // Avoid duplicates
            for newData in newSunData where !existingData.contains(where: { $0.date == newData.date }) {
                existingData.append(newData)
            }
            
            let data = try JSONEncoder().encode(existingData)
            try data.write(to: filePath, options: .atomicWrite)
            
            print("SunData appended to file.")
        } catch {
            print("Error appending sun data to file: \(error)")
        }
    }
    
    
    static func deleteFile(fileName: String) {
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
        
        guard let fileURL = documentsDirectory?.appendingPathComponent(fileName) else {
            print("Failed to get the file URL")
            return
        }
        
        do {
            try fileManager.removeItem(at: fileURL)
            print("\(fileName) successfully deleted")
        } catch {
            print("Error deleting file: \(error)")
        }
    }
    
    
    
}

func getDocumentsDirectory() -> URL {
    let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
    return paths[0]
}
