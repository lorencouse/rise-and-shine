//
//  SettingsComponents.swift
//  Rise and Shine
//
//  Created by loren on 2/6/24.
//

import Foundation
import SwiftUI


class settingsComponents {
    struct AlarmTimeSelector: View {
        @Binding var wakeUpOffsetHours: Int
        @Binding var wakeUpOffsetMinutes: Int
        @Binding var beforeSunrise: Bool

        var body: some View {
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
                Picker("", selection: $beforeSunrise) {
                    Text("Before Sunrise").tag(true)
                    Text("After Sunrise").tag(false)
                }.pickerStyle(SegmentedPickerStyle())
            }
            .listRowBackground(Color.appThird)
        }
    }
    
    
    struct LocationSelector: View {
        
        @Binding var sunData: [SunData]
        @ObservedObject var locationManager: LocationManager
        @State private var showingAlert = false
        @State private var sunriseTime: String = "Tap to Update Sunrise Time"
        @State private var cityName: String = UserDefaults.standard.currentCity
        let dateString = DateFormatter.fetchDateString()
        
        var body: some View {
            
            Section(header: Text("\(Image(systemName: "location.fill")) Location:")) {
                
                Button("\(Image(systemName: "location.circle")) \(cityName)") {
                    
                    updateLocationAndSunrise()
                    
                }

                .alert("Location Error", isPresented: $showingAlert) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text("Please ensure the app has permission to access your location and try again.")
                }
                
                Button("\(Image(systemName: "sun.haze.circle")) Sunrise Time: \(sunriseTime)") {
                    updateLocationAndSunrise()
                }
                
            }
            .onChange(of: locationManager.locationStatus) { newValue in
                if newValue == .denied || newValue == .restricted {
                    showingAlert = true
                }
            }
            .onAppear {
                updateLocationAndSunrise()
                
            }
            .listRowBackground(Color.appThird)
            
        }
        
        private func updateLocationAndSunrise() {
            Task {
                locationManager.requestSingleLocationUpdate()
                await updateSunData(date: dateString, locationManager: locationManager)
                sunData = AppDataManager.loadFile(fileName: Constants.sunDataFileName, type: [SunData].self) ?? []
                if let sunrise = sunData.first?.sunrise {
                    sunriseTime = "\(sunrise)"
                } else {
                }
            }
        }

    }
    
    
    struct TargetHoursOfSleepSelector: View {
        @Binding var targetHoursOfSleep: Int

        var body: some View {
            Section(header: Text("\(Image(systemName: "moon.zzz.fill")) Target Hours of Sleep")) {
                Picker("Sleep Goal: ", selection: $targetHoursOfSleep) {
                    ForEach(4..<14, id: \.self) { i in
                        Text("\(i) hours").tag(i)
                    }
                }.pickerStyle(MenuPickerStyle())
                    .listRowBackground(Color.appThird)
            }
        }
    }

    struct WindDownTimeSelector: View {
        @Binding var windDownTime: Int

        var body: some View {
            Section(header: Text("\(Image(systemName: "moonset.fill")) Wind down reminder")) {
                HStack {
                    Picker("Notify me ", selection: $windDownTime) {
                        ForEach(5..<60, id: \.self) { i in
                            Text("\(i) mins").tag(i)
                        }
                    }.pickerStyle(MenuPickerStyle())
                    Text(" before bedtime.")
                }
                .listRowBackground(Color.appThird)
                
            }
        }
    }


}
