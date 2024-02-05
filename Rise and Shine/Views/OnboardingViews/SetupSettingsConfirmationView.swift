//
//  SetupSettingsConfirmationView.swift
//  Rise and Shine
//
//  Created by loren on 2/5/24.
//

import Foundation
import SwiftUI

struct SetupSettingsConfirmationView: View {
    
    
    @State private var wakeUpOffsetHours: Int = UserDefaults.standard.wakeUpOffsetHours
    @State private var wakeUpOffsetMinutes: Int = UserDefaults.standard.wakeUpOffsetMinutes
    @State private var beforeSunrise: Bool = UserDefaults.standard.beforeSunrise
    @State private var windDownTime: Int = UserDefaults.standard.windDownTime
    @State private var targetHoursOfSleep: Int = UserDefaults.standard.targetHoursOfSleep
    
    

    
    var body: some View {

            VStack {
                VStack {
                    Text("Confirm Your Settings").font(.title).padding(.vertical)
                    
                    
                    Spacer()

                        Form {
                            
                            
                            settingsComponents.AlarmTimeSelector(wakeUpOffsetHours: $wakeUpOffsetHours, wakeUpOffsetMinutes: $wakeUpOffsetMinutes, beforeSunrise: $beforeSunrise)
                            settingsComponents.TargetHoursOfSleepSelector(targetHoursOfSleep: $targetHoursOfSleep)
                            settingsComponents.WindDownTimeSelector(windDownTime: $windDownTime)
                        
                        
                        
                    }
                    
                    Button(action: finishOnboarding) {
                        Text("Finish")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    .padding(.bottom)
                    
                }
            }
        
        }
    
    private func finishOnboarding() {
        UserDefaults.standard.onboardingCompleted = true
    }
        

    
    
}



#Preview {
    SetupSettingsConfirmationView()
}
    


