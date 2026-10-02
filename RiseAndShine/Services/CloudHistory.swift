import Foundation
import RiseCore

/// Mirrors wake history into iCloud's key-value store, so the record of how you have
/// actually been waking survives a new phone. Settings sync the same way in
/// `CloudSettings`; this is a separate key because the merge rule is different.
///
/// History is **merged**, not last-write-wins. Two copies of the same morning are
/// usually both partial — one device saw the ring, another the Health figure — so the
/// blob with the newer timestamp is not the better one. `WakeHistory.merged(with:)` in
/// RiseCore does the field-by-field union and carries the tests.
///
/// Sixty days of records is a few kilobytes, well inside the store's per-key megabyte.
@MainActor
final class CloudHistory {
    private let kv = NSUbiquitousKeyValueStore.default
    private static let dataKey = "history.v1"
    private static let stampKey = "history.v1.updated"
    /// When history was last cleared *anywhere*. A clear has to beat the merge, or the
    /// other device's copy would simply hand the records straight back.
    private static let clearedKey = "history.v1.cleared"

    /// Called with history this device should adopt: either the merge of ours and a
    /// remote copy, or an empty history when another device cleared it.
    var onRemoteChange: ((WakeHistory) -> Void)?

    /// Reading local history, so a remote change can be merged against what is here now
    /// rather than against a copy captured at init.
    private let local: () -> WakeHistory

    private var observer: NSObjectProtocol?

    init(local: @escaping () -> WakeHistory) {
        self.local = local
        observer = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: kv, queue: .main
        ) { [weak self] note in
            let reason = (note.userInfo?[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int) ?? -1
            guard reason != NSUbiquitousKeyValueStoreQuotaViolationChange else { return }
            let keys = (note.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String]) ?? []
            guard keys.contains(Self.dataKey) || keys.contains(Self.clearedKey) else { return }
            MainActor.assumeIsolated { self?.reconcile() }
        }
    }

    /// Timestamp of this device's own last write, so an echo of it is not treated as
    /// news and a stale remote clear cannot wipe records made since.
    private var localStamp: Double {
        get { UserDefaults.standard.double(forKey: "cloudHistoryStamp") }
        set { UserDefaults.standard.set(newValue, forKey: "cloudHistoryStamp") }
    }

    /// Take whatever iCloud holds and fold it into what is here. Safe to call at launch
    /// and on every external change.
    func reconcile() {
        let clearedAt = kv.double(forKey: Self.clearedKey)
        if clearedAt > localStamp {
            localStamp = clearedAt
            onRemoteChange?(WakeHistory())
            return
        }
        guard let remote = remote() else { return }
        let merged = local().merged(with: remote)
        guard merged != local() else { return }
        onRemoteChange?(merged)
        push(merged)
    }

    func push(_ history: WakeHistory) {
        guard let data = try? JSONEncoder().encode(history) else { return }
        let stamp = Date().timeIntervalSince1970
        localStamp = stamp
        kv.set(data, forKey: Self.dataKey)
        kv.set(stamp, forKey: Self.stampKey)
    }

    /// Clearing history is a deliberate act, so it propagates rather than being merged
    /// away by the next device that syncs.
    func pushCleared() {
        let stamp = Date().timeIntervalSince1970
        localStamp = stamp
        kv.set(Data(), forKey: Self.dataKey)
        kv.set(stamp, forKey: Self.stampKey)
        kv.set(stamp, forKey: Self.clearedKey)
    }

    private func remote() -> WakeHistory? {
        guard let data = kv.data(forKey: Self.dataKey), !data.isEmpty else { return nil }
        return try? JSONDecoder().decode(WakeHistory.self, from: data)
    }
}
