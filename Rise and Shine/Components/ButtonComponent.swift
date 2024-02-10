//
//  ButtonComponent.swift
//  Rise and Shine
//
//  Created by loren on 2/6/24.
//

import Foundation
import SwiftUI
import UserNotifications
import AVKit


struct CustomButton: View {
    var title: String
    var action: () -> Void
    var foregroundColor: Color = .black // Default color, customizable
    var backgroundColor: Color = .accentColor // Default color, customizable

    var body: some View {
        Button(action: action) {
            HStack {
                Spacer()
                Text(title)
                Spacer()
            }

                .foregroundColor(foregroundColor)
                .padding(.all)
                .background(backgroundColor)
                .cornerRadius(10)
        }
        .padding(.all)
        .shadow(radius: /*@START_MENU_TOKEN@*/10/*@END_MENU_TOKEN@*/)
    }
}

struct UpdateLocationButton: View {
    
    @ObservedObject var locationManager: LocationManager
    
    var body: some View {
        CustomButton(title: "Update Location") {
            Task {
            locationManager.requestSingleLocationUpdate()
            }
        }
    }
}


struct FocusModesButton: View {
    // State to control the visibility of the alert
    @State private var showAlert = false

    var body: some View {
        
        CustomButton(title: "Allow Alarm Notifications", action: {
            // Set the state to true to show the alert
            showAlert = true
        })
        .alert("Notification Control", isPresented: $showAlert) {
            // Define actions for the alert
            Button("Got it", role: .cancel) { }
            Button("Go to Settings") {
                // Open settings app manually using URL scheme
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(settingsUrl) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
        } message: {
            Text("""
                Add this app to your "Focus Mode" exceptions:

                1. Open Settings app.
                2. Tap "Focus".
                3. Modify the "Do Not Disturb" and "Sleep" Focus.
                4. Tap "Apps".
                5. Search for "Rise and Shine".
                6. Tap "Allow Notifications".
                """)
        }
    }
}




