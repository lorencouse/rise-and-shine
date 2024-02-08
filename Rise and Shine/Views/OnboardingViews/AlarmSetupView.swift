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
    @State private var sunData: [SunData] =  AppDataManager.loadFile(fileName: Constants.sunDataFileName, type: [SunData].self) ?? []
    @State private var alarmSchedule: [AlarmSchedule] = AppDataManager.loadFile(fileName: Constants.alarmDataFileName, type: [AlarmSchedule].self) ?? []
    @State private var alarmTime = ""
    
    var body: some View {
            
            ZStack {
                Color.appPrimary.edgesIgnoringSafeArea(/*@START_MENU_TOKEN@*/.all/*@END_MENU_TOKEN@*/)
          
            VStack {

                VStack {
                    Text("Sunrise Alarm Time").font(.title).padding(.vertical)
                    

                
                
                Spacer()
                
                Image("sunrise")
                Spacer()
                
                // Picker and settings
                VStack {
                    Text("Choose when you want to wake up each day.")
                        
                }
                .padding(.bottom)
                    
                            Text("Sunrise: \(sunData.first?.sunrise ?? "")")
                            Text("Alarm: \(alarmTime)")
                                .padding(.bottom)

                        


                   Spacer()
                    Text("I want to wake up")
                    HStack {
                        Spacer()
                        Picker("", selection: $wakeUpOffsetHours) {
                            ForEach(0..<4, id: \.self) { i in
                                Text("\(i) hours").tag(i)
                            }
                        }.pickerStyle(MenuPickerStyle())
                            .onChange(of: wakeUpOffsetHours) { _ in
                                updateAlarmTime()
                            }

                        
                        Spacer()
                        
                        
                        Text("and")
                        
                        Spacer()
                        
                        Picker("", selection: $wakeUpOffsetMinutes) {
                            ForEach(0..<12, id: \.self) { index in
                                Text("\(index * 5) mins").tag(index * 5)
                            }
                        }.pickerStyle(MenuPickerStyle())
                            .pickerStyle(MenuPickerStyle())
                                .onChange(of: wakeUpOffsetMinutes) { _ in
                                    updateAlarmTime()
                                }
                        
                        Spacer()
                    }
                    
                    Picker("", selection: $beforeSunrise) {
                        Text("Before Sunrise").tag(true)
                        Text("After Sunrise").tag(false)
                    }.padding().pickerStyle(SegmentedPickerStyle())
                }
                .onChange(of: beforeSunrise) { _ in
                    updateAlarmTime()
                }
                

                
                
                // Next button at the bottom
                NavigationLink(destination: SleepGoalSetupView()) {
                    
                    HStack {
                        Spacer()
                        Text("Next")
                        Spacer()
                    }
                    .foregroundColor(.black)
                    .padding(.all)
                    .background(Color.accentColor)
                    .cornerRadius(10)


                }
                .padding(.all)
                
                
                
                
            }
            .foregroundColor(.white)
            .onAppear {
                updateAlarmTime()
                
            }
                
                
            }
        
    }
    
    private func updateAlarmTime() {
        calculateScheduleForSunData(sunData)
        alarmSchedule = AppDataManager.loadFile(fileName: Constants.alarmDataFileName, type: [AlarmSchedule].self) ?? alarmSchedule
        alarmTime = String(alarmSchedule.first?.alarmTime.dropFirst(10)  ?? "")
    }
}



#Preview {
    AlarmSetupView()
}
    

