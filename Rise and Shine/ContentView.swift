//
//  ContentView.swift
//  Rise and Shine
//
//  Created by loren on 1/13/24.
//

import SwiftUI
import UserNotifications
import CoreLocation
import CoreLocationUI
import UIKit
import MapKit
import Foundation
import Combine

struct SunData: Decodable {
    let date: String
    let sunrise: String
    let sunset: String
    let firstLight: String
    let lastLight: String
    let dawn: String
    let dusk: String
    let solarNoon: String
    let goldenHour: String
    let dayLength: String
    let timezone: String
    let utcOffset: Int
    
    enum CodingKeys: String, CodingKey {
        case date
        case sunrise
        case sunset
        case firstLight = "first_light"
        case lastLight = "last_light"
        case dawn
        case dusk
        case solarNoon = "solar_noon"
        case goldenHour = "golden_hour"
        case dayLength = "day_length"
        case timezone
        case utcOffset = "utc_offset"
    }
}

struct SunApiResponse: Decodable {
    let results: SunData
    let status: String
    enum CodingKeys: String, CodingKey {
        case results
        case status
    }
}



struct ContentView: View {
    
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
                
                
                .navigationTitle("Rise and Shine")
                
            }
        }
    }
}

struct SettingsView: View {
    @ObservedObject private var locationManager = LocationManager()
    @State private var wakeUpOffsetHours = 0
    @State private var wakeUpOffsetMinutes = 0
    @State private var beforeSunrise = true // Default to "Before Sunrise"
    @State private var targetHoursOfSleep = 8
    @State private var windDownTime = 60
    @State private var sunData: SunData?
    @State private var locationData: LocationManager?

    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Location:")) {
                    HStack {
                        if let status = locationManager.locationStatus {
                            switch status {
                            case .authorizedAlways, .authorizedWhenInUse:
                                if let location = locationManager.currentLocation {
                                    Text(" \(locationManager.cityName ?? "Unknown City")")

                                    
                                } else {
                                    Text("Location not available")
                                }
                            case .denied, .restricted:
                                Text("Location Access Denied")
                            case .notDetermined:
                                Text("Location Access Not Determined")
                            default:
                                Text("Unknown Location Access Status")
                            }
                        }

                        Button("Update Location") {
                            locationManager.locationManager.requestLocation()

                            // Fetch sunrise data when location is available
                            Task {
                                do {
                                    if let location = locationManager.currentLocation {
                                        sunData = try await fetchSunDataFromAPI(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
                                    }
                                } catch {
                                    print("Error fetching sunrise data: \(error)")
                                }
                            }
                        }
                        .padding()
                    }
                }
                
                Section(header: Text("Sunrise Sunset")) {
                    if sunData != nil {
                        Text("Sunrise Time: \(sunData!.sunrise)")
                    } else {
                        Text("Sunrise Time not available")
                    }
                }
                
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
    public var locationManager = CLLocationManager()

    @Published var locationStatus: CLAuthorizationStatus?
    @Published var currentLocation: CLLocation?
    @Published var cityName: String?

    override init() {
        super.init()
        self.locationManager.delegate = self
        self.locationManager.requestWhenInUseAuthorization()
        self.locationManager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        self.locationStatus = status
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        self.currentLocation = location
        
        

        // Use reverse geocoding to get city name
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { (placemarks, error) in
            if let error = error {
                print("Reverse geocoding failed with error: \(error.localizedDescription)")
                return
            }

            if let placemark = placemarks?.first {
                self.cityName = placemark.locality ?? "Unknown City"
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error.localizedDescription)")
    }
}

func fetchSunDataFromAPI(latitude: Double?, longitude: Double?) async throws -> SunData? {
    guard let latitude = latitude, let longitude = longitude else {
        return nil
    }

    let url = URL(string: "https://api.sunrisesunset.io/json?lat=\(latitude)&lng=\(longitude)&timezone=UTC")!

    let (data, _) = try await URLSession.shared.data(from: url)

    let decoded = try JSONDecoder().decode(SunApiResponse.self, from: data)

    return decoded.results
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
