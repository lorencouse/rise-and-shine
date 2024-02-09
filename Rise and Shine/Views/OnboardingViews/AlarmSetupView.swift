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
                    HeaderView(title: "Sunrise Alarm Time", subtitle: "Choose when you want to wake up each day.", imageName: "sun.haze.circle")
                    Spacer()
                    
                    TimesPairView(leftSymbolName: "sun.haze.circle", leftText: "Sunrise\n\(sunData.first?.sunrise ?? "")", rightSymbolName: "alarm", rightText: "Alarm\n \(alarmTime)")
                    
                    
                    Spacer()
                    Text("I want to wake up")
                    HStack {
                        Spacer()
                        
                        CustomPicker(
                            label: "",
                            range: 0...3, // For wake-up offset hours from 0 to 3
                            step: 1, // Increment by 1 hour
                            unit: "hours",
                            selection: $wakeUpOffsetHours,
                            onChange: updateAlarmTime
                        )
                        
                        Spacer()
                        
                        Text("and")
                        
                        Spacer()
                        
                        CustomPicker(
                            label: "",
                            range: 0...11, // For wake-up offset minutes in 5-minute increments
                            step: 5, // Increment by 5 minutes
                            unit: "mins",
                            selection: $wakeUpOffsetMinutes,
                            onChange: updateAlarmTime
                        )
                        
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
                
                
                NavigationButton(destination: SleepGoalSetupView(), label: "Next")
                
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


