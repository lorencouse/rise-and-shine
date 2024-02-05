//
//  AlarmSetupView.swift
//  Rise and Shine
//
//  Created by loren on 2/5/24.
//

import Foundation
import SwiftUI

struct SleepGoalSetupView: View {
    
    @AppStorage("targetHoursOfSleep") var targetHoursOfSleep = Constants.targetHoursOfSleepDefault
    @AppStorage("targetMinutesOfSleep") var targetMinutesOfSleep = Constants.targetMinutesOfSleep
    
    var body: some View {
        
//        NavigationView {
            
            VStack {
                
                
                
                VStack {
                    
                    Text("Set Your Sleep Goal").font(.title).padding(.vertical)
                    
                    Text("Choose how many hours of sleep you would like to get each night. We will remind you when it's time to go to bed to reach your daily sleep goal.")
                    
                    
                }
                .padding(.horizontal)
                Spacer()
                
                VStack {
                    Text("I want to get")
                    HStack {
                        Spacer()
                        Picker("Sleep Goal: ", selection: $targetHoursOfSleep) {
                            ForEach(4..<14, id: \.self) { i in
                                Text("\(i) hours").tag(i)
                            }
                        }.pickerStyle(MenuPickerStyle())
                        Text("and ")
                        
                        Picker("", selection: $targetMinutesOfSleep) {
                            ForEach(0..<12, id: \.self) { index in
                                Text("\(index * 5) mins").tag(index * 5)
                            }
                        }.pickerStyle(MenuPickerStyle())
                        Spacer()
                    }
                    Text("of sleep each night.")
                        .padding(.bottom)
                    
                    
                    
                }
                
                NavigationLink(destination: WindDownSetupView()) {
                    Text("Next")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding(.bottom)
            }
            
//        }
    }
    
    }


#Preview {
    SleepGoalSetupView()
}
    

