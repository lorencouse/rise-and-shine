//
//  OnboardingView.swift
//  Rise and Shine
//
//  Created by loren on 2/5/24.
//

import Foundation
import SwiftUI
import MapKit


class UserSettings: ObservableObject {
    @Published var currentCity: String = ""
    @Published var wakeUpOffsetHours: Int = 0
    @Published var wakeUpOffsetMinutes: Int = 0
    @Published var beforeSunrise: Bool = true
    @Published var targetHoursOfSleep: Int = 8
    @Published var windDownTime: Int = 30
}



struct OnboardingView: View {
    @ObservedObject var userSettings = UserSettings()

    var body: some View {
        NavigationView {
            Form {
                LocationSection(userSettings: userSettings)
                AlarmTimeSection(userSettings: userSettings)
//                SleepGoalSection()
//                WindDownReminderSection()
                
                
            }
            .navigationTitle("Setup")
        }
    }
    
}



class LocationSearchCompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var suggestions: [MKLocalSearchCompletion] = []
    private var completer: MKLocalSearchCompleter?

    override init() {
        super.init()
        completer = MKLocalSearchCompleter()
        completer?.delegate = self
        completer?.resultTypes = .address // Focus on addresses
    }
    
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async {
            self.suggestions = completer.results
        }
    }
    
    func updateSearchQuery(query: String) {
        completer?.queryFragment = query
    }
}

struct LocationSection: View {
    @ObservedObject var userSettings: UserSettings
    @ObservedObject private var searchCompleter = LocationSearchCompleter()
    
    var body: some View {
        Section(header: Text("Location:")) {
            TextField("Current City", text: $userSettings.currentCity)
                .onChange(of: userSettings.currentCity) { newValue in
                    searchCompleter.updateSearchQuery(query: newValue)
                }
            
            ForEach(searchCompleter.suggestions, id: \.self) { suggestion in
                Text(suggestion.title).onTapGesture {
                    userSettings.currentCity = suggestion.title
                }
            }
        }
    }
}


struct AlarmTimeSection: View {
    @ObservedObject var userSettings: UserSettings

    var body: some View {
        Section(header: Text("Alarm time:")) {
            HStack {
                Text("Wake up ")
                Picker("", selection: $userSettings.wakeUpOffsetHours) {
                    ForEach(0..<4, id: \.self) { i in
                        Text("\(i) hours").tag(i)
                    }
                }.pickerStyle(MenuPickerStyle())
                
                Picker("", selection: $userSettings.wakeUpOffsetMinutes) {
                    ForEach(0..<60, id: \.self) { i in
                        Text("\(i) mins").tag(i)
                    }
                }.pickerStyle(MenuPickerStyle())
            }
            Picker("Direction", selection: $userSettings.beforeSunrise) {
                Text("Before Sunrise").tag(true)
                Text("After Sunrise").tag(false)
            }.pickerStyle(SegmentedPickerStyle())
        }
    }
}


