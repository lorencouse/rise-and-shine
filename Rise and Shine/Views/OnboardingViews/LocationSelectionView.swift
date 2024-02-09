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

                VStack {
                    Text("Current Location").font(.title).padding(.vertical)
                    Text("Choose when you would like to be woken up each day in relation to the sunrise.")
                }
                .padding(.horizontal)
                
                Spacer()
                
                Image(systemName: "location.fill")
                    .symbolEffect(.pulse)
                    .font(.system(size: 240))
                    .shadow(radius: /*@START_MENU_TOKEN@*/10/*@END_MENU_TOKEN@*/)
                
                Spacer()
                

                    Form {
                        
                        settingsComponents.LocationSelector( sunData: $sunData, locationManager: locationManager)
                        
                            
                    }
                    .scrollContentBackground(.hidden)



                
                
                // Next button at the bottom
                NavigationLink(destination: AlarmSetupView()) {
                    
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
}



#Preview {
    LocationSelectionView()
}
    

