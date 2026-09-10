import Foundation
import WatchConnectivity
import WidgetKit
import RiseCore

/// The watch's copy of the state. Settings arrive from the phone as application context and
/// are kept in the watch's App Group so the complication can read them; the plan is computed
/// here with the same RiseCore code the phone uses, so both agree to the second.
@Observable
final class WatchModel {

    private(set) var settings: AlarmSettings = SharedStore.shared.loadSettings() ?? AlarmSettings()
    private(set) var history: WakeHistory = SharedStore.shared.load(WakeHistory.self, from: AppGroup.wakeHistoryFile) ?? WakeHistory()
    private(set) var plan: [PlannedDay] = []
    private(set) var isReachable = false
    private(set) var pendingAction = false
    private(set) var lastError: String?

    private let link = WatchLink()

    init() {
        recompute()
        link.onContext = { [weak self] settings, history in
            Task { @MainActor in self?.apply(settingsData: settings, historyData: history) }
        }
        link.onReachability = { [weak self] reachable in
            Task { @MainActor in self?.isReachable = reachable }
        }
        link.activate()
    }

    var timeZone: TimeZone { settings.timeZone }
    var nextAlarm: PlannedDay? { AlarmPlanner.nextAlarm(in: plan, after: .now) }
    var today: PlannedDay? { plan.first { $0.date == DateKey(date: .now, calendar: settings.calendar) } }
    var hasSettings: Bool { settings.location != nil }

    // MARK: Actions (sent to the phone; the phone owns the alarms)

    func skipNext() {
        // Optimistic: reflect the skip immediately, the phone confirms with fresh context.
        guard let next = nextAlarm else { return }
        settings.skippedDays.insert(next.date)
        recompute()
        send(.skipNext)
    }

    func setEnabled(_ on: Bool) {
        settings.isEnabled = on
        recompute()
        send(.setEnabled, value: on)
    }

    private func send(_ action: WatchMessage.Action, value: Bool? = nil) {
        pendingAction = true
        link.send(action: action, value: value) { [weak self] error in
            Task { @MainActor in
                self?.pendingAction = false
                self?.lastError = error
            }
        }
    }

    // MARK: Internals

    private func apply(settingsData: Data?, historyData: Data?) {
        if let data = settingsData, let s = try? JSONDecoder().decode(AlarmSettings.self, from: data) {
            settings = s
            try? SharedStore.shared.save(s, to: AppGroup.settingsFile)
        }
        if let data = historyData, let h = try? JSONDecoder().decode(WakeHistory.self, from: data) {
            history = h
            try? SharedStore.shared.save(h, to: AppGroup.wakeHistoryFile)
        }
        recompute()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func recompute() {
        guard let loc = settings.location else { plan = []; return }
        let calendar = settings.calendar
        let start = calendar.date(byAdding: .day, value: -1, to: .now) ?? .now
        let days = SolarCalculator.solarDays(from: start, count: settings.horizonDays + 1,
                                             latitude: loc.latitude, longitude: loc.longitude, timeZone: settings.timeZone)
        plan = AlarmPlanner.plan(settings: settings, days: days, calendar: calendar)
        try? SharedStore.shared.save(plan, to: AppGroup.planFile)
    }
}

/// Thin WCSession wrapper; delegate callbacks arrive off the main actor.
nonisolated final class WatchLink: NSObject, WCSessionDelegate {
    /// Delivers the two payloads as `Data`, which is Sendable; the raw dictionary is not.
    var onContext: (@Sendable (_ settings: Data?, _ history: Data?) -> Void)?

    private func deliver(_ context: [String: Any]) {
        onContext?(context[WatchMessage.settingsKey] as? Data, context[WatchMessage.historyKey] as? Data)
    }
    var onReachability: (@Sendable (Bool) -> Void)?

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func send(action: WatchMessage.Action, value: Bool?, completion: @escaping @Sendable (String?) -> Void) {
        var message: [String: Any] = [WatchMessage.actionKey: action.rawValue]
        if let value { message[WatchMessage.valueKey] = value }
        let session = WCSession.default
        if session.isReachable {
            session.sendMessage(message, replyHandler: { _ in completion(nil) }) { error in
                // Fall back to the queued channel so the change still lands later.
                session.transferUserInfo(message)
                completion(error.localizedDescription)
            }
        } else {
            session.transferUserInfo(message)
            completion("iPhone not reachable. Sent; it will apply when connected.")
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        if state == .activated {
            let context = session.receivedApplicationContext
            if !context.isEmpty { deliver(context) }
            onReachability?(session.isReachable)
            if context.isEmpty, session.isReachable {
                session.sendMessage([WatchMessage.actionKey: WatchMessage.Action.requestSettings.rawValue], replyHandler: nil)
            }
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        onReachability?(session.isReachable)
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        deliver(applicationContext)
    }
}
