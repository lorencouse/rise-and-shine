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
    @AppStorage("targetMinutesOfSleep") var targetMinutesOfSleep = Constants.targetMinutesOfSleepDefault
    @State private var sunData: [SunData] =  AppDataManager.loadFile(fileName: Constants.sunDataFileName, type: [SunData].self) ?? []
    @State private var alarmSchedule: [AlarmSchedule] = AppDataManager.loadFile(fileName: Constants.alarmDataFileName, type: [AlarmSchedule].self) ?? []
    @State private var alarmTime = ""
    @State private var bedTime = ""
    
    var body: some View {
        
        
        ZStack {
            Color.appPrimary.edgesIgnoringSafeArea(.all)
            
            
            VStack {
                
                HeaderView(title: "Set Your Sleep Goal", subtitle: "We will remind you when it's time for bed.", imageName: "moon.zzz.fill")
                
                Spacer()
                
                VStack {
                    Spacer()
                    
                    TimesPairView(leftSymbolName: "sun.haze.circle", leftText: "Sleep Time\n\(bedTime)", rightSymbolName: "alarm", rightText: "Alarm\n \(alarmTime)")
                        .cornerRadius(20)
                    
                    Spacer()
                    Text("My sleep goal each night is")
                    Spacer()
                    HStack {
                        
                        
                        Spacer()
                        
                        CustomPicker(
                            label: "Sleep Goal",
                            range: 4...13,
                            step: 1,
                            unit: "hours",
                            selection: $targetHoursOfSleep,
                            onChange: updateSelectedTimes
                        )
                        
                        
                        Text("and")
                        
                        CustomPicker(
                            label: "",
                            range: 0...11,
                            step: 5,
                            unit: "mins",
                            selection: $targetMinutesOfSleep,
                            onChange: updateSelectedTimes
                        )
                        
                        Spacer()
                        
                    }
                    
                    Spacer()
                    
                    
                }
                .padding(.bottom)
                
                NavigationButton(destination: WindDownSetupView(), label: "Next")
                
                
            }
            .foregroundColor(.white)
            .onAppear {
                
                updateSelectedTimes()
                
            }
            
            
        }
        
    }
    
    func updateSelectedTimes() {
        calculateAlarms(sunData)
        alarmSchedule = AppDataManager.loadFile(fileName: Constants.alarmDataFileName, type: [AlarmSchedule].self) ?? alarmSchedule
        alarmTime = String(alarmSchedule.first?.alarmTime.convertToTimeWithoutSeconds()  ?? "")
        bedTime = String(alarmSchedule.first?.bedTime.convertToTimeWithoutSeconds()  ?? "")
    }
    
}


#Preview {
    SleepGoalSetupView()
}


