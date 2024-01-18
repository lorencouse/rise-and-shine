//
//  SettingsView.swift
//  Rise and Shine
//
//  Created by loren on 1/18/24.
//

import Foundation
import SwiftUI

struct SettingsView: View {
    @ObservedObject private var locationManager = LocationManager()
    @AppStorage("wakeUpOffsetHours") var wakeUpOffsetHours = 0
    @AppStorage("wakeUpOffsetMinutes") var wakeUpOffsetMinutes = 0
    @AppStorage("beforeSunrise") var beforeSunrise = true
    @AppStorage("targetHoursOfSleep") var targetHoursOfSleep = 8
    @AppStorage("windDownTime") var windDownTime = 59
    @State private var sunData: [SunData]?
    @State private var locationData: LocationManager?
    @State private var currentDate: String = fetchDate()
    @State private var alarmTime: Date?
    @State private var bedTime: Date?
    
    
    var body: some View {
        NavigationView {
            Form {
                // Use the new function for the button action
                updateButton
                
                Section(header: Text("Location:")) {
                    VStack {
                        Text("City: " + fetchLocation(locationManager: locationManager))
                    }
                }
                
                Section(header: Text("Sunrise Sunset")) {
                    Text("Date: " + (currentDate ))
                    if let sunrise = sunData?.first?.sunrise, let sunset = sunData?.first?.sunset {
                        Text("Sunrise Time: \(sunrise)")
                        Text("Sunset Time: \(sunset)")
                    } else {
                        Text("Please Update Location")
                    }
                }
                
                
                
                Section(header: Text("Alarm time:")) {
                    HStack {
                        
                        Text("Wake up ")

                        Picker("", selection: $wakeUpOffsetHours) {
                            ForEach(0..<4, id: \.self) { i in
                                Text("\(i) hours").tag(i)
                            }
                        }.pickerStyle(MenuPickerStyle())
                        
                        Picker("", selection: $wakeUpOffsetMinutes) {
                            ForEach(0..<60, id: \.self) { i in
                                Text("\(i) mins").tag(i)
                            }
                        }.pickerStyle(MenuPickerStyle())
                    }
                    Picker("Direction", selection: $beforeSunrise) {
                        Text("Before Sunrise").tag(true)
                        Text("After Sunrise").tag(false)
                    }.pickerStyle(SegmentedPickerStyle())
                    
                    if let alarmTimeString = alarmTime {
                        
                        Text("Alarm Time: \(formattedDateString(date: alarmTimeString)) ")
                        
                    }
                    else {
                        Text("No Alarm Set")
                    }
                    
                }
                
                Section(header: Text("Target Hours of Sleep")) {
                    
                    if let calcBedTime = calculateBedTime(sunriseTime: sunData?[1].sunrise ?? "06:10:00", hoursOfSleep: targetHoursOfSleep) {
                        Text("Your bedtime is: \(calcBedTime)")
                    }
                    else {
                        Text("Set Your Bed Time")
                    }
                    
                    Picker("Sleep Goal: ", selection: $targetHoursOfSleep) {
                        ForEach(4..<14, id: \.self) { i in
                            Text("\(i) hours").tag(i)
                        }
                    }.pickerStyle(MenuPickerStyle())
                }
                
                Section(header: Text("Wind down reminder")) {
                    VStack {
                        Picker("Notify me ", selection: $windDownTime) {
                            ForEach(0..<60, id: \.self) { i in
                                Text("\(i) mins").tag(i)
                            }
                        }.pickerStyle(MenuPickerStyle())
                        Text(" before bedtime.")
                    }
                    
                    
                }
                
                VStack {
                    Link("Data from SunriseSunset.io", destination: URL(string: "https://sunrisesunset.io/api/")!)
                        .padding()
                }

            }
            .navigationTitle("Settings")
            
        }
    }
    
    private func updateData(latitude: Double, longitude: Double) {
        Task {
            do {
//                let wakeUpOffsetHours = UserDefaults.standard.wakeUpOffsetHours
                sunData = try await APIManager.fetchSunDataFromAPI(latitude: latitude, longitude: longitude, startDate: currentDate ?? "2000-01-30")
                
                // Move the calculation of alarmTime here
                let alarmOffset = wakeUpOffsetMinutes + (wakeUpOffsetHours * 60)
                alarmTime = calculateWakeTime(sunriseTime: sunData?.first?.sunrise ?? "", alarmOffsetMinutes: alarmOffset, beforeSunrise: beforeSunrise)
                
            } catch {
                print("Error fetching sunrise data: \(error)")
            }
        }

    }

    private var updateButton: some View {
        Button("Refresh") {
            locationManager.locationManager.requestLocation()
            
            // Fetch sunrise data when location is available
            if let location = locationManager.currentLocation {
                updateData(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
            }
        }
        .padding()
    }

}
