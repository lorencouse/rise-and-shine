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
    @State private var sunData: [SunData] =  AppDataManager.loadFile(fileName: Constants.sunDataFileName, type: [SunData].self) ?? []
    @State private var alarmSchedule: [AlarmSchedule] = AppDataManager.loadFile(fileName: Constants.alarmDataFileName, type: [AlarmSchedule].self) ?? []
    @State private var alarmTime = ""
    @State private var bedTime = ""
    
    var body: some View {
        

        ZStack {
            Color.appPrimary.edgesIgnoringSafeArea(.all)
            
            
            VStack {
                
                VStack {
                    
                    Text("Set Your Sleep Goal").font(.title).padding(.vertical)
                    
                    Text("We will remind you when it's time for bed.")
                    
                    
                }
                .padding(.horizontal)
                Spacer()
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 240))
                    .shadow(radius: /*@START_MENU_TOKEN@*/10/*@END_MENU_TOKEN@*/)

                Spacer()
                
                VStack {
                    
                    HStack {
                        Spacer()
                        Text("\(Image(systemName: "sun.haze.circle")) Sleep Time\n\(bedTime)")
                            .multilineTextAlignment(.center)
                            .padding()
                        
                        
                        Spacer()
                        
                        
                        Text("\(                Image(systemName: "alarm")) Alarm\n \(alarmTime)")
                            .multilineTextAlignment(.center)
                        
                        Spacer()
                        
                    }
                    .background(Color(.appThird))
                    .cornerRadius(20)
Spacer()
                    Text("My sleep goal each night is")
                    Spacer()
                    HStack {


                        Spacer()
                        Picker("Sleep Goal: ", selection: $targetHoursOfSleep) {
                            ForEach(4..<14, id: \.self) { i in
                                Text("\(i) hours").tag(i)
                            }
                        }.pickerStyle(MenuPickerStyle())
                            .onChange(of: targetHoursOfSleep) { _ in
                                updateAlarmTime()
                            }

                        
                        Text("and")
                        
                        Picker("", selection: $targetMinutesOfSleep) {
                            ForEach(0..<12, id: \.self) { index in
                                Text("\(index * 5) mins").tag(index * 5)

                            }
                        }.pickerStyle(MenuPickerStyle())
                            .onChange(of: targetMinutesOfSleep) { _ in
                                updateAlarmTime()
                            }

                        Spacer()

                    }
                    
                    Spacer()

                    
                }
                .padding(.bottom)
                
                NavigationLink(destination: WindDownSetupView()) {
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
        bedTime = String(alarmSchedule.first?.bedTime.dropFirst(10)  ?? "")
    }
    
    }


#Preview {
    SleepGoalSetupView()
}
    

