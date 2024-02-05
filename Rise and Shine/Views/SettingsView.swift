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
    @AppStorage("wakeUpOffsetHours") private var wakeUpOffsetHours = Constants.wakeUpOffsetHoursDefault
    @AppStorage("wakeUpOffsetMinutes") private var wakeUpOffsetMinutes = Constants.wakeUpOffsetMinutesDefault
    @AppStorage("beforeSunrise") private var beforeSunrise = true
    @AppStorage("targetHoursOfSleep") private var targetHoursOfSleep = Constants.targetHoursOfSleepDefault
    @AppStorage("windDownTime") private var windDownTime = Constants.windDownTimeDefault
    @AppStorage("currentCity") private var currentCity = "Location: Please Update"
    
    var body: some View {
        NavigationView {
            Form {
                locationSelector
//                alarmTimeSelector
//                targetHoursOfSleepSelector
//                windDownTimeSelector
                settingsComponents.AlarmTimeSelector(wakeUpOffsetHours: $wakeUpOffsetHours, wakeUpOffsetMinutes: $wakeUpOffsetMinutes, beforeSunrise: $beforeSunrise)
                settingsComponents.TargetHoursOfSleepSelector(targetHoursOfSleep: $targetHoursOfSleep)
                settingsComponents.WindDownTimeSelector(windDownTime: $windDownTime)
                notificationSettingsSection
                dataManagementSection
                attributionsSection
            }
            .navigationTitle("Settings")
        }
    }
    

    
    private var locationSelector: some View {
        Section(header: Text("Location:")) {
            Text(currentCity)
        }
    }
    
    private var alarmTimeSelector: some View {
        Section(header: Text("Alarm time:")) {
            HStack {
                Text("Wake up ")
                
                Picker("", selection: $wakeUpOffsetHours) {
                    ForEach(0..<4, id: \.self) { hours in
                        Text("\(hours) hours").tag(hours)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                
                Picker("", selection: $wakeUpOffsetMinutes) {
                    ForEach(0..<60, id: \.self) { minutes in
                        Text("\(minutes) mins").tag(minutes)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
            
            Picker("", selection: $beforeSunrise) {
                Text("Before Sunrise").tag(true)
                Text("After Sunrise").tag(false)
            }
            .pickerStyle(SegmentedPickerStyle())
        }
    }
    
    private var targetHoursOfSleepSelector: some View {
        Section(header: Text("Target Hours of Sleep")) {
            Picker("Sleep Goal: ", selection: $targetHoursOfSleep) {
                ForEach(4..<14, id: \.self) { hours in
                    Text("\(hours) hours").tag(hours)
                }
            }
            .pickerStyle(MenuPickerStyle())
        }
    }
    
    private var windDownTimeSelector: some View {
        Section(header: Text("Wind down reminder")) {
            HStack {
                Picker("Notify me ", selection: $windDownTime) {
                    ForEach(5..<60, id: \.self) { minutes in
                        Text("\(minutes) mins").tag(minutes)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                Text(" before bedtime.")
            }
        }
    }
    
    private var notificationSettingsSection: some View {
        Section(header: Text("Notification Settings")) {
            NavigationLink(destination: NotificationsView()) {
                Label("Notification Settings", systemImage: "line.horizontal.3")
                    .foregroundColor(.blue)
                    .imageScale(.large)
                    .padding()
            }
            
            Button("Update Notifications Permissions") {
                Task {
                    NotificationManager.requestNotificationPermission()
                }
            }
        }
    }
    
    private var dataManagementSection: some View {
        Section(header: Text("Data Management")) {
            Button("Reset Alarm Preferences") {
                Task {
                    clearUserDefaults()
                }
            }
            
            Button("Erase All App Data") {
                Task {
                    clearUserDefaults()
                    AppDataManager.deleteFile(fileName: Constants.alarmDataFileName)
                    AppDataManager.deleteFile(fileName: Constants.sunDataFileName)
                }
            }
        }
    }
    
    private var attributionsSection: some View {
        Section(header: Text("Attributions")) {
            Link("Data from SunriseSunset.io", destination: URL(string: "https://sunrisesunset.io/api/")!)
                .padding()
        }
    }

}

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
        }
    }
    
    struct TargetHoursOfSleepSelector: View {
        @Binding var targetHoursOfSleep: Int

        var body: some View {
            Section(header: Text("Target Hours of Sleep")) {
                Picker("Sleep Goal: ", selection: $targetHoursOfSleep) {
                    ForEach(4..<14, id: \.self) { i in
                        Text("\(i) hours").tag(i)
                    }
                }.pickerStyle(MenuPickerStyle())
            }
        }
    }

    struct WindDownTimeSelector: View {
        @Binding var windDownTime: Int

        var body: some View {
            Section(header: Text("Wind down reminder")) {
                HStack {
                    Picker("Notify me ", selection: $windDownTime) {
                        ForEach(5..<60, id: \.self) { i in
                            Text("\(i) mins").tag(i)
                        }
                    }.pickerStyle(MenuPickerStyle())
                    Text(" before bedtime.")
                }
            }
        }
    }


}



#Preview {
    SettingsView()
}



