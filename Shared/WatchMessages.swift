import Foundation

/// The vocabulary phone and watch share over WatchConnectivity. Settings travel as the
/// same JSON the App Group stores; the watch computes everything else itself.
nonisolated enum WatchMessage {
    /// Application-context key carrying encoded `AlarmSettings`.
    static let settingsKey = "settings"
    /// Application-context key carrying encoded `WakeHistory` (phone → watch, display only).
    static let historyKey = "history"

    /// Message keys (watch → phone).
    static let actionKey = "action"
    enum Action: String, Sendable {
        case skipNext
        case setEnabled
        case requestSettings
    }
    static let valueKey = "value"
}
