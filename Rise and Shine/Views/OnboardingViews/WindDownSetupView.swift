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

                VStack {
                    Text("Set Wind Down Reminder").font(.title).padding(.vertical)
                    Text("Choose how long before bedtime you want to be reminded to starting winding down for the night.")
                }
                .padding(.horizontal)
                
                Spacer()
                Image("alarm-clock")
                Spacer()
                
                // Picker and settings
                HStack {
                    Text("Remind me")
                    timePicker
                    Text("before bedtime.")
                    Spacer()


                    
                }.padding()
                
                // Next button at the bottom
                NavigationLink(destination: SetupSettingsConfirmationView()) {
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
    

