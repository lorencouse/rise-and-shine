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
                    
                    HeaderView(title: "Rise and Shine", subtitle: "Sync your sleep with the sunrise, \nand align your body's natural clock.", imageName: "sun.dust.circle")
                    
                    NavigationButton(destination: LocationSelectionView(), label: "Get Started")

                    
                }
                .foregroundColor(.white)
                
                
            }
            
        }
        
    }
}



#Preview {
    WelcomeView()
}
    

