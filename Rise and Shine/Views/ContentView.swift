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
    @State private var sunData: [SunData] = (APIManager.loadSunDataFromFile() ?? [])
    @State private var alarmSchedule: [AlarmSchedule] = (loadSchedulesFromFile() ?? [])
    @State private var selectedDateIndex = 0 // Index for the selected date


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
                

                
                Form {
                    

                        
                    Section(header: Text("Sunrise Data: \(UserDefaults.standard.currentCity)")){
                            // Picker for selecting the date
                            Picker("Select Date", selection: $selectedDateIndex) {
                                ForEach(0 ..< sunData.count, id: \.self) { index in
                                    Text(self.sunData[index].date).tag(index)
                                }
                            }.pickerStyle(MenuPickerStyle())
                            
                        Button("Update") {
                            Task {
                                fetchLocation(locationManager: locationManager)
                                await updateData()
                                sunData = APIManager.loadSunDataFromFile() ?? []
                                alarmSchedule = (loadSchedulesFromFile() ?? [])
                            }
                        }
                        
                        Button("Clear All") {
                            Task {
                                alarmSchedule = []
                                sunData = []
                            }

                            
                        }
                        
                        }
                    
                        Section {
                            // List to display sun data for the selected date
                            List {
                                if alarmSchedule.indices.contains(selectedDateIndex) {
                                    let data = alarmSchedule[selectedDateIndex]
                                    Section(header: Text("Date: \(data.date)")) {
                                        Text("Sunrise Time: \(data.sunriseTime)")
                                        Text("Alarm Time: \(data.alarmTime)")
                                        Text("Bed Time: \(data.bedTime)")
                                        Text("Sleep Reminder: \(data.windDownTime)")
                                    }
                                }
                            }
                        }
                    
                        
                        Section {
                            // List to display sun data for the selected date
                            List {
                                if sunData.indices.contains(selectedDateIndex) {
                                    let data = sunData[selectedDateIndex]
                                    Section(header: Text("Date: \(data.date)")) {
                                        Text("Sunrise: \(data.sunrise)")
                                        Text("Sunset: \(data.sunset)")
                                        Text("First Light: \(data.firstLight)")
                                        Text("Last Light: \(data.lastLight)")
                                        Text("Dawn: \(data.dawn)")
                                        Text("Dusk: \(data.dusk)")
                                        Text("Day Length: \(data.dayLength)")
                                    }
                                }
                            }
                        }
    
                }
                

                }
                
                
                .navigationTitle("Rise and Shine")
                
            }
        }
    }




#Preview {
    ContentView()
}
