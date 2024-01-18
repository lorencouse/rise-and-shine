//
//  ContentView.swift
//  Rise and Shine
//
//  Created by loren on 1/13/24.
//

import SwiftUI
import UserNotifications
import CoreLocation
import UIKit
import Foundation
import Combine

struct ContentView: View {
    
    var body: some View {
        NavigationView {
            VStack {
                VStack {
                    
                    Text("Rise and Shine")
                        .font(.largeTitle).padding()

                
                NavigationLink(destination: SettingsView()) {
                    Text("Settings")
                        .foregroundColor(Color.blue)
                }
                }
                
                
                .navigationTitle("Rise and Shine")
                
            }
        }
    }
}


func fetchLocation(locationManager: LocationManager) -> String {
    guard let status = locationManager.locationStatus else {
        return "Unknown Location Access Status"
    }

    switch status {
    case .authorizedAlways, .authorizedWhenInUse:
        if locationManager.currentLocation != nil {
            return locationManager.cityName ?? "Unknown City"
        } else {
            return "Location not available"
        }
    case .denied, .restricted:
        return "Location Access Denied"
    case .notDetermined:
        return "Location Access Not Determined"
    @unknown default:
        return "Error fetching location"
    }
}


func fetchDate() -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    
    let currentDate = Date()
    let formattedDate = dateFormatter.string(from: currentDate)
    
    return formattedDate
}


func calculateWakeTime(sunriseTime: String, alarmOffsetMinutes: Int, beforeSunrise: Bool) -> Date {
    
    let alarmOffsetMinutes = beforeSunrise ? -alarmOffsetMinutes : alarmOffsetMinutes
    // Step 1: Convert sunriseTime string to Date
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "h:mm:ss a"
    dateFormatter.locale = Locale(identifier: "en_US_POSIX") // Set the locale to ensure proper parsing
    
    guard let sunriseDate = dateFormatter.date(from: sunriseTime) else {
        fatalError("Invalid date format for sunriseTime")
    }
    
    // Step 2: Add alarmOffsetMinutes to get alarm time
    let calendar = Calendar.current
    if let alarmTime = calendar.date(byAdding: .minute, value: alarmOffsetMinutes, to: sunriseDate) {
        return alarmTime
    } else {
        fatalError("Error calculating alarm time")
    }
}

func calculateBedTime(sunriseTime: String, hoursOfSleep: Int) -> Date? {
    // Step 1: Convert sunriseTime string to Date datatype
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "h:mm:ss a"
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    
    guard let sunriseDate = dateFormatter.date(from: sunriseTime) else {
        // Handle invalid date format gracefully
        return nil
    }
    
    // Step 2: Subtract hours of sleep from converted Date
    if let bedTime = Calendar.current.date(byAdding: .hour, value: -hoursOfSleep, to: sunriseDate) {
        return bedTime
    } else {
        // Handle error if unable to calculate sleep time
        return nil
    }
}


func formattedDateString(date: Date) -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "h:mm:ss a"
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    return dateFormatter.string(from: date)
}

#Preview {
    ContentView()
}
