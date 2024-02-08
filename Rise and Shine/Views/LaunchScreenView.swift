//
//  LaunchScreenView.swift
//  Rise and Shine
//
//  Created by loren on 2/8/24.
//

import Foundation
import SwiftUI

import SwiftUI

struct LaunchScreenView: View {
    var body: some View {
        
        ZStack {
            Color.appPrimary.edgesIgnoringSafeArea(.all)
            
            VStack {
                Text("Welcome to My App")
                    .font(.largeTitle)
                    .padding()
                Image("appLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 150, height: 150)
            }
            
        }
        

    }
}

