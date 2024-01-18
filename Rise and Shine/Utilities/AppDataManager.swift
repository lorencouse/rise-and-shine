//
//  AppDataManager.swift
//  Rise and Shine
//
//  Created by loren on 1/18/24.
//

import Foundation
import CoreLocation

//class AppDataManager {
//    static let shared = AppDataManager()
//    
//    // Fetch and update the data
//    func updateDataOnLaunch() {
//        fetchLocationData { [weak self] location in
//            self?.fetchDateAndSunData(location: location) { sunData in
//                self?.updateAlarms(sunData: sunData)
//                // Store values in UserDefaults
//                UserDefaults.standard.sunData = sunData
//                // ... store other values ...
//            }
//        }
//    }
//
//    private func fetchLocationData(completion: @escaping (CLLocation) -> Void) {
//        // Fetch location and call completion with the result
//    }
//
//    private func fetchDateAndSunData(location: CLLocation, completion: @escaping (SunData) -> Void) {
//        // Fetch date and sun data, then call completion
//    }
//
//    private func updateAlarms(sunData: SunData) {
//        // Logic to update alarms based on sun data
//    }
//}
