//
//  WindDownSetupView.swift
//  Rise and Shine
//
//  Created by loren on 2/5/24.
//

import Foundation
import SwiftUI

struct WindDownSetupView: View {
    
    @AppStorage("windDownTime") var windDownTime = Constants.windDownTimeDefault
    

    
    var body: some View {

        ZStack {
            Color.appPrimary.edgesIgnoringSafeArea(.all)
            VStack {
                
                HeaderView(title: "Bedtime Reminder", subtitle: "Choose how long before bedtime you want to be reminded to starting winding down for the night.", imageName: "moonset.fill")

                Spacer()
                
                // Picker and settings
                HStack {
                    Spacer()
                    Text("Remind me")
                    timePicker
                    Text("before bedtime.")
                    Spacer()
                    
                }.padding()
                
                NavigationButton(destination: SetupSettingsConfirmationView(), label: "Next")


            }
            .foregroundColor(.white)
        }
    }
    
    private var timePicker: some View {
        Picker("", selection: $windDownTime) {
            ForEach(0..<12, id: \.self) { index in
                Text("\(index * 5) mins").tag(index * 5)
            }
        }.pickerStyle(MenuPickerStyle())

    }
    
    
}



#Preview {
    WindDownSetupView()
}
    

