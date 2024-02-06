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
            ZStack {
                Color.appPrimary.edgesIgnoringSafeArea(.all)
                
                VStack {
                    
                    Form {
                        locationSelector
                        settingsComponents.AlarmTimeSelector(wakeUpOffsetHours: $wakeUpOffsetHours, wakeUpOffsetMinutes: $wakeUpOffsetMinutes, beforeSunrise: $beforeSunrise)
                        settingsComponents.TargetHoursOfSleepSelector(targetHoursOfSleep: $targetHoursOfSleep)
                        settingsComponents.WindDownTimeSelector(windDownTime: $windDownTime)
                        
                        
                        VStack {
     
                            eraseAllDataButton
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
    

    
    private var locationSelector: some View {
        Section(header: Text("Location:")) {
            Text(currentCity)
                .listRowBackground(Color.appThird)
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
 
    private var eraseAllDataButton: some View {
        
        CustomButton(title: "Erase All Data") {
            Task {
                AppDataManager.deleteFile(fileName: Constants.alarmDataFileName)
                AppDataManager.deleteFile(fileName: Constants.sunDataFileName)
            }
        }
        
    }
    
    private var resetAppButton: some View {
        
        CustomButton(title: "Reset App") {
            Task {
                clearUserDefaults()
                AppDataManager.deleteFile(fileName: Constants.alarmDataFileName)
                AppDataManager.deleteFile(fileName: Constants.sunDataFileName)
            }
        }
        
        
    }
    
    private var attributionsSection: some View {
        HStack {
            Spacer()
            Link("API Data from SunriseSunset.io", destination: URL(string: "https://sunrisesunset.io/api/")!)
            Spacer()
        }
        .listRowBackground(Color.appPrimary)

    }

}





#Preview {
    SettingsView()
}



