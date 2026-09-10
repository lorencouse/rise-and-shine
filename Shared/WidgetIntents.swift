import AppIntents
import WidgetKit

// Intents the widget button and the Control Center toggle fire. Both conform to
// `LiveActivityIntent`, which makes the system run `perform` in the *app's* process rather
// than the widget extension's. That matters because only the app can talk to AlarmKit; a
// skip that merely edited a JSON file would leave the real alarm ringing. The extension
// still has to compile these types to reference them, hence the `WIDGET_EXTENSION` guard.

struct SkipNextAlarmWidgetIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Skip Next Alarm"
    static let description = IntentDescription("Skips the next sunrise alarm.")
    static let isDiscoverable = false

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        await AppModel.shared.skipNext()
        #endif
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

struct SunriseAlarmToggleIntent: SetValueIntent, LiveActivityIntent {
    static let title: LocalizedStringResource = "Sunrise Alarm"
    static let description = IntentDescription("Turns the sunrise alarm on or off.")
    static let isDiscoverable = false

    @Parameter(title: "On")
    var value: Bool

    init() {}
    init(value: Bool) { self.value = value }

    @MainActor
    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        let model = AppModel.shared
        model.settings.isEnabled = value
        await model.flushSync()
        #endif
        WidgetCenter.shared.reloadAllTimelines()
        ControlCenter.shared.reloadAllControls()
        return .result()
    }
}
