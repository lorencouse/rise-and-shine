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
    @ObservedObject private var locationManager = LocationManager()
    @State private var locationData: LocationManager?

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




func fetchDate() -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    return dateFormatter.string(from: Date())
}

func formattedDateString(date: Date) -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "h:mm:ss a"
    return dateFormatter.string(from: date)
}

func fetchLocation(locationManager: LocationManager) -> String {
    guard let status = locationManager.locationStatus else {
        return "Unknown Location Access Status"
    }

    switch status {
    case .authorizedAlways, .authorizedWhenInUse:
        if locationManager.currentLocation != nil {
            UserDefaults.standard.setValue( locationManager.currentLocation?.coordinate.latitude, forKey: "currentLatitude")
            UserDefaults.standard.setValue( locationManager.currentLocation?.coordinate.longitude, forKey: "currentLongitude")
            UserDefaults.standard.setValue( locationManager.cityName, forKey: "currentCity")
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


func updateData() async {
    // Retrieve user settings
    let hoursOfSleep = UserDefaults.standard.integer(forKey: "hoursOfSleep")
    let alarmOffsetHours = UserDefaults.standard.wakeUpOffsetHours
    let alarmOffsetMinutes = UserDefaults.standard.wakeUpOffsetMinutes
    let beforeSunrise = UserDefaults.standard.beforeSunrise
    
    // Get current date
    let date = fetchDate()
    print(date)
    
    // Call SunAPI and update sunData
    do {
        let sunData = try await APIManager.fetchSunDataFromAPI(latitude: UserDefaults.standard.currentLatitude, longitude: UserDefaults.standard.currentLongitude, startDate: date)
        
        // Ensure sunData has enough entries
        guard let firstSunrise = sunData?.first?.sunrise, let nextDaySunrise = sunData?.dropFirst().first?.sunrise else {
            print("Insufficient sun data")
            return
        }
        Task {
            // Calculate BedTime for next day
            calculateBedTime(sunriseTimeNextDay: nextDaySunrise, hoursOfSleep: hoursOfSleep)

            // Calculate AlarmTime for today
            calculateAlarmTime(sunriseTime: firstSunrise, alarmOffsetMinutes: alarmOffsetMinutes, alarmOffsetHours: alarmOffsetHours, beforeSunrise: beforeSunrise)
        }
        print(firstSunrise)
        print(nextDaySunrise)

    } catch {
        print("Error fetching sun data: \(error)")
    }





}


func calculateAlarmTime(sunriseTime: String, alarmOffsetMinutes: Int, alarmOffsetHours: Int,  beforeSunrise: Bool) -> Date {
    var alarmOffset = alarmOffsetMinutes + (alarmOffsetHours * 60)
    alarmOffset = beforeSunrise ? -alarmOffset : alarmOffset
    // Step 1: Convert sunriseTime string to Date
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "h:mm:ss a"
    dateFormatter.locale = Locale(identifier: "en_US_POSIX") // Set the locale to ensure proper parsing
    
    guard let sunriseDate = dateFormatter.date(from: sunriseTime) else {
        fatalError("Invalid date format for sunriseTime")
    }
    
    // Step 2: Add alarmOffsetMinutes to get alarm time
    let calendar = Calendar.current
    if let alarmTime = calendar.date(byAdding: .minute, value: alarmOffset, to: sunriseDate) {
        return alarmTime
    } else {
        fatalError("Error calculating alarm time")
    }
}

func calculateBedTime(sunriseTimeNextDay: String, hoursOfSleep: Int) -> Date? {
    // Step 1: Convert sunriseTime string to Date datatype
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "h:mm:ss a"
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    
    guard let sunriseAsDate = dateFormatter.date(from: sunriseTimeNextDay) else {
        // Handle invalid date format gracefully
        return nil
    }
    
    // Step 2: Subtract hours of sleep from converted Date
    if let bedTime = Calendar.current.date(byAdding: .hour, value: -hoursOfSleep, to: sunriseAsDate) {
        return bedTime
    } else {
        // Handle error if unable to calculate sleep time
        return nil
    }
}

#Preview {
    ContentView()
}
