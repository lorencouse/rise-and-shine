import Testing
import Foundation
@testable import Rise_and_Shine

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
}
