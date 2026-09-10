import Foundation
import WatchConnectivity
import RiseCore

/// Phone side of the watch link. Pushes settings (and history) as application context —
/// the "latest state wins" channel, which is exactly the semantics settings want — and
/// answers the watch's few actions by driving the shared model.
/// `@unchecked Sendable` is safe here: the class holds no mutable state of its own, only a
/// computed reference to the singleton `WCSession`.
nonisolated final class WatchBridge: NSObject, WCSessionDelegate, @unchecked Sendable {

    static let shared = WatchBridge()

    private var session: WCSession? { WCSession.isSupported() ? WCSession.default : nil }

    func activate() {
        guard let session else { return }
        session.delegate = self
        session.activate()
    }

    /// Mirror the current state to the watch. Cheap and idempotent; call after every save.
    func push(settings: AlarmSettings, history: WakeHistory) {
        // `isPaired` keeps this quiet on a phone with no watch, where the call would
        // otherwise fail with WCErrorCodeDeviceNotPaired on every settings save.
        guard let session, session.activationState == .activated, session.isPaired else { return }
        var context: [String: Any] = [:]
        if let data = try? JSONEncoder().encode(settings) { context[WatchMessage.settingsKey] = data }
        if let data = try? JSONEncoder().encode(history) { context[WatchMessage.historyKey] = data }
        try? session.updateApplicationContext(context)
    }

    // MARK: WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        guard state == .activated else { return }
        Task { @MainActor in
            let model = AppModel.shared
            self.push(settings: model.settings, history: model.alarms.history)
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        // Acknowledge receipt straight away. The work itself hops to the main actor, and the
        // watch learns the outcome from the application context that follows, so there is
        // nothing to wait for here — and the reply handler is not Sendable.
        replyHandler(["ok": true])
        handle(message)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handle(message)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        handle(userInfo)
    }

    /// Only the Sendable pieces of the message cross into the task; `[String: Any]` cannot.
    private func handle(_ message: [String: Any]) {
        guard let raw = message[WatchMessage.actionKey] as? String,
              let action = WatchMessage.Action(rawValue: raw) else { return }
        let value = message[WatchMessage.valueKey] as? Bool
        Task { @MainActor in
            let model = AppModel.shared
            switch action {
            case .skipNext:
                await model.skipNext()
            case .setEnabled:
                if let value { model.settings.isEnabled = value; await model.flushSync() }
            case .requestSettings:
                break
            }
            self.push(settings: model.settings, history: model.alarms.history)
        }
    }
}
