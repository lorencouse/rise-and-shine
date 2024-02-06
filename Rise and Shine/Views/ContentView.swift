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
    @State private var sunData: [SunData] = []
    @State private var alarmSchedule: [AlarmSchedule] = []
    @State private var selectedDate = Date.now
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.appPrimary.edgesIgnoringSafeArea(.all)

                
                VStack {

                    navigationBar
                    
                    Text("Home").font(.title)
                        .foregroundColor(.white)
                    
                    
                    formView
                        .scrollContentBackground(.hidden)
                    updateButtons
                    
                }
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
                    .foregroundColor(Color.white)
                    .imageScale(.large)
                    .padding()
                Text("Settings")
                    .foregroundColor(Color.white)
                
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
                alarmsSection
                
            }
            
            Section {
                sunTimesSection
            }
            
        }
        
        
    }
    
    
    
    private var datePickerView: some View {
        DatePicker("Choose Date", selection: $selectedDate, in: Date.now..., displayedComponents: .date)
            .datePickerStyle(GraphicalDatePickerStyle())
            .frame(maxHeight: 400)
            .onChange(of: selectedDate) { _ in
                checkMissingData()
            }
    }
    
    private var alarmsSection: some View {
        List {
            // Alarm Data
            if let data = alarmSchedule.first(where: { $0.date == DateFormatter.formattedDateString(date: selectedDate) }) {
                alarmSection(data)
            } else {
                if sunData.isEmpty {
                    Text("Fetching sun data for this date...")
                } else {
                    Text("No alarm data available for this date")
                }
            }
            

        }
    }
    
    private var sunTimesSection: some View {
        List {
            // Sun Data
            if let data = sunData.first(where: { $0.date == DateFormatter.formattedDateString(date: selectedDate) }) {
                sunDataSection(data)
            } else {
                Text("Fetching alarm data for this date...")            }
        }
    }
    
    
    
    private func alarmSection(_ data: AlarmSchedule) -> some View {
        Section(header: Text("Today's Date: \(data.date)")) {
            
            if let currentIndex = alarmSchedule.firstIndex(where: { $0.date == data.date }),
               alarmSchedule.indices.contains(currentIndex + 1) {
                let nextDayData = alarmSchedule[currentIndex + 1]
                Text("Sunrise Time Tomorrow: \(nextDayData.sunriseTime)")
            } else {
                Text("Sunrise Time Tomorrow: Not available")
                
            }
            Text("Sleep Reminder Tonight: \(data.windDownTime)")
            Text("Bed Time Tonight: \(data.bedTime)")
            Text("Alarm Time Tomorrow: \(data.alarmTime)")
            
            
        }
    }
    
    private func sunDataSection(_ data: SunData) -> some View {
        Section {
            Text("All Sun Times for \(data.date)")
            Text("Sunrise: \(data.sunrise)")
            Text("Sunset: \(data.sunset)")
            Text("First Light: \(data.firstLight)")
            Text("Last Light: \(data.lastLight)")
            Text("Dawn: \(data.dawn)")
            Text("Dusk: \(data.dusk)")
            Text("Day Length: \(data.dayLength)")
        }
        
    }
    
    private func checkMissingData() {
        let dateString = DateFormatter.formattedDateString(date: selectedDate)

        let isSunDataMissing = !sunData.contains { $0.date == dateString }
        let isAlarmDataMissing = !alarmSchedule.contains { $0.date == dateString }

        if isSunDataMissing || isAlarmDataMissing {
            fetchMissingData()
        }
    }
    
    private func fetchMissingData() {
        Task {
            do {
                try await
                
                APIManager.fetchSunData(latitude: UserDefaults.standard.currentLatitude, longitude: UserDefaults.standard.currentLongitude, startDate: DateFormatter.formattedDateString(date: selectedDate), missingDate: true)
                
                sunData
                = AppDataManager.loadFile(fileName: Constants.sunDataFileName, type: [SunData].self) ?? sunData
                
                calculateScheduleForSunData(sunData)
                
                alarmSchedule = AppDataManager.loadFile(fileName: Constants.alarmDataFileName, type: [AlarmSchedule].self) ?? alarmSchedule
                
                
            }
            
            catch {
                print("Error fetching sun data: \(error)")
            }
            
        }
    }
    
    
    
    private var updateButtons: some View {
//        Section(header: Text("Sunrise Data: \(UserDefaults.standard.currentCity)")){
            
            
            Button("Update") {
                Task {
                    fetchLocation(locationManager: locationManager)
                    await updateData(date: selectedDate)
                    sunData = AppDataManager.loadFile(fileName: Constants.sunDataFileName, type: [SunData].self) ?? []
                    alarmSchedule = (AppDataManager.loadFile(fileName: Constants.alarmDataFileName, type: [AlarmSchedule].self) ?? [])
                }
            }
            .foregroundColor(.black)
            .padding()
            .background(Color.accentColor)
            .cornerRadius(10)
            
//        }
    }
    
    private func loadData() {
        Task {
            fetchLocation(locationManager: locationManager)
            await updateData(date: selectedDate)
            sunData = AppDataManager.loadFile(fileName: Constants.sunDataFileName, type: [SunData].self) ?? []
            alarmSchedule = AppDataManager.loadFile(fileName: Constants.alarmDataFileName, type: [AlarmSchedule].self) ?? []
        }
    }
    
    //    ContentView Close
    
}




#Preview {
    ContentView()
}
