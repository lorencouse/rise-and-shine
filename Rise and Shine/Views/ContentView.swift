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
    @State private var sunData: [SunData] = (AppDataManager.loadSunDataFile() ?? [])
    @State private var alarmSchedule: [AlarmSchedule] = (AppDataManager.loadAlarmsFile() ?? [])
    @State private var selectedDateIndex = 0 // Index for the selected date
    @State private var selectedDate = Date.now



    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "line.horizontal.3")
                            .foregroundColor(Color.blue)
                            .imageScale(.large)
                            .padding()
                        Text("Settings")
                    }
                    
                    Spacer()


                }
            
                Form {
                    
                    Section {
                        Text("Location: \(UserDefaults.standard.currentCity)")
                    }
                    
                        Section {
                            
                            DatePicker("Enter your birthday", selection: $selectedDate, in: Date.now..., displayedComponents: .date)
                                .datePickerStyle(GraphicalDatePickerStyle())
                                .frame(maxHeight: 400)
                            
                            
                            List {
                                
//                                Alarm Data
                                if alarmSchedule.contains(where: { $0.date == formattedDateString(date: selectedDate) }) {
                                    if let data = alarmSchedule.first(where: { $0.date == formattedDateString(date: selectedDate) }) {
                                        Section(header: Text("Date: \(data.date)")) {
                                            Text("Sunrise Time: \(data.sunriseTime)")
                                            Text("Alarm Time: \(data.alarmTime)")
                                            Text("Bed Time: \(data.bedTime)")
                                            Text("Sleep Reminder: \(data.windDownTime)")
                                        }
                                    }
                                } else {
                                    Text("No data available for this date")
                                }
                                
//                                Sun Data
                                
                                if let data = sunData.first(where: { $0.date == formattedDateString(date: selectedDate) }) {
                                    Section {
                                        Text("Sunset: \(data.sunset)")
                                        Text("First Light: \(data.firstLight)")
                                        Text("Last Light: \(data.lastLight)")
                                        Text("Dawn: \(data.dawn)")
                                        Text("Dusk: \(data.dusk)")
                                        Text("Day Length: \(data.dayLength)")
                                    }
                                } else {
                                    Text("No data available for this date")
                                }
                                
                            }
                            
                        }
                        
    
                    Section(header: Text("Sunrise Data: \(UserDefaults.standard.currentCity)")){

                            
                        Button("Update") {
                            Task {
                                fetchLocation(locationManager: locationManager)
                                await updateData()
                                sunData = AppDataManager.loadSunDataFile() ?? []
                                alarmSchedule = (AppDataManager.loadAlarmsFile() ?? [])
                            }
                        }
                        
                        Button("Clear All") {
                            Task {
                                alarmSchedule = []
                                sunData = []
                            }

                            
                        }
                        
                        }
                    
                }
                

                }
                
                
                .onAppear() {
                    Task {
                        fetchLocation(locationManager: locationManager)
                        await updateData()
                        sunData = AppDataManager.loadSunDataFile() ?? []
                        alarmSchedule = AppDataManager.loadAlarmsFile() ?? []
                    }

                }
                
            }
        }
    }





#Preview {
    ContentView()
}
