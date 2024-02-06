//
//  SettingsComponents.swift
//  Rise and Shine
//
//  Created by loren on 2/6/24.
//

import Foundation
import SwiftUI


class settingsComponents {
    struct AlarmTimeSelector: View {
        @Binding var wakeUpOffsetHours: Int
        @Binding var wakeUpOffsetMinutes: Int
        @Binding var beforeSunrise: Bool

        var body: some View {
            Section(header: Text("Alarm time:")) {
                HStack {
                    Text("Wake up ")

                    Picker("", selection: $wakeUpOffsetHours) {
                        ForEach(0..<4, id: \.self) { i in
                            Text("\(i) hours").tag(i)
                        }
                    }.pickerStyle(MenuPickerStyle())

                    Picker("", selection: $wakeUpOffsetMinutes) {
                        ForEach(0..<60, id: \.self) { i in
                            Text("\(i) mins").tag(i)
                        }
                    }.pickerStyle(MenuPickerStyle())
                }
                Picker("", selection: $beforeSunrise) {
                    Text("Before Sunrise").tag(true)
                    Text("After Sunrise").tag(false)
                }.pickerStyle(SegmentedPickerStyle())
            }
            .listRowBackground(Color.appThird)
        }
    }
    
    struct TargetHoursOfSleepSelector: View {
        @Binding var targetHoursOfSleep: Int

        var body: some View {
            Section(header: Text("Target Hours of Sleep")) {
                Picker("Sleep Goal: ", selection: $targetHoursOfSleep) {
                    ForEach(4..<14, id: \.self) { i in
                        Text("\(i) hours").tag(i)
                    }
                }.pickerStyle(MenuPickerStyle())
                    .listRowBackground(Color.appThird)
            }
        }
    }

    struct WindDownTimeSelector: View {
        @Binding var windDownTime: Int

        var body: some View {
            Section(header: Text("Wind down reminder")) {
                HStack {
                    Picker("Notify me ", selection: $windDownTime) {
                        ForEach(5..<60, id: \.self) { i in
                            Text("\(i) mins").tag(i)
                        }
                    }.pickerStyle(MenuPickerStyle())
                    Text(" before bedtime.")
                }
                .listRowBackground(Color.appThird)
                
            }
        }
    }


}
