//
//  SetupSettingsConfirmationView.swift
//  Rise and Shine
//
//  Created by loren on 2/5/24.
//

import Foundation
import SwiftUI
import EventKit


struct SetupSettingsConfirmationView: View {
    
    
    @State private var wakeUpOffsetHours: Int = UserDefaults.standard.wakeUpOffsetHours
    @State private var wakeUpOffsetMinutes: Int = UserDefaults.standard.wakeUpOffsetMinutes
    @State private var beforeSunrise: Bool = UserDefaults.standard.beforeSunrise
    @State private var windDownTime: Int = UserDefaults.standard.windDownTime
    @State private var targetHoursOfSleep: Int = UserDefaults.standard.targetHoursOfSleep
    
    private let eventStore = EKEventStore()

    
    var body: some View {
        ZStack {
            Color.appPrimary.edgesIgnoringSafeArea(.all)
            VStack {
                VStack {
                    Text("Confirm Your Settings").font(.title).padding(.vertical)
                        .foregroundColor(.white)
                    
                    
                    Spacer()
                    
                    Form {
                        
                        
                        AlarmTimeSelector(wakeUpOffsetHours: $wakeUpOffsetHours, wakeUpOffsetMinutes: $wakeUpOffsetMinutes, beforeSunrise: $beforeSunrise)
                        TargetHoursOfSleepSelector(targetHoursOfSleep: $targetHoursOfSleep)
                        WindDownTimeSelector(windDownTime: $windDownTime)
                        
                        
                        
                    }
                    .scrollContentBackground(.hidden)
                    .foregroundColor(.white)
                    
                    finishButton
                    
                }
            }

        }

        }
    
    private func finishOnboarding() {
        UserDefaults.standard.onboardingCompleted = true
    }
    
    private var finishButton: some View {
        CustomButton(title: "Finish", action: finishOnboarding)
    }
    


    
    
}



#Preview {
    SetupSettingsConfirmationView()
}
    


