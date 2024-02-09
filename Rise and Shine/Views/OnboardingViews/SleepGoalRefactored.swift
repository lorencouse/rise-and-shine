////
////  SleepGoalRefactored.swift
////  Rise and Shine
////
////  Created by loren on 2/9/24.
////
//
//import Foundation
//import SwiftUI
//
//struct SleepGoalSetupViewRefactored: View {
//    @AppStorage("targetHoursOfSleep") var targetHoursOfSleep = Constants.targetHoursOfSleepDefault
//    @AppStorage("targetMinutesOfSleep") var targetMinutesOfSleep = Constants.targetMinutesOfSleepDefault
//    @State private var sunData = loadSunData()
//    @State private var bedTime = ""
//    @State private var alarmTime = ""
//
//    var body: some View {
//        ZStack {
//            Color.appPrimary.edgesIgnoringSafeArea(.all)
//            VStack {
//                HeaderView(title: "Set Your Sleep Goal", subtitle: "We will remind you when it's time for bed.", imageName: "moon.zzz.fill")
//                InfoBlockView(symbolName: "sun.haze.circle", title: "Sleep Time", value: bedTime)
//                InfoBlockView(symbolName: "alarm", title: "Alarm", value: alarmTime)
//                Spacer()
//                SleepGoalPicker(hours: $targetHoursOfSleep, minutes: $targetMinutesOfSleep) {
//                    self.alarmTime = updateAlarmTime(sunData: sunData, alarmFileName: Constants.alarmDataFileName)
//                }
//                NavigationButton(destination: WindDownSetupView(), label: "Next")
//            }
//            .foregroundColor(.white)
//            .onAppear {
//                self.alarmTime = updateAlarmTime(sunData: sunData, alarmFileName: Constants.alarmDataFileName)
//            }
//        }
//    }
//}
//
