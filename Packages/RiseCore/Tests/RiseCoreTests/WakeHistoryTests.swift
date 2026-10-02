import Testing
import Foundation
@testable import RiseCore

struct WakeHistoryTests {
    private func record(_ day: Int, snoozes: Int, stopped: Bool = true) -> WakeRecord {
        let date = DateKey(year: 2026, month: 9, day: day)
        let t = Date(timeIntervalSince1970: 1_788_000_000 + Double(day) * 86_400)
        return WakeRecord(date: date, scheduled: t, rang: t, stopped: stopped ? t.addingTimeInterval(Double(snoozes) * 540 + 30) : nil, snoozes: snoozes)
    }

    @Test func streakCountsRecentCleanMorningsOnly() {
        var h = WakeHistory()
        h[DateKey(year: 2026, month: 9, day: 1)] = record(1, snoozes: 2)
        h[DateKey(year: 2026, month: 9, day: 2)] = record(2, snoozes: 0)
        h[DateKey(year: 2026, month: 9, day: 3)] = record(3, snoozes: 0)
        h[DateKey(year: 2026, month: 9, day: 4)] = record(4, snoozes: 0, stopped: false)   // still ringing: ignored
        #expect(h.cleanStreak == 2)
        #expect(h.completed.count == 3)
        #expect(h.averageSnoozes.map { abs($0 - 2.0 / 3.0) < 0.001 } == true)
    }

    @Test func subscriptReplacesAndSorts() {
        var h = WakeHistory()
        h[DateKey(year: 2026, month: 9, day: 5)] = record(5, snoozes: 1)
        h[DateKey(year: 2026, month: 9, day: 3)] = record(3, snoozes: 0)
        h[DateKey(year: 2026, month: 9, day: 5)] = record(5, snoozes: 3)
        #expect(h.records.map(\.date.day) == [3, 5])
        #expect(h[DateKey(year: 2026, month: 9, day: 5)]?.snoozes == 3)
    }

    @Test func pruneDropsOldMornings() {
        var h = WakeHistory()
        for d in 1...5 { h[DateKey(year: 2026, month: 9, day: d)] = record(d, snoozes: 0) }
        h.prune(before: DateKey(year: 2026, month: 9, day: 4))
        #expect(h.records.map(\.date.day) == [4, 5])
    }

    @Test func lingerMeasuresRingToStop() {
        let r = record(1, snoozes: 1)   // stopped 570 s after ringing
        #expect(r.lingered == 570)
        #expect(!r.wokeCleanly)
        #expect(record(2, snoozes: 0).wokeCleanly)
    }
}

// MARK: - Recording observed transitions

@Suite("Wake record transitions")
struct WakeRecordTransitionTests {
    private let day = DateKey(year: 2026, month: 9, day: 10)
    /// The alarm was set for 06:49 and stopped at 06:52; the app only looked at 08:26.
    private let scheduled = Date(timeIntervalSince1970: 1_788_000_000)
    private var rangAt: Date { scheduled }
    private var muchLater: Date { scheduled.addingTimeInterval(5_820) }   // +1h37m

    @Test("A ring seen live records the schedule's time, not the observation's")
    func ringUsesScheduleTime() {
        var h = WakeHistory()
        let changed = h.record(from: .scheduled, to: .alerting, day: day,
                         scheduled: scheduled, rangAt: rangAt, now: muchLater)
        #expect(changed)
        #expect(h[day]?.rang == rangAt)
    }

    /// The regression: `rang` used to be stamped with the observation time, so an alarm
    /// that rang at 06:49 and was first seen at 08:26 recorded 08:26.
    @Test("A stop seen at the next launch still records when the alarm actually rang")
    func stopObservedLateKeepsTheRealRingTime() {
        var h = WakeHistory()
        let changed = h.record(from: .alerting, to: .absent, day: day,
                         scheduled: scheduled, rangAt: rangAt, now: muchLater)
        #expect(changed)
        let r = try! #require(h[day])
        #expect(r.rang == rangAt)
        #expect(r.stopped == muchLater)
        #expect(r.lingered == 5_820)
    }

    @Test("Only the first ring counts as rang")
    func reRingAfterSnoozeDoesNotMoveRang() {
        var h = WakeHistory()
        _ = h.record(from: .scheduled, to: .alerting, day: day,
                     scheduled: scheduled, rangAt: rangAt, now: rangAt)
        _ = h.record(from: .alerting, to: .countdown, day: day,
                     scheduled: scheduled, rangAt: rangAt, now: rangAt)
        // Rings again when the snooze ends.
        let changed = h.record(from: .countdown, to: .alerting, day: day,
                          scheduled: scheduled, rangAt: rangAt, now: muchLater)
        #expect(!changed)
        #expect(h[day]?.rang == rangAt)
        #expect(h[day]?.snoozes == 1)
    }

    @Test("Snoozing then stopping counts the snooze and is not a clean wake")
    func snoozeThenStop() {
        var h = WakeHistory()
        _ = h.record(from: .scheduled, to: .alerting, day: day,
                     scheduled: scheduled, rangAt: rangAt, now: rangAt)
        _ = h.record(from: .alerting, to: .countdown, day: day,
                     scheduled: scheduled, rangAt: rangAt, now: rangAt)
        _ = h.record(from: .countdown, to: .absent, day: day,
                     scheduled: scheduled, rangAt: rangAt, now: muchLater)
        let r = try! #require(h[day])
        #expect(r.snoozes == 1)
        #expect(r.stopped == muchLater)
        #expect(!r.wokeCleanly)
        #expect(h.cleanStreak == 0)
    }

    @Test("Stopping straight from the alert is a clean wake")
    func stopWithoutSnoozeIsClean() {
        var h = WakeHistory()
        _ = h.record(from: .scheduled, to: .alerting, day: day,
                     scheduled: scheduled, rangAt: rangAt, now: rangAt)
        _ = h.record(from: .alerting, to: .absent, day: day,
                     scheduled: scheduled, rangAt: rangAt, now: rangAt.addingTimeInterval(180))
        #expect(h[day]?.wokeCleanly == true)
        #expect(h.cleanStreak == 1)
        #expect(h.completed.count == 1)
    }

    @Test("Transitions that carry no information change nothing")
    func inertTransitions() {
        var h = WakeHistory()
        let becameScheduled = h.record(from: .absent, to: .scheduled, day: day,
                                       scheduled: scheduled, rangAt: rangAt, now: rangAt)
        #expect(!becameScheduled)
        let stayedScheduled = h.record(from: .scheduled, to: .scheduled, day: day,
                                       scheduled: scheduled, rangAt: rangAt, now: rangAt)
        #expect(!stayedScheduled)
        #expect(h[day] == nil)
    }
}

/// The morning lost when the app was not opened while the alarm still existed: stopped,
/// then dropped by AlarmKit before any snapshot saw it go.
@Suite("Mornings no transition was seen for")
struct UnobservedMorningTests {
    private let utc: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()
    private let day = DateKey(year: 2026, month: 9, day: 10)
    /// 06:49 UTC on 2026-09-10, with a five-minute pre-alarm countdown before it.
    private var alertsAt: Date { day.startOfDay(in: utc).addingTimeInterval(6 * 3_600 + 49 * 60) }
    private var morning: ScheduledMorning { ScheduledMorning(scheduled: alertsAt.addingTimeInterval(-300), alertsAt: alertsAt) }
    private var later: Date { alertsAt.addingTimeInterval(5_820) }

    @Test("A past morning whose alarm is gone gets a record that rang on schedule")
    func recordsTheLostMorning() {
        var h = WakeHistory()
        #expect(h.unrecordedMornings([day: morning], live: [], now: later, calendar: utc) == [day])
        let changed = h.recordUnobserved([day: morning], live: [], now: later, calendar: utc)
        #expect(changed)
        let r = try! #require(h[day])
        #expect(r.scheduled == morning.scheduled)
        #expect(r.rang == alertsAt)
        #expect(r.stopped == nil)
        #expect(r.snoozes == 0)
        // The stop is unknown, so it must not pass for a clean wake.
        #expect(h.completed.isEmpty)
        #expect(h.cleanStreak == 0)
    }

    @Test("An alarm still held by the system is left to the transitions")
    func liveAlarmIsSkipped() {
        let h = WakeHistory()
        #expect(h.unrecordedMornings([day: morning], live: [day], now: later, calendar: utc).isEmpty)
    }

    @Test("A morning that has not rung yet is not a missed one")
    func futureMorningIsSkipped() {
        let h = WakeHistory()
        let before = alertsAt.addingTimeInterval(-60)
        #expect(h.unrecordedMornings([day: morning], live: [], now: before, calendar: utc).isEmpty)
        #expect(h.unrecordedMornings([day: morning], live: [], now: alertsAt, calendar: utc) == [day])
    }

    @Test("A morning already recorded keeps what the transitions saw")
    func existingRecordWins() {
        var h = WakeHistory()
        _ = h.record(from: .alerting, to: .absent, day: day,
                     scheduled: morning.scheduled, rangAt: alertsAt, now: alertsAt.addingTimeInterval(120))
        let seen = h[day]
        let changed = h.recordUnobserved([day: morning], live: [], now: later, calendar: utc)
        #expect(!changed)
        #expect(h[day] == seen)
    }

    @Test("Several missed mornings come back oldest first, inside the retention window")
    func severalDaysAndRetention() {
        let h = WakeHistory()
        func morning(on key: DateKey) -> ScheduledMorning {
            let t = key.startOfDay(in: utc).addingTimeInterval(6 * 3_600)
            return ScheduledMorning(scheduled: t, alertsAt: t)
        }
        let recent = (1...3).map { day.adding(days: -$0, in: utc) }
        let ancient = day.adding(days: -(WakeHistory.retentionDays + 5), in: utc)
        var mornings = Dictionary(uniqueKeysWithValues: recent.map { ($0, morning(on: $0)) })
        mornings[ancient] = morning(on: ancient)
        #expect(h.unrecordedMornings(mornings, live: [], now: later, calendar: utc) == recent.reversed())
    }
}

/// Merging the copies two devices keep. The point of the sync is that history survives
/// a new phone, which means a union, not a last-write-wins overwrite.
struct WakeHistoryMergeTests {
    private let day = DateKey(year: 2026, month: 9, day: 12)
    private let base = Date(timeIntervalSince1970: 1_788_030_000)

    private func record(scheduled: Double = 0, rang: Double? = nil, stopped: Double? = nil,
                        snoozes: Int = 0, sleep: Int? = nil) -> WakeRecord {
        WakeRecord(date: day,
                   scheduled: base.addingTimeInterval(scheduled),
                   rang: rang.map { base.addingTimeInterval($0) },
                   stopped: stopped.map { base.addingTimeInterval($0) },
                   snoozes: snoozes,
                   sleepMinutes: sleep)
    }

    @Test func mergeFillsInWhatEachCopyIsMissing() {
        let mine = record(rang: 0, snoozes: 1)
        let theirs = record(stopped: 300, sleep: 430)
        let merged = mine.merged(with: theirs)
        #expect(merged.rang == base)
        #expect(merged.stopped == base.addingTimeInterval(300))
        #expect(merged.snoozes == 1)
        #expect(merged.sleepMinutes == 430)
    }

    /// A device that only noticed at its next launch stamps the event late; the earlier
    /// stamp is the one that actually happened.
    @Test func mergeKeepsTheEarliestObservation() {
        let early = record(rang: 0, stopped: 120)
        let late = record(rang: 5_000, stopped: 6_000)
        #expect(early.merged(with: late).rang == base)
        #expect(late.merged(with: early).stopped == base.addingTimeInterval(120))
    }

    @Test func mergeTakesTheHigherSnoozeCount() {
        #expect(record(snoozes: 1).merged(with: record(snoozes: 3)).snoozes == 3)
        #expect(record(snoozes: 3).merged(with: record(snoozes: 1)).snoozes == 3)
    }

    /// The case the whole feature exists for: a fresh phone with nothing takes the lot.
    @Test func historyMergeIsAUnionAcrossDays() {
        var mine = WakeHistory()
        mine[DateKey(year: 2026, month: 9, day: 1)] = WakeRecord(date: DateKey(year: 2026, month: 9, day: 1), scheduled: base)
        var theirs = WakeHistory()
        theirs[DateKey(year: 2026, month: 9, day: 2)] = WakeRecord(date: DateKey(year: 2026, month: 9, day: 2), scheduled: base)

        let merged = mine.merged(with: theirs)
        #expect(merged.records.map(\.date.day) == [1, 2])
        #expect(WakeHistory().merged(with: theirs).records.count == 1)
    }

    @Test func historyMergeCombinesTheSameMorningRatherThanReplacingIt() {
        var mine = WakeHistory()
        mine[day] = record(rang: 0)
        var theirs = WakeHistory()
        theirs[day] = record(stopped: 300, sleep: 400)

        let merged = mine.merged(with: theirs)
        #expect(merged.records.count == 1)
        #expect(merged[day]?.rang == base)
        #expect(merged[day]?.stopped == base.addingTimeInterval(300))
        #expect(merged[day]?.sleepMinutes == 400)
    }

    @Test func mergeIsOrderIndependent() {
        let a = record(rang: 0, snoozes: 2)
        let b = record(stopped: 600, sleep: 415)
        #expect(a.merged(with: b) == b.merged(with: a))
    }
}
