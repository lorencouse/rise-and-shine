//
//  Rise_and_ShineApp.swift
//  Rise and Shine
//
//  Created by loren on 1/13/24.
//

import SwiftUI

@main
struct Rise_and_ShineApp: App {
    init() {
     UINavigationBar.appearance().largeTitleTextAttributes = [.foregroundColor: UIColor.white]
     UINavigationBar.appearance().titleTextAttributes = [.foregroundColor: UIColor.white]
   }
    
    @AppStorage("onboardingCompleted") private var onboardingCompleted: Bool = false

    var body: some Scene {
        WindowGroup {
            
            if onboardingCompleted {
                
                ContentView()
                
            } else {
                AlarmSetupView()
            }

        }
    }
    
}
