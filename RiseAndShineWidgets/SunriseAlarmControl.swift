import WidgetKit
import SwiftUI
import AppIntents

/// Control Center / Lock Screen toggle for the master switch.
struct SunriseAlarmControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "SunriseAlarmToggle", provider: Provider()) { isOn in
            ControlWidgetToggle("Sunrise Alarm", isOn: isOn, action: SunriseAlarmToggleIntent()) { on in
                Label(on ? "On" : "Off", systemImage: on ? "sunrise.fill" : "sunrise")
            }
            .tint(WidgetTheme.sunrise)
        }
        .displayName("Sunrise Alarm")
        .description("Turn the sunrise alarm on or off.")
    }

    nonisolated struct Provider: ControlValueProvider {
        var previewValue: Bool { true }
        func currentValue() async throws -> Bool {
            SharedStore.shared.loadSettings()?.isEnabled ?? false
        }
    }
}
