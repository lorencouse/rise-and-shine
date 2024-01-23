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
    @State private var locationData: LocationManager?

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




func fetchDate() -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    return dateFormatter.string(from: Date())
}

func formattedDateString(date: Date) -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "h:mm:ss a"
    return dateFormatter.string(from: date)
}

func fetchLocation(locationManager: LocationManager) -> String {
    guard let status = locationManager.locationStatus else {
        return "Unknown Location Access Status"
    }

    switch status {
    case .authorizedAlways, .authorizedWhenInUse:
        if locationManager.currentLocation != nil {
            UserDefaults.standard.setValue( locationManager.currentLocation?.coordinate.latitude, forKey: "currentLatitude")
            UserDefaults.standard.setValue( locationManager.currentLocation?.coordinate.longitude, forKey: "currentLongitude")
            UserDefaults.standard.setValue( locationManager.cityName, forKey: "currentCity")
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







#Preview {
    ContentView()
}
