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
//    @State private var locationData: LocationManager?
    @AppStorage("wakeUpOffsetHours") var wakeUpOffsetHours = 0
    @AppStorage("wakeUpOffsetMinutes") var wakeUpOffsetMinutes = 0
    @AppStorage("beforeSunrise") var beforeSunrise = true 
    @AppStorage("targetHoursOfSleep") var targetHoursOfSleep = Constants.targetHoursOfSleepDefault
    @AppStorage("windDownTime") var windDownTime = 0
    @AppStorage("bedTime") var bedTime = ""
    @AppStorage("alarmTime") var alarmTime = ""
    @AppStorage("currentCity") var currentCity = "Location: Unknown"
    @State private var sunData: [SunData] = APIManager.loadSunDataFromFile() ?? []


    
    
    var body: some View {
        
        
        NavigationView {
            
            Form {
                
                Section(header: Text("Location:")) {
                    
                    Text(currentCity)
                    VStack {

                        Button("Update") {
                            Task {
                                fetchLocation(locationManager: locationManager)
                                await updateData()
                                sunData = APIManager.loadSunDataFromFile() ?? []
                            }
                            print(UserDefaults.standard.currentCity)
                            
                        }
                        
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

                    Text("Date: " + (fetchDate()))
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



                        Text("Alarm Time: \(alarmTime) ")


                }

                Section(header: Text("Target Hours of Sleep")) {


                        Text("Your bedtime is: \(bedTime)")



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
                    Text("Wind down at: \(UserDefaults.standard.windDownTimeReminder ?? "")")


                }
                
                Section() {
                    Button("Clear User Data") {
                        Task {
                            clearUserDefaults()
                            sunData = []
                        }

                        
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



