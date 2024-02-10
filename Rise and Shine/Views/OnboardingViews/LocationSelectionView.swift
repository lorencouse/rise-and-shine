//
//  AlarmSetupView.swift
//  Rise and Shine
//
//  Created by loren on 2/5/24.
//

import Foundation
import SwiftUI



struct LocationSelectionView: View {
    
    @State private var sunData: [SunData] =  AppDataManager.loadFile(fileName: Constants.sunDataFileName, type: [SunData].self) ?? []
    @ObservedObject private var locationManager = LocationManager()
    @State private var sunriseTime: String = ""
    @State private var currentCity = UserDefaults.standard.currentCity
    
    var body: some View {

            
            ZStack {
                Color.appPrimary.edgesIgnoringSafeArea(/*@START_MENU_TOKEN@*/.all/*@END_MENU_TOKEN@*/)
          
            VStack {
                
                HeaderView(title: "Current Location", subtitle: "Below is the sunrise time for your current location.", imageName: "location.fill")
                
                Spacer()
                

                    Form {
                        
                        LocationSelector( sunData: $sunData, locationManager: locationManager)
                        
                            
                    }
                    .scrollContentBackground(.hidden)

                
                NavigationButton(destination: AlarmSetupView(), label: "Next")

                
            }
            .foregroundColor(.white)
                
                
            }
            
        
    }
}



#Preview {
    LocationSelectionView()
}
    

