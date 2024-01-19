//
//  SettingsView.swift
//  Rise and Shine
//
//  Created by loren on 1/18/24.
//

import Foundation
import SwiftUI
import CoreLocation

struct SettingsView: View {
    @ObservedObject private var locationManager = LocationManager()
    @AppStorage("wakeUpOffsetHours") var wakeUpOffsetHours = 0
    @AppStorage("wakeUpOffsetMinutes") var wakeUpOffsetMinutes = 0
    @AppStorage("beforeSunrise") var beforeSunrise = true
    @AppStorage("targetHoursOfSleep") var targetHoursOfSleep = 8
    @AppStorage("windDownTime") var windDownTime = 59
    @State private var sunData: [SunData] = []
    @State private var locationData: LocationManager?
    @State private var currentDate: String = fetchDate()
    @State private var alarmTime: Date?
    @State private var bedTime: Date?
    
    
    var body: some View {
        
        
        NavigationView {
            
            Form {
                
                Section(header: Text("Location:")) {
                    VStack {

                        Button("Update") {
                            Task {
                                await fetchLocation(locationManager: locationManager)
                                await updateData()
                            }
                            print(UserDefaults.standard.currentCity)
                            
                        }


                        Text("City: " + UserDefaults.standard.currentCity)
                    }
                }

                Section(header: Text("Sunrise Sunset")) {

                    if sunData.isEmpty {
                        Text("No sunrise data available")
                    } else {
                        ForEach(sunData, id: \.self) { day in

                            Text("\(day.date): \(day.sunrise)")
                        }
                    }

                    Text("Date: " + (currentDate ))
                    if let sunrise = sunData.first?.sunrise, let sunset = sunData.first?.sunset {
                        Text("Sunrise Time: \(sunrise)")


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

                    if sunData.count > 1 {
                        Text("Your bedtime is: \(formattedDateString(date: bedTime!))")
                    } else {
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
    
    
    
}



