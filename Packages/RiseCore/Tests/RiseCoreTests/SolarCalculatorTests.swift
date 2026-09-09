import Testing
import Foundation
@testable import RiseCore

/// Reference values come from the NOAA Solar Calculator / timeanddate.com. Tolerance is
/// two minutes, which is well inside what an alarm needs.
struct SolarCalculatorTests {

    private func hm(_ date: Date?, _ tz: TimeZone) -> String {
        guard let date else { return "nil" }
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.timeZone = tz
        return f.string(from: date)
    }

    private func minutes(_ date: Date?, _ tz: TimeZone) -> Int? {
        guard let date else { return nil }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let c = cal.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    private func expectClose(_ actual: Date?, _ expectedHHmm: String, tz: TimeZone, tolerance: Int = 2, _ label: String) {
        let parts = expectedHHmm.split(separator: ":").map { Int($0)! }
        let expected = parts[0] * 60 + parts[1]
        let got = minutes(actual, tz)
        #expect(got != nil, "\(label): got nil, expected \(expectedHHmm)")
        if let got {
            #expect(abs(got - expected) <= tolerance, "\(label): got \(hm(actual, tz)), expected \(expectedHHmm)")
        }
    }

    @Test func newYorkSummerSolstice() {
        let tz = TimeZone(identifier: "America/New_York")!
        let day = SolarCalculator.solarDay(for: DateKey(year: 2024, month: 6, day: 21),
                                           latitude: 40.7128, longitude: -74.0060, timeZone: tz)
        expectClose(day.sunrise, "05:25", tz: tz, "NYC sunrise")
        expectClose(day.sunset, "20:31", tz: tz, "NYC sunset")
        expectClose(day.civilDawn, "04:52", tz: tz, "NYC civil dawn")
    }

    @Test func londonWinterSolstice() {
        let tz = TimeZone(identifier: "Europe/London")!
        let day = SolarCalculator.solarDay(for: DateKey(year: 2024, month: 12, day: 21),
                                           latitude: 51.5074, longitude: -0.1278, timeZone: tz)
        expectClose(day.sunrise, "08:04", tz: tz, "London sunrise")
        expectClose(day.sunset, "15:53", tz: tz, "London sunset")
    }

    @Test func sydneyNewYear() {
        let tz = TimeZone(identifier: "Australia/Sydney")!
        let day = SolarCalculator.solarDay(for: DateKey(year: 2024, month: 1, day: 1),
                                           latitude: -33.8688, longitude: 151.2093, timeZone: tz)
        expectClose(day.sunrise, "05:47", tz: tz, "Sydney sunrise")
        expectClose(day.sunset, "20:09", tz: tz, "Sydney sunset")
    }

    @Test func taipeiEquinox() {
        let tz = TimeZone(identifier: "Asia/Taipei")!
        let day = SolarCalculator.solarDay(for: DateKey(year: 2025, month: 3, day: 20),
                                           latitude: 25.0330, longitude: 121.5654, timeZone: tz)
        expectClose(day.sunrise, "05:57", tz: tz, "Taipei sunrise")
        expectClose(day.sunset, "18:05", tz: tz, "Taipei sunset")
    }

    @Test func tromsoPolarNightHasNoSunrise() {
        let tz = TimeZone(identifier: "Europe/Oslo")!
        let day = SolarCalculator.solarDay(for: DateKey(year: 2024, month: 12, day: 21),
                                           latitude: 69.6492, longitude: 18.9553, timeZone: tz)
        #expect(day.sunrise == nil)
        #expect(day.sunset == nil)
        // Civil twilight still happens in Tromsø in December.
        #expect(day.civilDawn != nil)
    }

    @Test func tromsoMidnightSunHasNoSunset() {
        let tz = TimeZone(identifier: "Europe/Oslo")!
        let day = SolarCalculator.solarDay(for: DateKey(year: 2024, month: 6, day: 21),
                                           latitude: 69.6492, longitude: 18.9553, timeZone: tz)
        #expect(day.sunrise == nil)
        #expect(day.sunset == nil)
    }

    @Test func eventsAreOrdered() {
        let tz = TimeZone(identifier: "America/Los_Angeles")!
        let day = SolarCalculator.solarDay(for: DateKey(year: 2026, month: 9, day: 9),
                                           latitude: 37.7749, longitude: -122.4194, timeZone: tz)
        let ordered = [day.astronomicalDawn, day.nauticalDawn, day.civilDawn, day.sunrise,
                       day.solarNoon, day.sunset, day.civilDusk, day.nauticalDusk, day.astronomicalDusk]
            .compactMap { $0 }
        #expect(ordered == ordered.sorted())
        #expect(ordered.count == 9)
    }

    @Test func consecutiveDaysAreDistinctAndAscending() {
        let tz = TimeZone(identifier: "Europe/Berlin")!
        let days = SolarCalculator.solarDays(from: DateKey(year: 2026, month: 3, day: 27).startOfDay(in: {
            var c = Calendar(identifier: .gregorian); c.timeZone = tz; return c
        }()), count: 5, latitude: 52.52, longitude: 13.405, timeZone: tz)
        #expect(days.count == 5)
        let sunrises = days.compactMap(\.sunrise)
        #expect(sunrises == sunrises.sorted())
        // Spans the DST change on 2026-03-29; local sunrise should jump forward ~1 hour.
        let before = minutes(days[1].sunrise, tz)!  // Mar 28
        let after = minutes(days[2].sunrise, tz)!   // Mar 29
        #expect(after - before > 50 && after - before < 70)
    }
}
