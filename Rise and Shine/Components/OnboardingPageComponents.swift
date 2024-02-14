//
//  OnboardingPageComponents.swift
//  Rise and Shine
//
//  Created by loren on 2/9/24.
//

import Foundation
import SwiftUI

struct HeaderView: View {
    
    var header: String
    var text: String
    var imageName: String

    init(title: String, subtitle: String, imageName: String) {
        self.header = title
        self.text = subtitle
        self.imageName = imageName
    }
    
    var body: some View {
        
        VStack {
            
            Text(header).font(.title).padding(.vertical)
            
            Text(text)
            
            
        }
        .padding(.horizontal)
        Spacer()
        Image(systemName: imageName)
            .font(.system(size: 240))
            .shadow(radius: /*@START_MENU_TOKEN@*/10/*@END_MENU_TOKEN@*/)

        Spacer()
        
    }
    
}


struct NavigationButton<Destination: View>: View {
    var destination: Destination
    var label: String

    var body: some View {
        NavigationLink(destination: destination) {
            HStack {
                Spacer()
                Text(label)
                Spacer()
            }
            .foregroundColor(.white)
            .padding()
            .background(Color.accentColor)
            .cornerRadius(10)
        }
        .padding()
    }
}



struct TimesPairView: View {
    var leftSymbolName: String
    var leftText: String
    var rightSymbolName: String
    var rightText: String
    
    init(leftSymbolName: String, leftText: String, rightSymbolName: String, rightText: String) {
        self.leftSymbolName = leftSymbolName
        self.leftText = leftText
        self.rightSymbolName = rightSymbolName
        self.rightText = rightText
    }

    var body: some View {
        HStack {
            Spacer()
            Text("\(Image(systemName: leftSymbolName)) \(leftText)")
                .multilineTextAlignment(.center)

            Spacer()
            
            Text("\(Image(systemName: rightSymbolName)) \(rightText)")
                .multilineTextAlignment(.center)
                .padding(.vertical)
            Spacer()
        }
        .background(Color("appThird"))
        
    }
}

struct CustomPicker: View {
    var label: String
    var range: ClosedRange<Int>
    var step: Int
    var unit: String
    @Binding var selection: Int
    var onChange: () -> Void
    
    var body: some View {
        Picker(label.isEmpty ? "" : "\(label): ", selection: $selection) {
            ForEach(range.lowerBound...range.upperBound, id: \.self) { i in
                Text("\(i * step) \(unit)").tag(i * step)
            }
        }
        .pickerStyle(MenuPickerStyle())
        .onChange(of: selection) {
            onChange()
        }
    }
}



extension View {
    func updateAlarmTime(sunData: [SunData], alarmFileName: String) -> String {
        let alarmSchedule: [AlarmSchedule] = AppDataManager.loadFile(fileName: alarmFileName, type: [AlarmSchedule].self) ?? []
        return String(alarmSchedule.first?.alarmTime.dropFirst(10) ?? "")
    }
}


extension View {
    func updateBedTime(sunData: [SunData], alarmFileName: String) -> String {
        let alarmSchedule: [AlarmSchedule] = AppDataManager.loadFile(fileName: alarmFileName, type: [AlarmSchedule].self) ?? []
        return String(alarmSchedule.first?.bedTime.dropFirst(10) ?? "")
    }
}


extension View {
    func loadSunData() -> [SunData] {
        AppDataManager.loadFile(fileName: Constants.sunDataFileName, type: [SunData].self) ?? []
    }

    func loadAlarmSchedule() -> [AlarmSchedule] {
        AppDataManager.loadFile(fileName: Constants.alarmDataFileName, type: [AlarmSchedule].self) ?? []
    }
}


