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
    @AppStorage("wakeUpOffsetHours") var wakeUpOffsetHours = Constants.wakeUpOffsetHoursDefault
    @AppStorage("wakeUpOffsetMinutes") var wakeUpOffsetMinutes = Constants.wakeUpOffsetMinutesDefault
    @AppStorage("beforeSunrise") var beforeSunrise = true
    @AppStorage("targetHoursOfSleep") var targetHoursOfSleep = Constants.targetHoursOfSleepDefault
    @AppStorage("windDownTime") var windDownTime = Constants.windDownTimeDefault
    @AppStorage("windDownTimer") var windDownTimer = "10:00 PM"
    @AppStorage("bedTime") var bedTime = ""
    @AppStorage("alarmTime") var alarmTime = ""
    @AppStorage("currentCity") var currentCity = "Location: Please Update"
    @State private var updateButtonText: String = "Save Prefrences"


    
    
    var body: some View {
        
        
        NavigationView {
            
            Form {
                
                Section(header: Text("Location:")) {
                    
                    Text(currentCity)

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

                }

                Section(header: Text("Target Hours of Sleep")) {
                    
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
                
                Section() {
                    Button("Reset Alarm Preferences") {
                        Task {
                            clearUserDefaults()
                        }

                        
                    }
                    
                    Button("Erase All App Data") {
                        Task {
                            clearUserDefaults()
                            AppDataManager.clearAndDeleteSunData()
                            AppDataManager.deleteAlarmsFile()
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

#Preview {
    SettingsView()
}



