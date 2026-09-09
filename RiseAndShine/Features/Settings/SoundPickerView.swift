import SwiftUI
import AVFoundation
import RiseCore

struct SoundPickerView: View {
    @Environment(AppModel.self) private var model
    @State private var player: AVAudioPlayer?
    @State private var playing: String?

    var body: some View {
        @Bindable var model = model
        List {
            Section {
                ForEach(model.availableSounds, id: \.self) { file in
                    Button {
                        model.settings.soundFile = file
                        preview(file)
                    } label: {
                        HStack {
                            Image(systemName: playing == file ? "speaker.wave.3.fill" : "speaker.wave.2")
                                .foregroundStyle(playing == file ? Theme.sun : .secondary)
                                .frame(width: 24)
                            Text((file as NSString).deletingPathExtension)
                                .foregroundStyle(.primary)
                            Spacer()
                            if model.settings.soundFile == file {
                                Image(systemName: "checkmark").foregroundStyle(Theme.sunrise)
                            }
                        }
                    }
                }
            } footer: {
                Text("Tap to preview. The alarm plays through Silent mode at the alarm volume set in Settings › Sounds & Haptics.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.night)
        .navigationTitle("Alarm sound")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { player?.stop() }
    }

    private func preview(_ file: String) {
        player?.stop()
        guard let url = Bundle.main.url(forResource: (file as NSString).deletingPathExtension,
                                        withExtension: (file as NSString).pathExtension) else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            player = try AVAudioPlayer(contentsOf: url)
            player?.play()
            playing = file
        } catch {
            playing = nil
        }
    }
}
