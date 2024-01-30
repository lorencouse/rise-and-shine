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
    @State private var sunData: [SunData] = (AppDataManager.loadSunDataFile() ?? [])
    @State private var alarmSchedule: [AlarmSchedule] = (AppDataManager.loadAlarmsFile() ?? [])
    @State private var selectedDate = Date.now



    var body: some View {
        NavigationView {
            VStack {

            navigationBar
               formView

                }
                
                
                .onAppear() {
                    loadData()

                }
                
            }
        }
    
    
    private var navigationBar: some View {
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
        
        
    }
    
    private var formView: some View {
        Form {
            
            Section {
                Text("Location: \(UserDefaults.standard.currentCity)")
            }
            
                Section {
                    
                    datePickerView
                    timesAndAlarmsSection
                    
 
                }
                

            updateButtons
            
        }
        

    }
    
    
    
    private var datePickerView: some View {
        DatePicker("Choose Date", selection: $selectedDate, in: Date.now..., displayedComponents: .date)
            .datePickerStyle(GraphicalDatePickerStyle())
            .frame(maxHeight: 400)
            .onChange(of: selectedDate) { _ in
                checkAndFetchSunData()
            }
    }
    
    private var timesAndAlarmsSection: some View {
        List {
            // Alarm Data
            if let data = alarmSchedule.first(where: { $0.date == formattedDateString(date: selectedDate) }) {
                alarmSection(data)
            } else {
                if sunData.isEmpty {
                    Text("Fetching data for this date...")
                        .onAppear {
                            fetchSunDataForSelectedDate()
                        }
                } else {
                    Text("No alarm data available for this date")
                }
            }

            // Sun Data
            if let data = sunData.first(where: { $0.date == formattedDateString(date: selectedDate) }) {
                sunDataSection(data)
            } else {
                Text("No sun data available for this date")
            }
        }
    }



    private func alarmSection(_ data: AlarmSchedule) -> some View {
        Section(header: Text("Date: \(data.date)")) {
            Text("Sunrise Time: \(data.sunriseTime)")
            Text("Alarm Time: \(data.alarmTime)")
            Text("Bed Time: \(data.bedTime)")
            Text("Sleep Reminder: \(data.windDownTime)")
        }
    }

    private func sunDataSection(_ data: SunData) -> some View {
        Section {
            Text("Sunset: \(data.sunset)")
            Text("First Light: \(data.firstLight)")
            Text("Last Light: \(data.lastLight)")
            Text("Dawn: \(data.dawn)")
            Text("Dusk: \(data.dusk)")
            Text("Day Length: \(data.dayLength)")
        }
    }

    
    private func checkAndFetchSunData() {
        if !sunData.contains(where: { $0.date == formattedDateString(date: selectedDate) }) {
            fetchSunDataForSelectedDate()
            
        }
    }
    
    
    private func fetchSunDataForSelectedDate() {
        Task {
            do {
                if let newData = try await APIManager.fetchMissingSunDataFromAPI(latitude: UserDefaults.standard.currentLatitude, longitude: UserDefaults.standard.currentLongitude, startDate: formattedDateString(date: selectedDate)) {
                    sunData = newData
                    calculateScheduleForSunData(newData)
                    alarmSchedule = AppDataManager.loadAlarmsFile() ?? alarmSchedule
                }
            } catch {
                print("Error fetching sun data: \(error)")
            }
        }
    }
    
    private var updateButtons: some View {
        Section(header: Text("Sunrise Data: \(UserDefaults.standard.currentCity)")){

                
            Button("Update") {
                Task {
                    fetchLocation(locationManager: locationManager)
                    await updateData()
                    sunData = AppDataManager.loadSunDataFile() ?? []
                    alarmSchedule = (AppDataManager.loadAlarmsFile() ?? [])
                }
            }
            
//            Button("Clear All") {
//                Task {
//                    alarmSchedule = []
//                    sunData = []
//                }
//            }
            
            }
    }
    
    private func loadData() {
        Task {
            fetchLocation(locationManager: locationManager)
            await updateData()
            sunData = AppDataManager.loadSunDataFile() ?? []
            alarmSchedule = AppDataManager.loadAlarmsFile() ?? []
        }
    }

    //    ContentView Close

    }








#Preview {
    ContentView()
}
