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
//import Combine

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
                    formView

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
                    .foregroundColor(Color.yellow)
                    .imageScale(.large)
                    .padding()
                Text("Settings")
                    .foregroundColor(Color.yellow)
                Spacer()
                
            }
            
            Spacer()
            
        }
        
        
        
    }
    
    private var formView: some View {
        Form {
            datePickerView
            
//            Section(header: Text("Location")) {
//                Text("\(UserDefaults.standard.currentCity)")
//                    .listRowBackground(Color.appThird)
                
                LocationSelector(sunData: $sunData, locationManager: locationManager)
                
//            }
            
            alarmsSection
            sunTimesSection
            updateButtons
            
        }
        .scrollContentBackground(.hidden)
        .foregroundColor(.white)
        
        
    }
    

    
    
    private var alarmsSection: some View {
        List {
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
        .listRowBackground(Color.appThird)
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))

        
    }
    
    
    
    private func alarmSection(_ data: AlarmSchedule) -> some View {
        Section(header: Text("\(Image(systemName: "alarm")) Alarm time")) {
            
            VStack(alignment: .leading) {
                
                if let currentIndex = alarmSchedule.firstIndex(where: { $0.date == data.date }),
                   alarmSchedule.indices.contains(currentIndex + 1) {
                    let nextDayData = alarmSchedule[currentIndex + 1]
                    TimesPairView(leftSymbolName: "sun.haze.circle", leftText: "Next Sunrise\n\(nextDayData.sunriseTime.dropSecondsFromTime())", rightSymbolName: "alarm", rightText: "Alarm\n \(data.alarmTime.convertToTimeWithoutSeconds())")
                } else {
                    Text("Sunrise Time Tomorrow: Not available")
                }
                
                TimesPairView(leftSymbolName: "moonset.fill", leftText: "Sleep Reminder\n \(data.windDownTime.convertToTimeWithoutSeconds())", rightSymbolName: "moon.zzz.fill", rightText: "Bed Time\n \(data.bedTime.convertToTimeWithoutSeconds())")
                
            }
            
        }
    }
    
    
    
    private var sunTimesSection: some View {
        List {
            if let data = sunData.first(where: { $0.date == DateFormatter.formattedDateString(date: selectedDate) }) {
                sunDataSection(data)
            } else {
                Text("Fetching alarm data for this date...")            }
        }
        .listRowBackground(Color.appThird)
    }
    
    private func sunDataSection(_ data: SunData) -> some View {
        Section(header: Text("For Today: \(data.date)")) {
            Text("Day Length: \(data.dayLength)")
            Text("Last Light: \(data.lastLight.dropSecondsFromTime())")
            Text("Sunset: \(data.sunset.dropSecondsFromTime())")
            Text("First Light: \(data.firstLight.dropSecondsFromTime())")
            Text("Dawn: \(data.dawn.dropSecondsFromTime())")
            
        }
        
    }
    

    
    
    private var datePickerView: some View {
        DatePicker("Choose Date", selection: $selectedDate, in: Date.now..., displayedComponents: .date)
            .datePickerStyle(GraphicalDatePickerStyle())
            .frame(maxHeight: 400)
            .onChange(of: selectedDate) { _ in
                checkMissingData()
            }
            .shadow(radius: 10)
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
                
                APIManager.fetchSunData(latitude: locationManager.currentLocation?.coordinate.latitude, longitude: locationManager.currentLocation?.coordinate.longitude, startDate: DateFormatter.formattedDateString(date: selectedDate), missingDate: true)
                
                sunData = loadSunData()
                
                calculateAlarms(sunData)
                
                alarmSchedule = loadAlarmSchedule()
                
            }
            
            catch {
                print("Error fetching sun data: \(error)")
            }
            
        }
    }
    
    
    
    private var updateButtons: some View {
        
        CustomButton(title: "Update") {
            Task {
                loadData()
            }
        }
        .listRowBackground(Color.appPrimary)
        
        
    }
    
    private func updateLists() {
        sunData = loadSunData()
        alarmSchedule = loadAlarmSchedule()
    }
    
    private func loadData() {
        Task {
            locationManager.requestSingleLocationUpdate()
            await updateSunData(date: DateFormatter.formattedDateString(date: selectedDate), locationManager: locationManager)
            updateAlarms()
            updateLists()
        }
    }
    
    //    ContentView Close
    
}




#Preview {
    ContentView()
}
