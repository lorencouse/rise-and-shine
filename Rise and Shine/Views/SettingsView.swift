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
    
//    Read Deafaults
    @AppStorage("wakeUpOffsetHours") private var wakeUpOffsetHours = Constants.wakeUpOffsetHoursDefault
    @AppStorage("wakeUpOffsetMinutes") private var wakeUpOffsetMinutes = Constants.wakeUpOffsetMinutesDefault
    @AppStorage("beforeSunrise") private var beforeSunrise = true
    @AppStorage("targetHoursOfSleep") private var targetHoursOfSleep = Constants.targetHoursOfSleepDefault
    @AppStorage("windDownTime") private var windDownTime = Constants.windDownTimeDefault
    
//    Load JSON Data
    @State private var sunData: [SunData] =  AppDataManager.loadFile(fileName: Constants.sunDataFileName, type: [SunData].self) ?? []
    @State private var showingResetAlert = false
    
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.appPrimary.edgesIgnoringSafeArea(.all)
                
                VStack {
                    
                    Form {
                        LocationSelector(sunData: $sunData, locationManager: locationManager)
                        
                        AlarmTimeSelector(wakeUpOffsetHours: $wakeUpOffsetHours, wakeUpOffsetMinutes: $wakeUpOffsetMinutes, beforeSunrise: $beforeSunrise)
                        TargetHoursOfSleepSelector(targetHoursOfSleep: $targetHoursOfSleep)
                        WindDownTimeSelector(windDownTime: $windDownTime)
                        
                        
                        Section(header: Text("\(Image(systemName: "music.note")) Alarm Sound")) {
                            SoundSelector()
                        }
                        

                        
                        Section(header: Text("\(Image(systemName: "bell.badge")) Notifications")) {
                            DNDExceptionEducationView()
                                .listRowBackground(Color.appThird)
                        }
                        

                        
                        
                        
                        VStack {

                            resetAppButton
                            
                            
                        }
                        .listRowBackground(Color.appPrimary)
                        
                        attributionsSection
                        
                        
                        
                    }
                    .scrollContentBackground(.hidden)
                    .foregroundColor(.white)
                    
                    
                    
                }
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.inline)
                
                
                
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
    
    
    
    
    
    private var resetAppButton: some View {
        
        CustomButton(title: "Reset App") {
            showingResetAlert = true
        }
        .alert(isPresented: $showingResetAlert) {
            Alert(
                title: Text("Reset App Data"),
                message: Text("Are you sure you want to reset all app data? This action cannot be undone."),
                primaryButton: .destructive(Text("Reset All App Data")) {
                    Task {
                        clearUserDefaults()
                        AppDataManager.deleteFile(fileName: Constants.alarmDataFileName)
                        AppDataManager.deleteFile(fileName: Constants.sunDataFileName)
                    }
                },
                secondaryButton: .cancel()
            )
        }
        
        
    }
    
    private var attributionsSection: some View {
        Section {
            
            Link("API Data from SunriseSunset.io", destination: URL(string: "https://sunrisesunset.io/api/")!)
            
        }
        .listRowBackground(Color.appPrimary)
        
    }
    
}








#Preview {
    SettingsView()
}



