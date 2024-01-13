//
//  ContentView.swift
//  Rise and Shine
//
//  Created by loren on 1/13/24.
//

import SwiftUI
import UserNotifications
import CoreLocation
import Foundation

struct SunriseAPI {
    static func getSunriseTime(latitude: Double, longitude: Double, completion: @escaping (Date?) -> Void) {
        // Implement API call to get sunrise time
                // Parse the response and return the sunrise time
                // Example: Use URLSession to call a sunrise-sunset API
        
        
    }
}

struct ContentView: View {
    
    @ObservedObject private var locationManager = LocationManager()
    @ObservedObject private var notificationManager = NotificationManager()
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Rise and Shine")
                    .font(.largeTitle).padding()
                
                NavigationLink(destination: SettingsView()) {
                    Text("Settings")
                        .foregroundColor(Color.blue)
                }
                .onAppear {
                    notificationManager.requestNotificationAuthorization()
                }
                .navigationTitle("Rise and Shine")
                
            }
        }
    }
}

struct SettingsView: View {
    @State private var wakeUpOffsetHours = 0
    @State private var wakeUpOffsetMinutes = 0
    @State private var beforeSunrise = true // Default to "Before Sunrise"
    @State private var targetHoursOfSleep = 8
    @State private var windDownTime = 60

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Wake up time:")) {
                    
                    HStack {
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
                        Picker("Wind down reminder ", selection: $windDownTime) {
                            ForEach(0..<60, id: \.self) { i in
                                Text("\(i) mins").tag(i)
                            }
                        }.pickerStyle(MenuPickerStyle())
                    Text(" before bedtime.")
                    }
                    }

            }
            .navigationTitle("Settings")
        }
    }
}



class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private var locationManager = CLLocationManager()

    @Published var userLocation: CLLocationCoordinate2D?

    override init() {
        super.init()
        self.locationManager.delegate = self
        self.locationManager.requestWhenInUseAuthorization()
        self.locationManager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first?.coordinate else { return }
        userLocation = location
    }
}

class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    private let notificationCenter = UNUserNotificationCenter.current()

    func requestNotificationAuthorization() {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            // Handle authorization response
        }
    }

    func scheduleNotification(title: String, body: String, dateComponents: DateComponents) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        notificationCenter.add(request) { error in
            // Handle request completion
        }
    }
    

    
}



#Preview {
    ContentView()
}
