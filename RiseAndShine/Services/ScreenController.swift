import SwiftUI
import UIKit

/// Owns the three bits of device state nightstand mode needs and the rest of the app
/// must not be left holding: screen brightness, the idle timer, and rotation.
///
/// Brightness is a global the system does not restore for us — leaving the phone at 2%
/// after a nightstand session would look like a broken screen — so every entry saves the
/// user's own level and every exit puts it back, including on backgrounding.
@MainActor
@Observable
final class ScreenController {
    static let shared = ScreenController()

    /// Whether the phone is on power. Nightstand can offer itself when it is.
    private(set) var isCharging = false

    private var savedBrightness: CGFloat?
    private var observers: [NSObjectProtocol] = []

    private init() {}

    /// Start watching the battery. Cheap, but it needs an explicit opt-in from UIKit.
    func startMonitoringCharge() {
        guard observers.isEmpty else { return }
        UIDevice.current.isBatteryMonitoringEnabled = true
        isCharging = Self.charging(UIDevice.current.batteryState)
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: UIDevice.batteryStateDidChangeNotification,
                                            object: nil, queue: .main) { [weak self] _ in
            let state = UIDevice.current.batteryState
            MainActor.assumeIsolated { self?.isCharging = Self.charging(state) }
        })
    }

    private static func charging(_ state: UIDevice.BatteryState) -> Bool {
        state == .charging || state == .full
    }

    // MARK: Nightstand session

    func beginNightstand(brightness: Double) {
        if savedBrightness == nil { savedBrightness = screen?.brightness }
        UIApplication.shared.isIdleTimerDisabled = true
        OrientationLock.set(.allButUpsideDown)
        setBrightness(brightness)
    }

    func endNightstand() {
        UIApplication.shared.isIdleTimerDisabled = false
        OrientationLock.set(.portrait)
        if let savedBrightness {
            screen?.brightness = savedBrightness
            self.savedBrightness = nil
        }
    }

    /// Set the backlight, clamped away from fully off so the screen never looks dead.
    func setBrightness(_ value: Double) {
        screen?.brightness = CGFloat(min(max(value, 0.01), 1))
    }

    /// The screen the app is actually on. `UIScreen.main` is the deprecated way to ask.
    private var screen: UIScreen? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.screen
    }
}

/// The app is portrait everywhere except nightstand mode, which is the one screen you
/// look at with the phone on its side. Info.plist has to allow landscape for that to be
/// possible at all, so the restriction lives here instead.
@MainActor
enum OrientationLock {
    private(set) static var mask: UIInterfaceOrientationMask = .portrait

    static func set(_ new: UIInterfaceOrientationMask) {
        guard new != mask else { return }
        mask = new
        for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: new))
            scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
    }
}

/// Only reason for an app delegate: UIKit asks *it* which orientations are allowed, and
/// there is no SwiftUI equivalent.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        OrientationLock.mask
    }
}
