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
//        NavigationView {
            VStack {
                // Your content here
                VStack {
                    Text("Set Wind Down Reminder").font(.title).padding(.vertical)
                    Text("Choose how long before bedtime you want to be reminded to starting winding down for the night.")
                }
                .padding(.horizontal)
                
                Spacer() // Pushes everything above to the top and everything below to the bottom
                
                // Picker and settings
                HStack {
                    Text("Remind me")
                    timePicker
                    Text("before bedtime.")
                    Spacer()


                    
                }.padding()
                
                // Next button at the bottom
                NavigationLink(destination: SetupSettingsConfirmationView()) {
                    Text("Next")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding(.bottom) // Adds padding at the bottom if needed
            }
//        }
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
    

