import Foundation

/// Identifiers shared between the app and the widget extension.
/// Change `bundleIdentifier` in one place: project.yml.
nonisolated enum AppGroup {
    /// The App Group container both targets can read. Must match the entitlements.
    static let identifier = "group.com.lomaco.riseandshine.shared"

    static let settingsFile = "settings.json"
    static let planFile = "plan.json"
    static let alarmRegistryFile = "alarm-registry.json"
    static let testAlarmFile = "test-alarm.json"
    static let wakeHistoryFile = "wake-history.json"
    static let calendarRegistryFile = "calendar-registry.json"

    static let backgroundRefreshTask = "com.lomaco.riseandshine.refresh"
    static let deepLinkScheme = "riseandshine"

    /// Destinations the widget (and, later, Shortcuts) can open the app at.
    enum DeepLink: String, CaseIterable {
        case home, wakeTime, days, sleep
        /// Skips the next alarm on open. The widget's Skip button uses this rather than
        /// firing an intent: the intent source is compiled into both the app and the
        /// widget extension, and the extension runs its own copy, where the AlarmKit
        /// path is compiled out. Opening the app is the cost of actually cancelling.
        case skipNext

        var url: URL { URL(string: "\(AppGroup.deepLinkScheme)://\(rawValue)")! }

        init?(url: URL) {
            guard url.scheme == AppGroup.deepLinkScheme, let host = url.host() else { return nil }
            self.init(rawValue: host)
        }
    }

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }

    static func url(for file: String) -> URL? {
        containerURL?.appendingPathComponent(file)
    }
}
