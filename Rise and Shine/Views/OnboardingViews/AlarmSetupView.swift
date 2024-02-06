//
//  AlarmSetupView.swift
//  Rise and Shine
//
//  Created by loren on 2/5/24.
//

import Foundation
import SwiftUI

struct AlarmSetupView: View {
    
    @AppStorage("wakeUpOffsetHours") var wakeUpOffsetHours = Constants.wakeUpOffsetHoursDefault
    @AppStorage("wakeUpOffsetMinutes") var wakeUpOffsetMinutes = Constants.wakeUpOffsetMinutesDefault
    @AppStorage("beforeSunrise") var beforeSunrise = true
    
    var body: some View {
        NavigationView {
            
            ZStack {
                Color.appPrimary.edgesIgnoringSafeArea(/*@START_MENU_TOKEN@*/.all/*@END_MENU_TOKEN@*/)
          
            VStack {

                VStack {
                    Text("Sunrise Alarm Time").font(.title).padding(.vertical)
                    Text("Choose when you would like to be woken up each day in relation to the sunrise.")
                }
                .padding(.horizontal)
                
                Spacer()
                
                Image("sunrise")
                Spacer()
                
                // Picker and settings
                VStack {
                    Text("I want to wake up")
                    HStack {
                        Spacer()
                        Picker("", selection: $wakeUpOffsetHours) {
                            ForEach(0..<4, id: \.self) { i in
                                Text("\(i) hours").tag(i)
                            }
                        }.pickerStyle(MenuPickerStyle())
                            .background(Color.white)
                            .cornerRadius(10)
                        
                        Spacer()
                        
                        
                        Text("and")
                        
                        Spacer()
                        
                        Picker("", selection: $wakeUpOffsetMinutes) {
                            ForEach(0..<12, id: \.self) { index in
                                Text("\(index * 5) mins").tag(index * 5)
                            }
                        }.pickerStyle(MenuPickerStyle())
                            .background(Color.white)
                            .cornerRadius(10)
                        
                        Spacer()
                    }
                    
                    Picker("", selection: $beforeSunrise) {
                        Text("Before Sunrise").tag(true)
                        Text("After Sunrise").tag(false)
                    }.padding(.vertical).pickerStyle(SegmentedPickerStyle())
                }
                
                
                // Next button at the bottom
                NavigationLink(destination: SleepGoalSetupView()) {
                    Text("Next")
                        .foregroundColor(.black)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(10)
                }
                .padding(.bottom)
                
                
                
                
            }
            .foregroundColor(.white)
                
                
            }
            
        }
        
    }
}



#Preview {
    AlarmSetupView()
}
    

