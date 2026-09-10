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

    /// 2026-03-08 is the US spring-forward day: 02:00 becomes 03:00. Midnight + 330 min is
    /// 06:30 on the clock that day, but "no earlier than 5:30" has to mean 5:30.
    @Test func clockTimeIsWallClockOnDSTDays() {
        let springForward = DateKey(year: 2026, month: 3, day: 8)
        let fallBack = DateKey(year: 2026, month: 11, day: 1)
        let t = ClockTime(hour: 5, minute: 30)
        for key in [springForward, fallBack] {
            let d = t.date(on: key, calendar: calendar)
            #expect(calendar.component(.hour, from: d) == 5)
            #expect(calendar.component(.minute, from: d) == 30)
            #expect(DateKey(date: d, calendar: calendar) == key)
        }
    }

    @Test func clampHoldsOnSpringForwardDay() {
        var s = AlarmSettings()
        s.offsetMinutes = -120           // well before the earliest bound
        s.clampEnabled = true
        s.earliest = ClockTime(hour: 6, minute: 0)
        s.activeWeekdays = Set(1...7)
        let day = SolarCalculator.solarDay(for: DateKey(year: 2026, month: 3, day: 8),
                                           latitude: 39.7392, longitude: -104.9903, timeZone: tz)
        let p = AlarmPlanner.plan(settings: s, day: day, calendar: calendar)
        #expect(p.wasClamped)
        #expect(hhmm(p.alarmTime) == "06:00")
    }

    @Test func locationThresholdIgnoresGPSJitter() {
        let home = SavedLocation(name: "Denver", latitude: 39.7392, longitude: -104.9903,
                                 followsDevice: true, timeZoneIdentifier: "America/Denver")
        var jitter = home
        jitter.latitude += 0.002          // ~220 m
        jitter.name = "Denver, CO"
        #expect(!home.isMeaningfullyDifferent(from: jitter))

        var boulder = home
        boulder.latitude = 40.0150; boulder.longitude = -105.2705
        #expect(home.isMeaningfullyDifferent(from: boulder))

        var newZone = jitter
        newZone.timeZoneIdentifier = "America/Chicago"
        #expect(home.isMeaningfullyDifferent(from: newZone))

        var manual = jitter
        manual.followsDevice = false
        #expect(home.isMeaningfullyDifferent(from: manual))
    }

    @Test func pauseSilencesDaysBeforeResumeDate() {
        var s = AlarmSettings()
        s.activeWeekdays = Set(1...7)
        s.pausedUntil = DateKey(year: 2026, month: 6, day: 16)
        let paused = AlarmPlanner.plan(settings: s, day: juneDay, calendar: calendar)   // 15 June
        #expect(paused.status == .paused)
        #expect(paused.alarmTime == nil)
        let resumeDay = SolarCalculator.solarDay(for: DateKey(year: 2026, month: 6, day: 16),
                                                 latitude: 39.7392, longitude: -104.9903, timeZone: tz)
        #expect(AlarmPlanner.plan(settings: s, day: resumeDay, calendar: calendar).status == .active)
    }

    @Test func overrideRingsAtFixedTimeAndBeatsWeekdayOffAndPause() {
        var s = AlarmSettings()
        s.activeWeekdays = [2, 3, 4, 5, 6]
        s.pausedUntil = DateKey(year: 2026, month: 7, day: 1)
        // 2026-06-14 is a Sunday: normally off, and inside the pause.
        let sunday = SolarCalculator.solarDay(for: DateKey(year: 2026, month: 6, day: 14),
                                              latitude: 39.7392, longitude: -104.9903, timeZone: tz)
        s.dayOverrides[sunday.date] = ClockTime(hour: 4, minute: 45)
        let p = AlarmPlanner.plan(settings: s, day: sunday, calendar: calendar)
        #expect(p.status == .active)
        #expect(p.isOverridden)
        #expect(!p.wasClamped)
        #expect(hhmm(p.alarmTime) == "04:45")

        // A skip still wins.
        s.skippedDays = [sunday.date]
        #expect(AlarmPlanner.plan(settings: s, day: sunday, calendar: calendar).status == .skipped)
    }

    @Test func weekendProfileAppliesOnSaturdayAndSunday() {
        var s = AlarmSettings()
        s.activeWeekdays = Set(1...7)
        s.clampEnabled = false
        s.offsetMinutes = -30
        s.weekendProfile = WakeProfile(anchor: .sunrise, offsetMinutes: 90, clampEnabled: false)
        let sunday = SolarCalculator.solarDay(for: DateKey(year: 2026, month: 6, day: 14),
                                              latitude: 39.7392, longitude: -104.9903, timeZone: tz)
        let weekend = AlarmPlanner.plan(settings: s, day: sunday, calendar: calendar)
        #expect(weekend.alarmTime == sunday.sunrise!.addingTimeInterval(90 * 60))
        let monday = AlarmPlanner.plan(settings: s, day: juneDay, calendar: calendar)   // 15 June
        #expect(monday.alarmTime == juneDay.sunrise!.addingTimeInterval(-30 * 60))
    }

    @Test func newFieldsRoundTripAndOldFilesStillDecode() throws {
        var s = AlarmSettings()
        s.dayOverrides = [DateKey(year: 2026, month: 9, day: 10): ClockTime(hour: 5, minute: 0)]
        s.pausedUntil = DateKey(year: 2026, month: 9, day: 20)
        s.weekendProfile = WakeProfile(offsetMinutes: 60)
        let data = try JSONEncoder().encode(s)
        #expect(try JSONDecoder().decode(AlarmSettings.self, from: data) == s)

        // A v2.0 file has none of the new keys.
        let legacy = """
        {"version":1,"isEnabled":true,"anchor":"sunrise","offsetMinutes":-30,"clampEnabled":true,
         "earliest":{"minutes":330},"latest":{"minutes":480},"activeWeekdays":[2,3,4,5,6],
         "skippedDays":[],"snoozeMinutes":9,"sleepGoalMinutes":480,"windDownMinutes":30,
         "remindersEnabled":true,"soundFile":"Phone Chime 1.caf","horizonDays":14,"onboardingCompleted":true}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AlarmSettings.self, from: legacy)
        #expect(decoded.dayOverrides.isEmpty)
        #expect(decoded.pausedUntil == nil)
        #expect(decoded.weekendProfile == nil)
    }

    /// A field whose shape is wrong must not cost the user their whole configuration: a
    /// failed decode would look like "no settings" and send them back to onboarding.
    @Test func malformedFieldFallsBackWithoutLosingTheFile() throws {
        let broken = """
        {"isEnabled":true,"anchor":"sunrise","offsetMinutes":-45,
         "dayOverrides":{},"skippedDays":"nonsense","activeWeekdays":[1,2],
         "sleepGoalMinutes":"eight hours","soundFile":"Warning 1.caf","onboardingCompleted":true,
         "location":{"name":"Oslo","latitude":59.91,"longitude":10.75,"followsDevice":false}}
        """.data(using: .utf8)!
        let s = try JSONDecoder().decode(AlarmSettings.self, from: broken)

        // Good fields survive.
        #expect(s.offsetMinutes == -45)
        #expect(s.activeWeekdays == [1, 2])
        #expect(s.soundFile == "Warning 1.caf")
        #expect(s.onboardingCompleted)
        #expect(s.location?.name == "Oslo")

        // Bad ones fall back to defaults rather than throwing.
        let d = AlarmSettings()
        #expect(s.skippedDays == d.skippedDays)
        #expect(s.dayOverrides.isEmpty)
        #expect(s.sleepGoalMinutes == d.sleepGoalMinutes)
    }
}
