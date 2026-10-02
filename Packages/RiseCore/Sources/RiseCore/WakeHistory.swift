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

// MARK: - Recording observed alarm transitions

/// The states a scheduled alarm can be observed in. Mirrors AlarmKit's `Alarm.State` so
/// this logic can live here — and be tested — without RiseCore depending on AlarmKit.
/// `absent` covers both "not scheduled yet" and "gone", which is what the system reports
/// once an alarm is stopped.
public enum AlarmPhase: String, Sendable, Codable, Equatable {
    case absent, scheduled, countdown, alerting, paused
}

extension WakeHistory {
    /// Folds one observed state transition into the history, returning whether anything
    /// changed. Only transitions carry information: an alarm that stays `scheduled` says
    /// nothing yet.
    ///
    /// - Parameters:
    ///   - rangAt: when the alarm alerted, derived from its schedule rather than from the
    ///     clock. Updates are only delivered while the app runs, so a ring is usually first
    ///     seen at the next launch and "now" would record the launch time.
    ///   - now: the moment the transition was observed. Correct for `stopped`, because the
    ///     alarm's removal is a diff between two in-process snapshots.
    public mutating func record(from before: AlarmPhase, to after: AlarmPhase,
                                day: DateKey, scheduled: Date, rangAt: Date, now: Date) -> Bool {
        switch (before, after) {
        case (.scheduled, .alerting), (.countdown, .alerting), (.absent, .alerting):
            // Rang, or rang again after a snooze. Only the first ring is "rang".
            var r = self[day] ?? WakeRecord(date: day, scheduled: scheduled)
            guard r.rang == nil else { return false }
            r.rang = rangAt
            self[day] = r
            return true
        case (.alerting, .countdown):
            // Snooze pressed.
            var r = self[day] ?? WakeRecord(date: day, scheduled: scheduled, rang: rangAt)
            r.snoozes += 1
            self[day] = r
            return true
        case (.alerting, .absent), (.countdown, .absent), (.paused, .absent):
            // Stopped from the alert or during a snooze.
            var r = self[day] ?? WakeRecord(date: day, scheduled: scheduled, rang: rangAt)
            if r.rang == nil { r.rang = rangAt }
            r.stopped = now
            self[day] = r
            return true
        default:
            return false
        }
    }
}

// MARK: - Merging copies from two devices

extension WakeRecord {
    /// Combine two observations of the same morning, field by field.
    ///
    /// Not last-write-wins: the two copies are usually *both* partial. The phone that was
    /// on the nightstand saw the ring and the stop; a second device may have seen only
    /// the schedule, and Health may have filled the sleep figure in on either. Taking the
    /// whole newer blob would throw away whichever half it lacked.
    public func merged(with other: WakeRecord) -> WakeRecord {
        precondition(date == other.date, "Only records for the same morning can merge.")
        var out = self
        // The earliest observation of an event is the truthful one: a later stamp means
        // the other device noticed late, not that the alarm rang twice.
        out.scheduled = min(scheduled, other.scheduled)
        out.rang = [rang, other.rang].compactMap { $0 }.min()
        out.stopped = [stopped, other.stopped].compactMap { $0 }.min()
        // Snoozes are counted, not observed at an instant, so the device that saw more
        // of the morning has the better number.
        out.snoozes = max(snoozes, other.snoozes)
        out.sleepMinutes = sleepMinutes ?? other.sleepMinutes
        return out
    }
}

extension WakeHistory {
    /// The union of two histories, merging any morning both of them hold.
    public func merged(with other: WakeHistory) -> WakeHistory {
        var out = self
        for record in other.records {
            out[record.date] = out[record.date].map { $0.merged(with: record) } ?? record
        }
        return out
    }
}

// MARK: - Mornings no transition was seen for

/// When one day's alarm was set to go off, kept beside the alarm id so the morning can
/// still be recorded after AlarmKit has dropped the alarm and its schedule with it.
public struct ScheduledMorning: Sendable, Codable, Equatable {
    /// The instant handed to AlarmKit: earlier than `alertsAt` by any pre-alarm countdown.
    public var scheduled: Date
    /// When the alarm alerts.
    public var alertsAt: Date

    public init(scheduled: Date, alertsAt: Date) {
        self.scheduled = scheduled
        self.alertsAt = alertsAt
    }
}

extension WakeHistory {
    /// Days whose alarm should have gone off by `now`, is no longer scheduled, and left no
    /// record, oldest first.
    ///
    /// `record(from:to:…)` only sees transitions, and only while the app runs. Stop the
    /// alarm and open the app after AlarmKit has dropped it, and the alarm is in neither
    /// snapshot: without this the morning is lost. Days older than the retention window
    /// are left out, since `prune` would drop them again straight away.
    ///
    /// - Parameters:
    ///   - mornings: what was scheduled, per day.
    ///   - live: days whose alarm the system still holds. Those are still observable.
    public func unrecordedMornings(_ mornings: [DateKey: ScheduledMorning], live: Set<DateKey>,
                                   now: Date, calendar: Calendar = .current) -> [DateKey] {
        let cutoff = DateKey(date: now.addingTimeInterval(-Double(Self.retentionDays) * 86_400), calendar: calendar)
        return mornings
            .filter { day, morning in
                morning.alertsAt <= now && !live.contains(day) && day >= cutoff && self[day] == nil
            }
            .keys
            .sorted()
    }

    /// Records every morning `unrecordedMornings` finds, as rung on schedule with the stop
    /// unknown. Returns whether anything changed.
    ///
    /// AlarmKit alerts exactly on schedule, so `rang` is as good as an observed one. When it
    /// was stopped, and how often it was snoozed, cannot be known, so `stopped` stays `nil`
    /// and the morning does not count toward the streak or the averages.
    public mutating func recordUnobserved(_ mornings: [DateKey: ScheduledMorning], live: Set<DateKey>,
                                          now: Date, calendar: Calendar = .current) -> Bool {
        let missed = unrecordedMornings(mornings, live: live, now: now, calendar: calendar)
        for day in missed {
            guard let morning = mornings[day] else { continue }
            self[day] = WakeRecord(date: day, scheduled: morning.scheduled, rang: morning.alertsAt)
        }
        return !missed.isEmpty
    }
}
