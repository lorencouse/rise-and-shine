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
    
//    Sun Data Json Manager
    
    static func saveSunDataToFile(sunData: [SunData]) {
        do {
            let filePath = getDocumentsDirectory().appendingPathComponent("sunData.json")
            let data = try JSONEncoder().encode(sunData)
            try data.write(to: filePath, options: .atomicWrite)
        } catch {
            print("Error saving sun data to file: \(error)")
        }
    }

    static func loadSunDataFile() -> [SunData]? {
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
    
    static func appendSunDataToFile(newSunData: [SunData]) {
        do {
            let filePath = getDocumentsDirectory().appendingPathComponent("sunData.json")
            var existingData = loadSunDataFile() ?? []
            
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
    
//    User Alarms JSON Manager
    
    static func deleteAlarmsFile() {
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first

        guard let fileURL = documentsDirectory?.appendingPathComponent("userAlarms.json") else {
            print("Failed to get the file URL")
            return
        }

        do {
            try fileManager.removeItem(at: fileURL)
            print("File successfully deleted")
        } catch {
            print("Error deleting file: \(error)")
        }
    }
    
    static func loadAlarmsFile() -> [AlarmSchedule]? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Documents directory not found.")
            return nil
        }

        let fileURL = documentsDirectory.appendingPathComponent("userAlarms.json")

        do {
            let data = try Data(contentsOf: fileURL)
            let schedules = try JSONDecoder().decode([AlarmSchedule].self, from: data)
            return schedules
        } catch {
            print("Error reading schedules from file: \(error)")
            return nil
        }
    }

    
}

func getDocumentsDirectory() -> URL {
    let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
    return paths[0]
}
