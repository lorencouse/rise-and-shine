//
//  SettingsComponents.swift
//  Rise and Shine
//
//  Created by loren on 2/6/24.
//

import Foundation
import SwiftUI
import AVKit


struct AlarmTimeSelector: View {
    @Binding var wakeUpOffsetHours: Int
    @Binding var wakeUpOffsetMinutes: Int
    @Binding var beforeSunrise: Bool
    
    var body: some View {
        Section(header: Text("\(Image(systemName: "alarm")) Alarm time")) {
            HStack {
                Text("Wake up ")
                
                Picker("", selection: $wakeUpOffsetHours) {
                    ForEach(0..<4, id: \.self) { i in
                        Text("\(i) hours").tag(i)
                    }
                }.pickerStyle(MenuPickerStyle())
                
                Picker("", selection: $wakeUpOffsetMinutes) {
                    ForEach(0..<60, id: \.self) { i in
                        Text("\(i) mins").tag(i)
                    }
                }.pickerStyle(MenuPickerStyle())
            }
            Picker("", selection: $beforeSunrise) {
                Text("Before Sunrise").tag(true)
                Text("After Sunrise").tag(false)
            }.pickerStyle(SegmentedPickerStyle())
        }
        .listRowBackground(Color.appThird)
    }
}


struct SoundSelector: View {
    
    @State private var selectedSong: String = ""
    private var sounds: [String] = loadMP3Filenames().sorted(by: <)
    @State private var audioPlayer: AVAudioPlayer?
    @State private var soundPlaying: Bool = false
    
    var body: some View {
        
        
        HStack {
            
            
            Picker("", selection: $selectedSong) {
                ForEach(sounds, id: \.self) {
                    sound in Text(sound).tag(sound)
                }
            }
            .onChange(of: selectedSong) {
                audioPlayer?.stop()
                playSound(soundName: selectedSong)
            }
            
            Spacer()
            
            Button(action: {
                soundPlaying.toggle()
                if soundPlaying {
                    playSound(soundName: selectedSong)
                } else {
                    audioPlayer?.stop()
                }
            }) {
                Image(systemName: soundPlaying ? "pause.circle" : "play.circle")
            }
            .background(Color.appThird)
            .foregroundColor(.white)
            
        }
        .listRowBackground(Color.appThird)
        .pickerStyle(MenuPickerStyle())
        
    }
    
    private func playSound(soundName: String) {
        guard let path = Bundle.main.path(forResource: soundName, ofType: "mp3", inDirectory: "AlarmSounds") else {
            print("Sound file not found")
            return
        }
        
        let url = URL(fileURLWithPath: path) // Directly create the URL

        do {
            // Assuming `audioPlayer` is a previously defined variable in your class
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.numberOfLoops = -1 // Loop indefinitely
            audioPlayer?.play()
            soundPlaying = true
        } catch {
            print("Could not load file: \(error.localizedDescription)")
        }
    }

}



struct LocationSelector: View {
    
    @Binding var sunData: [SunData]
    @ObservedObject var locationManager: LocationManager
    @State private var showingAlert = false
    @State private var sunriseTime: String = "Tap to Update Sunrise Time"
    @State private var cityName: String = UserDefaults.standard.currentCity
    let dateString = DateFormatter.fetchDateString()
    
    var body: some View {
        
        Section(header: Text("\(Image(systemName: "location.fill")) Location")) {
            
            Button("\(Image(systemName: "location.circle")) \(cityName)") {
                
                updateLocationAndSunrise()
                
            }
            
            .alert("Location Error", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Please ensure the app has permission to access your location and try again.")
            }
            
            Button("\(Image(systemName: "sun.haze.circle")) Sunrise Today: \(sunriseTime.dropSecondsFromTime())") {
                updateLocationAndSunrise()
            }
            
        }
        .onChange(of: locationManager.locationStatus) {
            if $0 == .denied || $0 == .restricted {
                showingAlert = true
            }
        }
        .onAppear {
            updateLocationAndSunrise()
            
        }
        .listRowBackground(Color.appThird)
        
    }
    
    private func updateLocationAndSunrise() {
        Task {
            locationManager.requestSingleLocationUpdate()
            await updateSunData(date: dateString, locationManager: locationManager)
            sunData = AppDataManager.loadFile(fileName: Constants.sunDataFileName, type: [SunData].self) ?? []
            if let sunrise = sunData.first?.sunrise {
                sunriseTime = "\(sunrise)"
            } else {
            }
        }
    }
    
}


struct TargetHoursOfSleepSelector: View {
    @Binding var targetHoursOfSleep: Int
    
    var body: some View {
        Section(header: Text("\(Image(systemName: "moon.zzz.fill")) Target Hours of Sleep")) {
            Picker("Sleep Goal: ", selection: $targetHoursOfSleep) {
                ForEach(4..<14, id: \.self) { i in
                    Text("\(i) hours").tag(i)
                }
            }.pickerStyle(MenuPickerStyle())
                .listRowBackground(Color.appThird)
        }
    }
}

struct WindDownTimeSelector: View {
    @Binding var windDownTime: Int
    
    var body: some View {
        Section(header: Text("\(Image(systemName: "moonset.fill")) Wind down reminder")) {
            HStack {
                Picker("Notify me ", selection: $windDownTime) {
                    ForEach(5..<60, id: \.self) { i in
                        Text("\(i) mins").tag(i)
                    }
                }.pickerStyle(MenuPickerStyle())
                Text(" before bedtime.")
            }
            .listRowBackground(Color.appThird)
            
        }
    }
}


struct DNDExceptionEducationView: View {
    
    private let player = AVPlayer(url: Bundle.main.url(forResource: "notification-h264", withExtension: "mp4")!)
    
    var body: some View {
        VStack() {
            Text("Enable Alarm Notifications")
                .font(.title)
            
            LoopingVideoView()
            
            Text("To receive alarm notifications, please add this app to your \"Focus Mode\" exceptions:\n\n1. Open Settings app. \n2. Tap \"Focus\". \n3. Modify the \"Do Not Disturb\" and \"Sleep\" Focus. \n4. Tap \"Apps\". \n5. Search for \"Rise and Shine\". \n6. Tap \"Allow Notifications\".")
            
                .multilineTextAlignment(.leading)
            
            FocusModesButton()
        }
        
    }
    
}

