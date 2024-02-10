//
//  VideoComponents.swift
//  Rise and Shine
//
//  Created by loren on 2/10/24.
//

import Foundation
import AVKit
import SwiftUI

struct LoopingVideoView: View {
    
    private let player = AVPlayer(url: Bundle.main.url(forResource: "notification-h264", withExtension: "mp4")!)

    
    var body: some View {

            
            VideoPlayer(player: player)
                .frame(height: 400)
                .onAppear {
                    // Start playing the video as soon as the view appears
                    player.play()
                    
                    // Loop the video
                    NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main) { _ in
                        player.seek(to: .zero)
                        player.play()
                    }
                }
            
        
        

        
    }
    
}
