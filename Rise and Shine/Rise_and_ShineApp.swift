//
//  Rise_and_ShineApp.swift
//  Rise and Shine
//
//  Created by loren on 1/13/24.
//

import SwiftUI

@main
struct Rise_and_ShineApp: App {
    @AppStorage("isOnboardingCompleted") var isOnboardingCompleted: Bool = false

    var body: some Scene {
        WindowGroup {
            
            if isOnboardingCompleted {
                
                ContentView()
                
            } else {
                AlarmSetupView()
            }

        }
    }
    
}
