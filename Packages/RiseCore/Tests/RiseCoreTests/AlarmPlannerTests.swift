import Testing
import Foundation
@testable import RiseCore

struct AlarmPlannerTests {
    let tz = TimeZone(identifier: "America/Denver")!
    var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = tz
        return c
    }

    /// Denver, mid-June: sunrise ≈ 05:32 MDT.
    var juneDay: SolarDay {
        SolarCalculator.solarDay(for: DateKey(year: 2026, month: 6, day: 15),
                                 latitude: 39.7392, longitude: -104.9903, timeZone: tz)
    }

    /// Denver, mid-December: sunrise ≈ 07:15 MST.
    var decemberDay: SolarDay {
        SolarCalculator.solarDay(for: DateKey(year: 2026, month: 12, day: 15),
                                 latitude: 39.7392, longitude: -104.9903, timeZone: tz)
    }

    private func hhmm(_ date: Date?) -> String {
        guard let date else { return "nil" }
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.timeZone = tz
        return f.string(from: date)
    }

    @Test func offsetBeforeSunrise() {
        var s = AlarmSettings()
        s.offsetMinutes = -30
        s.clampEnabled = false
        s.activeWeekdays = Set(1...7)
        let p = AlarmPlanner.plan(settings: s, day: juneDay, calendar: calendar)
        #expect(p.isActive)
        let sunrise = juneDay.sunrise!
        #expect(p.alarmTime == sunrise.addingTimeInterval(-1800))
        #expect(p.wasClamped == false)
    }

    @Test func clampPreventsTooEarlyWakeInSummer() {
        var s = AlarmSettings()
        s.offsetMinutes = -45           // would be ~04:47
        s.clampEnabled = true
        s.earliest = ClockTime(hour: 6, minute: 0)
        s.latest = ClockTime(hour: 8, minute: 0)
        s.activeWeekdays = Set(1...7)
        let p = AlarmPlanner.plan(settings: s, day: juneDay, calendar: calendar)
        #expect(p.wasClamped)
        #expect(hhmm(p.alarmTime) == "06:00")
    }

    @Test func clampPreventsTooLateWakeInWinter() {
        var s = AlarmSettings()
        s.offsetMinutes = 30            // would be ~07:45
        s.clampEnabled = true
        s.earliest = ClockTime(hour: 5, minute: 30)
        s.latest = ClockTime(hour: 7, minute: 0)
        s.activeWeekdays = Set(1...7)
        let p = AlarmPlanner.plan(settings: s, day: decemberDay, calendar: calendar)
        #expect(p.wasClamped)
        #expect(hhmm(p.alarmTime) == "07:00")
    }

    @Test func weekendOffProducesNoAlarmButStillBedtime() {
        var s = AlarmSettings()
        s.activeWeekdays = [2, 3, 4, 5, 6]  // Mon–Fri
        // 2026-06-14 is a Sunday.
        let sunday = SolarCalculator.solarDay(for: DateKey(year: 2026, month: 6, day: 14),
                                              latitude: 39.7392, longitude: -104.9903, timeZone: tz)
        let p = AlarmPlanner.plan(settings: s, day: sunday, calendar: calendar)
        #expect(p.status == .weekdayOff)
        #expect(p.alarmTime == nil)
        #expect(p.bedtime != nil)
    }

    @Test func skipDayWins() {
        var s = AlarmSettings()
        s.activeWeekdays = Set(1...7)
        s.skippedDays = [juneDay.date]
        let p = AlarmPlanner.plan(settings: s, day: juneDay, calendar: calendar)
        #expect(p.status == .skipped)
        #expect(p.alarmTime == nil)
    }

    @Test func bedtimeAndWindDownDeriveFromAlarm() {
        var s = AlarmSettings()
        s.clampEnabled = false
        s.offsetMinutes = 0
        s.sleepGoalMinutes = 7 * 60 + 30
        s.windDownMinutes = 45
        s.activeWeekdays = Set(1...7)
        let p = AlarmPlanner.plan(settings: s, day: juneDay, calendar: calendar)
        let alarm = p.alarmTime!
        #expect(p.bedtime == alarm.addingTimeInterval(-7.5 * 3600))
        #expect(p.windDownTime == alarm.addingTimeInterval(-7.5 * 3600 - 45 * 60))
        // Bedtime lands on the previous calendar day.
        #expect(DateKey(date: p.bedtime!, calendar: calendar) < p.date)
    }

    @Test func polarNightFallsBackToLatestWhenClamped() {
        let oslo = TimeZone(identifier: "Europe/Oslo")!
        var cal = Calendar(identifier: .gregorian); cal.timeZone = oslo
        let day = SolarCalculator.solarDay(for: DateKey(year: 2026, month: 12, day: 21),
                                           latitude: 69.6492, longitude: 18.9553, timeZone: oslo)
        var s = AlarmSettings()
        s.activeWeekdays = Set(1...7)
        s.clampEnabled = true
        s.latest = ClockTime(hour: 7, minute: 30)
        let p = AlarmPlanner.plan(settings: s, day: day, calendar: cal)
        #expect(p.isActive)
        #expect(p.wasClamped)
        #expect(cal.component(.hour, from: p.alarmTime!) == 7)
        #expect(cal.component(.minute, from: p.alarmTime!) == 30)

        s.clampEnabled = false
        let q = AlarmPlanner.plan(settings: s, day: day, calendar: cal)
        #expect(q.status == .noSunEvent)
    }

    @Test func nextAlarmSkipsPastAndInactive() {
        var s = AlarmSettings()
        s.activeWeekdays = Set(1...7)
        s.clampEnabled = false
        let days = SolarCalculator.solarDays(from: DateKey(year: 2026, month: 6, day: 15).startOfDay(in: calendar),
                                             count: 3, latitude: 39.7392, longitude: -104.9903, timeZone: tz)
        let plan = AlarmPlanner.plan(settings: s, days: days, calendar: calendar)
        let afterFirst = plan[0].alarmTime!.addingTimeInterval(60)
        let next = AlarmPlanner.nextAlarm(in: plan, after: afterFirst)
        #expect(next?.date == DateKey(year: 2026, month: 6, day: 16))
    }

    @Test func settingsRoundTripJSON() throws {
        var s = AlarmSettings()
        s.skippedDays = [DateKey(year: 2026, month: 9, day: 10)]
        s.location = SavedLocation(name: "Denver", latitude: 39.7, longitude: -104.9, followsDevice: false)
        let data = try JSONEncoder().encode(s)
        let back = try JSONDecoder().decode(AlarmSettings.self, from: data)
        #expect(back == s)
    }

    @Test func offsetDescription() {
        var s = AlarmSettings()
        s.offsetMinutes = -30
        #expect(s.offsetDescription == "30 min before sunrise")
        s.offsetMinutes = 90
        s.anchor = .civilDawn
        #expect(s.offsetDescription == "1 hr 30 min after dawn")
        s.offsetMinutes = 0
        #expect(s.offsetDescription == "At dawn")
    }
}
