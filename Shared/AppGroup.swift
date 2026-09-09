import Foundation

/// Identifiers shared between the app and the widget extension.
/// Change `bundleIdentifier` in one place: project.yml.
nonisolated enum AppGroup {
    /// The App Group container both targets can read. Must match the entitlements.
    static let identifier = "group.com.lomaco.riseandshine"

    static let settingsFile = "settings.json"
    static let planFile = "plan.json"
    static let alarmRegistryFile = "alarm-registry.json"

    static let backgroundRefreshTask = "com.lomaco.riseandshine.refresh"
    static let deepLinkScheme = "riseandshine"

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }

    static func url(for file: String) -> URL? {
        containerURL?.appendingPathComponent(file)
    }
}
