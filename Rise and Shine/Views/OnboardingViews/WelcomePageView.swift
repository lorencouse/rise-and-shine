//
//  AlarmSetupView.swift
//  Rise and Shine
//
//  Created by loren on 2/5/24.
//

import Foundation
import SwiftUI

struct WelcomeView: View {
    
    var body: some View {
        NavigationView {
            
            ZStack {
                Color.appPrimary.edgesIgnoringSafeArea(.all)
                
                VStack {
                    
                    VStack {
                        Text("Rise and Shine").font(.largeTitle).padding(.top, 25.0)
                       

                    }
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    Image("AppLogoTransparent")
                    Spacer()
                    
                    // Picker and settings
                    VStack {

                        
                        Text("Sync your sleep with the sunrise, \nand align your body's natural clock.")
                            .multilineTextAlignment(.center)
                        
                    }
                    
                    
                    // Next button at the bottom
                    NavigationLink(destination: LocationSelectionView()) {
                        
                        HStack {
                            Spacer()
                            Text("Get Started")
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
        
    }
}



#Preview {
    WelcomeView()
}
    

