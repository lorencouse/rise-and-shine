import Foundation
import RiseCore

/// Mirrors the settings JSON into iCloud's key-value store so a new phone, or a second one,
/// starts with the same alarm instead of onboarding. Last write wins on a timestamp; the
/// data is a few hundred bytes and changes rarely, which is what this store is for.
/// Device-following locations are carried over as-is and corrected by the next fix.
@MainActor
final class CloudSettings {
    private let kv = NSUbiquitousKeyValueStore.default
    private static let dataKey = "settings.v1"
    private static let stampKey = "settings.v1.updated"
    private var observer: NSObjectProtocol?

    /// Called with the remote settings whenever another device wrote newer ones.
    var onRemoteChange: ((AlarmSettings) -> Void)?

    init() {
        observer = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: kv, queue: .main
        ) { [weak self] note in
            let reason = (note.userInfo?[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int) ?? -1
            guard reason != NSUbiquitousKeyValueStoreQuotaViolationChange else { return }
            MainActor.assumeIsolated {
                guard let self else { return }
                if let remote = self.remote(), remote.stamp > self.localStamp {
                    self.localStamp = remote.stamp
                    self.onRemoteChange?(remote.settings)
                }
            }
        }
        kv.synchronize()
    }

    /// The local copy's timestamp, so an echo of our own write is not applied as remote.
    private var localStamp: Double {
        get { UserDefaults.standard.double(forKey: "cloudSettingsStamp") }
        set { UserDefaults.standard.set(newValue, forKey: "cloudSettingsStamp") }
    }

    func push(_ settings: AlarmSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        let stamp = Date().timeIntervalSince1970
        localStamp = stamp
        kv.set(data, forKey: Self.dataKey)
        kv.set(stamp, forKey: Self.stampKey)
    }

    /// Settings from iCloud that are newer than anything written here. Used at launch when
    /// there is no local file yet.
    func remote() -> (settings: AlarmSettings, stamp: Double)? {
        guard let data = kv.data(forKey: Self.dataKey),
              let settings = try? JSONDecoder().decode(AlarmSettings.self, from: data) else { return nil }
        return (settings, kv.double(forKey: Self.stampKey))
    }
}
