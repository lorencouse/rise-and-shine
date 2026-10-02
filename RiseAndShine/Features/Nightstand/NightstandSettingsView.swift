import SwiftUI
import RiseCore

struct NightstandSettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var showDemo = false

    /// Off, then lengths that fit inside a normal wind-down. Beyond about an hour the
    /// ramp is too slow to perceive and the phone is just a lamp.
    private let glowChoices = [0, 10, 20, 30, 45, 60]

    var body: some View {
        @Bindable var model = model
        Form {
            Section {
                Picker("Sunrise light", selection: $model.settings.sunriseGlowMinutes) {
                    ForEach(glowChoices, id: \.self) { minutes in
                        Text(minutes == 0 ? "Off" : Formatters.duration(minutes: minutes)).tag(minutes)
                    }
                }
                .accessibilityIdentifier("nightstand.glowPicker")
                if model.settings.sunriseGlowMinutes > 0 {
                    brightnessSlider(value: $model.settings.sunriseGlowMaxBrightness,
                                     title: "Brightness at the alarm")
                    Button("Preview the sunrise") { showDemo = true }
                }
            } header: {
                Text("Sunrise light")
            } footer: {
                Text(glowFooter)
            }

            Section {
                Toggle("Start when charging", isOn: $model.settings.nightstandAutoEnabled)
                brightnessSlider(value: $model.settings.nightstandBrightness, title: "Clock brightness")
            } header: {
                Text("Nightstand")
            } footer: {
                Text("Nightstand keeps the screen on with a dim clock and your next alarm. Your usual brightness comes back when you leave it.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.night)
        .navigationTitle("Nightstand")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showDemo) {
            NightstandView(demo: true).environment(model)
        }
    }

    private var glowFooter: String {
        guard model.settings.sunriseGlowMinutes > 0 else {
            return "The screen can brighten gradually before the alarm, so you wake into light instead of noise. It only runs while the phone is showing nightstand mode."
        }
        let length = Formatters.duration(minutes: model.settings.sunriseGlowMinutes)
        return "The screen starts almost black \(length) before the alarm and reaches full brightness as it rings, then holds for \(Formatters.duration(minutes: SunriseGlow.holdMinutes)) while you get up. It needs the phone left in nightstand mode, plugged in."
    }

    private func brightnessSlider(value: Binding<Double>, title: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(value.wrappedValue.formatted(.percent.precision(.fractionLength(0))))
                    .foregroundStyle(.secondary)
            }
            .font(.footnote)
            // The slider below already speaks its title and percentage.
            .accessibilityHidden(true)
            Slider(value: value, in: 0.05...1) {
                Text(title)
            } minimumValueLabel: {
                Image(systemName: "sun.min").font(.caption2).accessibilityHidden(true)
            } maximumValueLabel: {
                Image(systemName: "sun.max").font(.caption2).accessibilityHidden(true)
            }
        }
    }
}
