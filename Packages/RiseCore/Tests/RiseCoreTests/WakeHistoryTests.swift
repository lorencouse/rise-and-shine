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
