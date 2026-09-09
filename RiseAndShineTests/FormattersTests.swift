import Testing
import Foundation
@testable import RiseAndShine

struct FormattersTests {
    @Test func durations() {
        #expect(Formatters.duration(minutes: 30) == "30 min")
        #expect(Formatters.duration(minutes: 120) == "2 hr")
        #expect(Formatters.duration(minutes: 450) == "7 hr 30 min")
    }

    @Test func countdownUnderAMinute() {
        let now = Date()
        #expect(Formatters.countdown(to: now.addingTimeInterval(20), from: now) == "less than a minute")
    }

    /// The whole point of the zone parameter: one instant, two clocks. This instant is
    /// 06:20 on 1 June in Reykjavík (GMT year-round) but 23:20 on 31 May in Los Angeles —
    /// a different hour *and* a different day.
    @Test func timeIsRenderedInTheGivenZone() {
        #expect(hourMinute(Self.instant, Self.reykjavik) == (6, 20))
        #expect(hourMinute(Self.instant, Self.losAngeles) == (23, 20))
        #expect(Formatters.time(Self.instant, in: Self.reykjavik)
                != Formatters.time(Self.instant, in: Self.losAngeles))
    }

    /// "Today"/"Tomorrow" must be decided on the location's calendar. Three hours later
    /// both zones have rolled into 1 June, so the instant is still "Today" in Reykjavík
    /// but is the previous day in Los Angeles and must not claim to be today.
    @Test func dayLabelUsesTheGivenZone() {
        let now = Self.instant.addingTimeInterval(3 * 3600)

        #expect(Formatters.dayLabel(Self.instant, in: Self.reykjavik, relativeTo: now) == "Today")

        let laLabel = Formatters.dayLabel(Self.instant, in: Self.losAngeles, relativeTo: now)
        #expect(laLabel != "Today")
        #expect(laLabel.contains("May"))
    }

    private static let instant = Date(timeIntervalSince1970: 1_780_294_800)
    private static let reykjavik = TimeZone(identifier: "Atlantic/Reykjavik")!
    private static let losAngeles = TimeZone(identifier: "America/Los_Angeles")!

    private func hourMinute(_ date: Date, _ zone: TimeZone) -> (Int, Int) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? -1, c.minute ?? -1)
    }
}
