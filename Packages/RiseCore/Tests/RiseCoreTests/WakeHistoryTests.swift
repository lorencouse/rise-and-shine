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
