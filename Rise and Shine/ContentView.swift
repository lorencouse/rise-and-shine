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


var globalSunriseData: SunriseSunsetResponse?


struct SunriseSunsetResponse: Decodable {
    let results: SunriseSunsetResults
    let status: String

    struct SunriseSunsetResults: Decodable {
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
    @State private var sunriseTimeText = "Fetch location to update"
    
    var body: some View {
        NavigationView {
            Form {
                
                Section(header: Text("Location:")) {
                    HStack{
                        
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
                        }
                        .padding()
                    }
                }
                
                Button("Fetch Sunrise") {
                   fetchSunriseJSON(completion: <#T##(Result<SunriseSunsetResponse, Error>) -> Void#>)
                }
                
                Section(header: Text("Sunrise Sunset")) {
                   
                    Text("Sunrise: ")
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

func fetchSunriseJSON(completion: @escaping (Result<SunriseSunsetResponse, Error>) -> Void) {
    let url = URL(string: "https://api.sunrisesunset.io/json?lat=38.907192&lng=-77.036873&timezone=UTC&date=1990-05-22")!

    let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
        if let error = error {
            completion(.failure(error))
            return
        }

        if let data = data {
            do {
                let sunriseResponse: SunriseSunsetResponse = try JSONDecoder().decode(SunriseSunsetResponse.self, from: data)
                globalSunriseData = sunriseResponse // Store the data globally
                print(sunriseResponse)
                completion(.success(sunriseResponse))
            } catch {
                completion(.failure(error))
            }
        }
    }
    task.resume()
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

class DataManager {
    static let shared = DataManager()

    var sunriseData: SunriseSunsetResponse?

    private init() {} // Ensure only one instance

    func fetchSunriseJSON(completion: @escaping (Result<SunriseSunsetResponse, Error>) -> Void) {
        let url = URL(string: "https://api.sunrisesunset.io/json?lat=38.907192&lng=-77.036873&timezone=UTC&date=1990-05-22")!

        let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
            if let error = error {
                completion(.failure(error))
                return
            }

            if let data = data {
                do {
                    let sunriseResponse: SunriseSunsetResponse = try JSONDecoder().decode(SunriseSunsetResponse.self, from: data)
                    self.sunriseData = sunriseResponse
                    completion(.success(sunriseResponse))
                } catch {
                    completion(.failure(error))
                }
            }
        }
        task.resume()
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
