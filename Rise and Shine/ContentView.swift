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
    @State private var beforeSunrise = true
    @State private var targetHoursOfSleep = 8
    @State private var windDownTime = 59
    @State private var sunData: SunData?
    @State private var locationData: LocationManager?
    @State private var currentDate = fetchDate()
    @State private var alarmTime: Date?
    
    var body: some View {
        NavigationView {
            Form {
                // Use the new function for the button action
                updateButton
                
                Section(header: Text("Location:")) {
                    VStack {
                        Text("City: " + fetchLocation(locationManager: locationManager))

                        
                    }
                }
                
                Section(header: Text("Sunrise Sunset")) {
                    Text("Date: " + (currentDate ?? "Failed to fetch."))
                    if let sunrise = sunData?.sunrise, let sunset = sunData?.sunset {
                        Text("Sunrise Time: \(sunrise)")
                        Text("Sunset Time: \(sunset)")
                    } else {
                        Text("Please Update Location")
                    }
                }
                
                
                
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
                    Picker("Direction", selection: $beforeSunrise) {
                        Text("Before Sunrise").tag(true)
                        Text("After Sunrise").tag(false)
                    }.pickerStyle(SegmentedPickerStyle())
                    
                    if let alarmTimeString = alarmTime {
                        
                        Text("Alarm Time: \(formattedDateString(date: alarmTimeString)) ")
                        
                    }
                    else {
                        Text("No Alarm Set")
                    }
                    
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
                        Picker("Notify me ", selection: $windDownTime) {
                            ForEach(0..<60, id: \.self) { i in
                                Text("\(i) mins").tag(i)
                            }
                        }.pickerStyle(MenuPickerStyle())
                        Text(" before bedtime.")
                    }
                    
                    
                }
                
                VStack {
                    Link("Data from SunriseSunset.io", destination: URL(string: "https://sunrisesunset.io/api/")!)
                        .padding()
                }

            }
            .navigationTitle("Settings").onAppear {
                // Initialize sunData when the view appears
                if let location = locationManager.currentLocation {
                    Task {
                        do {
                            sunData = try await fetchSunDataFromAPI(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude, date: currentDate ?? "2000-01-30")
                        } catch {
                            print("Error fetching sunrise data: \(error)")
                        }
                    }
                }
            }
        }
    }
    
    private func updateData(latitude: Double, longitude: Double) {
        Task {
            do {
                sunData = try await fetchSunDataFromAPI(latitude: latitude, longitude: longitude, date: currentDate ?? "2000-01-30")
                
                // Move the calculation of alarmTime here
                let alarmOffset = wakeUpOffsetMinutes + (wakeUpOffsetHours*60)
                alarmTime = calculateWakeTime(sunriseTime: sunData!.sunrise, alarmOffsetMinutes: alarmOffset, beforeSunrise: beforeSunrise)
                
            } catch {
                print("Error fetching sunrise data: \(error)")
            }
        }
    }

    private var updateButton: some View {
        Button("Refresh") {
            locationManager.locationManager.requestLocation()
            
            // Fetch sunrise data when location is available
            if let location = locationManager.currentLocation {
                updateData(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
            }
        }
        .padding()
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

func fetchLocation(locationManager: LocationManager) -> String {
    guard let status = locationManager.locationStatus else {
        return "Unknown Location Access Status"
    }

    switch status {
    case .authorizedAlways, .authorizedWhenInUse:
        if locationManager.currentLocation != nil {
            return locationManager.cityName ?? "Unknown City"
        } else {
            return "Location not available"
        }
    case .denied, .restricted:
        return "Location Access Denied"
    case .notDetermined:
        return "Location Access Not Determined"
    @unknown default:
        return "Error fetching location"
    }
}

func fetchSunDataFromAPI(latitude: Double?, longitude: Double?, date: String) async throws -> SunData? {
    guard let latitude = latitude, let longitude = longitude else {
        return nil
    }

    let url = URL(string: "https://api.sunrisesunset.io/json?lat=\(latitude)&lng=\(longitude)&date=\(date)")!
    print(url)

    let (data, _) = try await URLSession.shared.data(from: url)

    let decoded = try JSONDecoder().decode(SunApiResponse.self, from: data)

    return decoded.results
}

func fetchDate() -> String? {
    
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    
    let currentDate = Date()
    let formattedDate = dateFormatter.string(from: currentDate)
    
    if !formattedDate.isEmpty {
        return formattedDate
    }
    else {
        return nil
    }
    
}

func calculateWakeTime(sunriseTime: String, alarmOffsetMinutes: Int, beforeSunrise: Bool) -> Date {
    
    let alarmOffsetMinutes = beforeSunrise ? -alarmOffsetMinutes : alarmOffsetMinutes
    // Step 1: Convert sunriseTime string to Date
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "h:mm:ss a"
    dateFormatter.locale = Locale(identifier: "en_US_POSIX") // Set the locale to ensure proper parsing
    
    guard let sunriseDate = dateFormatter.date(from: sunriseTime) else {
        fatalError("Invalid date format for sunriseTime")
    }
    
    // Step 2: Add alarmOffsetMinutes to get alarm time
    let calendar = Calendar.current
    if let alarmTime = calendar.date(byAdding: .minute, value: alarmOffsetMinutes, to: sunriseDate) {
        return alarmTime
    } else {
        fatalError("Error calculating alarm time")
    }
}

func formattedDateString(date: Date) -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "h:mm:ss a"
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    return dateFormatter.string(from: date)
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
