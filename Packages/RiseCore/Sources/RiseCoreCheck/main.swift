// A dependency-free sanity check for RiseCore that runs with `swift run RiseCoreCheck`
// on a machine that has only the Command Line Tools (no XCTest / Swift Testing runtime).
// The real unit tests live in Tests/RiseCoreTests and run in Xcode.
import Foundation
import RiseCore

var failures = 0
@MainActor func check(_ condition: Bool, _ message: String) {
    if condition { print("  ✓ \(message)") } else { failures += 1; print("  ✗ \(message)") }
}
func minutes(_ date: Date?, _ tz: TimeZone) -> Int? {
    guard let date else { return nil }
    var cal = Calendar(identifier: .gregorian); cal.timeZone = tz
    let c = cal.dateComponents([.hour, .minute], from: date)
    return (c.hour ?? 0) * 60 + (c.minute ?? 0)
}
func hhmm(_ date: Date?, _ tz: TimeZone) -> String {
    guard let date else { return "nil" }
    let f = DateFormatter(); f.dateFormat = "HH:mm"; f.timeZone = tz
    return f.string(from: date)
}
@MainActor func close(_ actual: Date?, _ expected: String, _ tz: TimeZone, _ label: String, tolerance: Int = 2) {
    let p = expected.split(separator: ":").map { Int($0)! }
    let want = p[0] * 60 + p[1]
    if let got = minutes(actual, tz) {
        check(abs(got - want) <= tolerance, "\(label): \(hhmm(actual, tz)) ≈ \(expected)")
    } else {
        check(false, "\(label): nil, expected \(expected)")
    }
}

print("SolarCalculator against NOAA / timeanddate reference values")
do {
    let tz = TimeZone(identifier: "America/New_York")!
    let d = SolarCalculator.solarDay(for: DateKey(year: 2024, month: 6, day: 21), latitude: 40.7128, longitude: -74.0060, timeZone: tz)
    close(d.sunrise, "05:25", tz, "NYC Jun 21 sunrise"); close(d.sunset, "20:31", tz, "NYC Jun 21 sunset"); close(d.civilDawn, "04:52", tz, "NYC civil dawn")
}
do {
    let tz = TimeZone(identifier: "Europe/London")!
    let d = SolarCalculator.solarDay(for: DateKey(year: 2024, month: 12, day: 21), latitude: 51.5074, longitude: -0.1278, timeZone: tz)
    close(d.sunrise, "08:04", tz, "London Dec 21 sunrise"); close(d.sunset, "15:53", tz, "London Dec 21 sunset")
}
do {
    let tz = TimeZone(identifier: "Australia/Sydney")!
    let d = SolarCalculator.solarDay(for: DateKey(year: 2024, month: 1, day: 1), latitude: -33.8688, longitude: 151.2093, timeZone: tz)
    close(d.sunrise, "05:47", tz, "Sydney Jan 1 sunrise"); close(d.sunset, "20:09", tz, "Sydney Jan 1 sunset")
}
do {
    let tz = TimeZone(identifier: "Asia/Taipei")!
    let d = SolarCalculator.solarDay(for: DateKey(year: 2025, month: 3, day: 20), latitude: 25.0330, longitude: 121.5654, timeZone: tz)
    close(d.sunrise, "05:57", tz, "Taipei equinox sunrise"); close(d.sunset, "18:05", tz, "Taipei equinox sunset")
}
do {
    let tz = TimeZone(identifier: "Europe/Oslo")!
    let winter = SolarCalculator.solarDay(for: DateKey(year: 2024, month: 12, day: 21), latitude: 69.6492, longitude: 18.9553, timeZone: tz)
    check(winter.sunrise == nil && winter.sunset == nil && winter.civilDawn != nil, "Tromsø polar night: no sunrise, civil twilight present")
    let summer = SolarCalculator.solarDay(for: DateKey(year: 2024, month: 6, day: 21), latitude: 69.6492, longitude: 18.9553, timeZone: tz)
    check(summer.sunrise == nil && summer.sunset == nil, "Tromsø midnight sun: no sunrise/sunset")
}
do {
    let tz = TimeZone(identifier: "Europe/Berlin")!
    var cal = Calendar(identifier: .gregorian); cal.timeZone = tz
    let days = SolarCalculator.solarDays(from: DateKey(year: 2026, month: 3, day: 27).startOfDay(in: cal), count: 5, latitude: 52.52, longitude: 13.405, timeZone: tz)
    let before = minutes(days[1].sunrise, tz)!, after = minutes(days[2].sunrise, tz)!
    check(after - before > 50 && after - before < 70, "Berlin DST jump Mar 28→29: +\(after - before) min local")
}

print("AlarmPlanner")
do {
    let tz = TimeZone(identifier: "America/Denver")!
    var cal = Calendar(identifier: .gregorian); cal.timeZone = tz
    let june = SolarCalculator.solarDay(for: DateKey(year: 2026, month: 6, day: 15), latitude: 39.7392, longitude: -104.9903, timeZone: tz)
    let dec = SolarCalculator.solarDay(for: DateKey(year: 2026, month: 12, day: 15), latitude: 39.7392, longitude: -104.9903, timeZone: tz)

    var s = AlarmSettings(); s.activeWeekdays = Set(1...7); s.clampEnabled = false; s.offsetMinutes = -30
    let p1 = AlarmPlanner.plan(settings: s, day: june, calendar: cal)
    check(p1.isActive && p1.alarmTime == june.sunrise!.addingTimeInterval(-1800), "30 min before sunrise → \(hhmm(p1.alarmTime, tz)) (sunrise \(hhmm(june.sunrise, tz)))")

    s.clampEnabled = true; s.offsetMinutes = -45; s.earliest = ClockTime(hour: 6, minute: 0); s.latest = ClockTime(hour: 8, minute: 0)
    let p2 = AlarmPlanner.plan(settings: s, day: june, calendar: cal)
    check(p2.wasClamped && hhmm(p2.alarmTime, tz) == "06:00", "summer clamp to earliest 06:00 → \(hhmm(p2.alarmTime, tz))")

    s.offsetMinutes = 30; s.latest = ClockTime(hour: 7, minute: 0)
    let p3 = AlarmPlanner.plan(settings: s, day: dec, calendar: cal)
    check(p3.wasClamped && hhmm(p3.alarmTime, tz) == "07:00", "winter clamp to latest 07:00 → \(hhmm(p3.alarmTime, tz))")

    s = AlarmSettings(); s.activeWeekdays = [2, 3, 4, 5, 6]
    let sunday = SolarCalculator.solarDay(for: DateKey(year: 2026, month: 6, day: 14), latitude: 39.7392, longitude: -104.9903, timeZone: tz)
    let p4 = AlarmPlanner.plan(settings: s, day: sunday, calendar: cal)
    check(p4.status == .weekdayOff && p4.alarmTime == nil && p4.bedtime != nil, "Sunday off: no alarm, bedtime still computed")

    s.activeWeekdays = Set(1...7); s.skippedDays = [june.date]
    check(AlarmPlanner.plan(settings: s, day: june, calendar: cal).status == .skipped, "one-off skip")

    s = AlarmSettings(); s.activeWeekdays = Set(1...7); s.clampEnabled = false; s.offsetMinutes = 0; s.sleepGoalMinutes = 450; s.windDownMinutes = 45
    let p5 = AlarmPlanner.plan(settings: s, day: june, calendar: cal)
    check(p5.bedtime == p5.alarmTime!.addingTimeInterval(-450 * 60) && p5.windDownTime == p5.bedtime!.addingTimeInterval(-45 * 60) && DateKey(date: p5.bedtime!, calendar: cal) < p5.date,
          "bedtime \(hhmm(p5.bedtime, tz)) / wind-down \(hhmm(p5.windDownTime, tz)) the evening before")

    let oslo = TimeZone(identifier: "Europe/Oslo")!
    var ocal = Calendar(identifier: .gregorian); ocal.timeZone = oslo
    let polar = SolarCalculator.solarDay(for: DateKey(year: 2026, month: 12, day: 21), latitude: 69.6492, longitude: 18.9553, timeZone: oslo)
    s = AlarmSettings(); s.activeWeekdays = Set(1...7); s.latest = ClockTime(hour: 7, minute: 30)
    let p6 = AlarmPlanner.plan(settings: s, day: polar, calendar: ocal)
    check(p6.isActive && p6.wasClamped && hhmm(p6.alarmTime, oslo) == "07:30", "polar night with clamp → latest 07:30")
    s.clampEnabled = false
    check(AlarmPlanner.plan(settings: s, day: polar, calendar: ocal).status == .noSunEvent, "polar night without clamp → noSunEvent")

    s = AlarmSettings(); s.activeWeekdays = Set(1...7); s.clampEnabled = false
    let days = SolarCalculator.solarDays(from: DateKey(year: 2026, month: 6, day: 15).startOfDay(in: cal), count: 3, latitude: 39.7392, longitude: -104.9903, timeZone: tz)
    let plan = AlarmPlanner.plan(settings: s, days: days, calendar: cal)
    check(AlarmPlanner.nextAlarm(in: plan, after: plan[0].alarmTime!.addingTimeInterval(60))?.date == DateKey(year: 2026, month: 6, day: 16), "nextAlarm skips past alarm")

    var rt = AlarmSettings(); rt.skippedDays = [DateKey(year: 2026, month: 9, day: 10)]
    rt.location = SavedLocation(name: "Denver", latitude: 39.7, longitude: -104.9, followsDevice: false)
    let data = try! JSONEncoder().encode(rt)
    check(try! JSONDecoder().decode(AlarmSettings.self, from: data) == rt, "settings JSON round-trip")

    var od = AlarmSettings(); od.offsetMinutes = -30
    check(od.offsetDescription == "30 min before sunrise", "offsetDescription: \(od.offsetDescription)")
    od.offsetMinutes = 90; od.anchor = .civilDawn
    check(od.offsetDescription == "1 hr 30 min after dawn", "offsetDescription: \(od.offsetDescription)")
}

print(failures == 0 ? "\nALL CHECKS PASSED" : "\n\(failures) CHECK(S) FAILED")
exit(failures == 0 ? 0 : 1)
