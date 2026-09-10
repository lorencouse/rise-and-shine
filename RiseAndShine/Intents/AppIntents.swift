import AppIntents
import RiseCore

// Siri and Shortcuts. These run inside the app process, so they can use AlarmKit through
// the shared model; each one flushes the debounced sync before returning so the change is
// on the device by the time Siri confirms it.

struct NextAlarmIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Next Sunrise Alarm"
    static let description = IntentDescription("Tells you when your next sunrise alarm rings.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<Date?> {
        let model = AppModel.shared
        guard let next = model.nextAlarm, let time = next.alarmTime else {
            let reason = model.settings.isEnabled ? "No alarm is scheduled in the next \(model.settings.horizonDays) days." : "Your sunrise alarm is off."
            return .result(value: nil, dialog: IntentDialog(stringLiteral: reason))
        }
        let zone = model.timeZone
        var text = "Your next alarm is \(Formatters.dayLabel(time, in: zone).lowercased()) at \(Formatters.time(time, in: zone))"
        if let sunrise = next.solar.sunrise {
            text += ", sunrise is at \(Formatters.time(sunrise, in: zone))."
        } else {
            text += "."
        }
        return .result(value: time, dialog: IntentDialog(stringLiteral: text))
    }
}

struct SkipNextAlarmIntent: AppIntent {
    static let title: LocalizedStringResource = "Skip Next Sunrise Alarm"
    static let description = IntentDescription("Skips the next morning's alarm. The one after still rings.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let model = AppModel.shared
        guard let next = model.nextAlarm else {
            return .result(dialog: "There's no upcoming alarm to skip.")
        }
        await model.skipNext()
        let zone = model.timeZone
        let skipped = Formatters.dayLabel(next.date.startOfDay(in: model.settings.calendar), in: zone)
        if let after = model.nextAlarm, let t = after.alarmTime {
            return .result(dialog: IntentDialog(stringLiteral: "Skipped \(skipped). Your next alarm is \(Formatters.dayLabel(t, in: zone).lowercased()) at \(Formatters.time(t, in: zone))."))
        }
        return .result(dialog: IntentDialog(stringLiteral: "Skipped \(skipped)."))
    }
}

struct SetSunriseAlarmIntent: AppIntent {
    static let title: LocalizedStringResource = "Turn Sunrise Alarm On or Off"
    static let description = IntentDescription("Turns the sunrise alarm on or off.")

    @Parameter(title: "On")
    var enabled: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Turn sunrise alarm \(\.$enabled)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let model = AppModel.shared
        model.settings.isEnabled = enabled
        await model.flushSync()
        if enabled, let t = model.nextAlarm?.alarmTime {
            return .result(dialog: IntentDialog(stringLiteral: "Sunrise alarm on. Next one \(Formatters.dayLabel(t, in: model.timeZone).lowercased()) at \(Formatters.time(t, in: model.timeZone))."))
        }
        return .result(dialog: enabled ? "Sunrise alarm on." : "Sunrise alarm off.")
    }
}

struct RiseAndShineShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: NextAlarmIntent(),
            phrases: [
                "When is my next alarm in \(.applicationName)",
                "What time is my \(.applicationName) alarm",
                "Next sunrise alarm in \(.applicationName)"
            ],
            shortTitle: "Next alarm",
            systemImageName: "sunrise.fill"
        )
        AppShortcut(
            intent: SkipNextAlarmIntent(),
            phrases: [
                "Skip my next alarm in \(.applicationName)",
                "Skip tomorrow's alarm in \(.applicationName)"
            ],
            shortTitle: "Skip next alarm",
            systemImageName: "forward.end"
        )
        AppShortcut(
            intent: SetSunriseAlarmIntent(),
            phrases: [
                "Turn my \(.applicationName) alarm on",
                "Turn my \(.applicationName) alarm off"
            ],
            shortTitle: "Alarm on or off",
            systemImageName: "alarm"
        )
    }
}
