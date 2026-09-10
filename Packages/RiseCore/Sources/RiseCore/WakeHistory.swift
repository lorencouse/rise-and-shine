import Foundation

/// What happened on one morning the alarm was scheduled for. Built up from AlarmKit state
/// transitions: scheduled → alerting (rang), alerting → countdown (snoozed), gone (stopped).
public struct WakeRecord: Sendable, Codable, Equatable, Identifiable {
    public var id: DateKey { date }
    public let date: DateKey
    public var scheduled: Date
    public var rang: Date?
    public var stopped: Date?
    public var snoozes: Int
    /// Minutes asleep the night before, from Health. `nil` when unknown or not enabled.
    public var sleepMinutes: Int?

    public init(date: DateKey, scheduled: Date, rang: Date? = nil, stopped: Date? = nil, snoozes: Int = 0, sleepMinutes: Int? = nil) {
        self.date = date
        self.scheduled = scheduled
        self.rang = rang
        self.stopped = stopped
        self.snoozes = snoozes
        self.sleepMinutes = sleepMinutes
    }

    /// How long after the alarm first rang the user finally stopped it.
    public var lingered: TimeInterval? {
        guard let rang, let stopped else { return nil }
        return max(0, stopped.timeIntervalSince(rang))
    }

    /// A morning counts as "up with the alarm" when it was stopped without snoozing.
    public var wokeCleanly: Bool { stopped != nil && snoozes == 0 }
}

/// The last couple of months of mornings plus the figures Home shows.
public struct WakeHistory: Sendable, Codable, Equatable {
    public var records: [WakeRecord] = []
    public static let retentionDays = 60

    public init(records: [WakeRecord] = []) { self.records = records }

    public subscript(day: DateKey) -> WakeRecord? {
        get { records.first { $0.date == day } }
        set {
            records.removeAll { $0.date == day }
            if let newValue { records.append(newValue) }
            records.sort { $0.date < $1.date }
        }
    }

    /// Mornings with a stop recorded, newest first.
    public var completed: [WakeRecord] {
        records.filter { $0.stopped != nil }.sorted { $0.date > $1.date }
    }

    /// Consecutive most-recent mornings stopped without a snooze.
    public var cleanStreak: Int {
        var n = 0
        for r in completed {
            guard r.wokeCleanly else { break }
            n += 1
        }
        return n
    }

    public var averageSnoozes: Double? {
        let c = completed
        guard !c.isEmpty else { return nil }
        return Double(c.reduce(0) { $0 + $1.snoozes }) / Double(c.count)
    }

    /// Mean minutes asleep over mornings that have a Health figure.
    public var averageSleepMinutes: Int? {
        let values = completed.compactMap(\.sleepMinutes)
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / values.count
    }

    /// Mean time from first ring to stop, over completed mornings that rang.
    public var averageLinger: TimeInterval? {
        let values = completed.compactMap(\.lingered)
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    public mutating func prune(before cutoff: DateKey) {
        records.removeAll { $0.date < cutoff }
    }
}
