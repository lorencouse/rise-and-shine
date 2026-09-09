import Foundation

/// The computed plan for a single wake-up.
public struct PlannedDay: Sendable, Codable, Equatable, Identifiable {
    public var id: DateKey { date }

    /// The morning this alarm rings.
    public let date: DateKey
    public let solar: SolarDay

    /// Why (or whether) the alarm is off this day.
    public let status: Status

    /// The alarm instant, `nil` if the day is inactive or the sun never reaches the anchor
    /// and no clamp is set.
    public let alarmTime: Date?

    /// True when the clamp moved the alarm away from the pure sun-relative time.
    public let wasClamped: Bool

    /// The evening before: when to be asleep to meet the sleep goal.
    public let bedtime: Date?
    /// The evening before: when to start winding down.
    public let windDownTime: Date?

    public enum Status: String, Sendable, Codable {
        case active
        case disabled          // master switch off
        case weekdayOff        // not an active weekday
        case skipped           // one-off skip
        case noSunEvent        // polar day/night and clamp disabled
    }

    public var isActive: Bool { status == .active && alarmTime != nil }
}

/// Turns settings + solar days into concrete alarm, bedtime and wind-down instants.
public enum AlarmPlanner {

    public static func plan(
        settings: AlarmSettings,
        days: [SolarDay],
        calendar: Calendar = .current
    ) -> [PlannedDay] {
        days.map { plan(settings: settings, day: $0, calendar: calendar) }
    }

    public static func plan(
        settings: AlarmSettings,
        day: SolarDay,
        calendar: Calendar = .current
    ) -> PlannedDay {
        let (rawTime, clamped) = alarmInstant(settings: settings, day: day, calendar: calendar)

        let status: PlannedDay.Status
        if !settings.isEnabled {
            status = .disabled
        } else if settings.skippedDays.contains(day.date) {
            status = .skipped
        } else if !settings.activeWeekdays.contains(day.date.weekday(in: calendar)) {
            status = .weekdayOff
        } else if rawTime == nil {
            status = .noSunEvent
        } else {
            status = .active
        }

        // Bedtime is still useful on inactive days for the "tonight" card, so derive it
        // from the would-be alarm time whenever one exists.
        let bedtime = rawTime.map { $0.addingTimeInterval(-Double(settings.sleepGoalMinutes) * 60) }
        let windDown = bedtime.map { $0.addingTimeInterval(-Double(settings.windDownMinutes) * 60) }

        return PlannedDay(
            date: day.date,
            solar: day,
            status: status,
            alarmTime: status == .active ? rawTime : nil,
            wasClamped: clamped,
            bedtime: bedtime,
            windDownTime: windDown
        )
    }

    /// The sun-relative alarm time with the clamp applied. Independent of enable state.
    public static func alarmInstant(
        settings: AlarmSettings,
        day: SolarDay,
        calendar: Calendar = .current
    ) -> (time: Date?, clamped: Bool) {
        let anchorTime = day.time(for: settings.anchor)
        let sunRelative = anchorTime?.addingTimeInterval(Double(settings.offsetMinutes) * 60)

        guard settings.clampEnabled else {
            return (sunRelative, false)
        }

        let earliest = settings.earliest.date(on: day.date, calendar: calendar)
        let latest = settings.latest.date(on: day.date, calendar: calendar)

        guard let sunRelative else {
            // No sun event (polar regions): fall back to the latest allowed time so the
            // user still gets woken.
            return (latest, true)
        }

        if sunRelative < earliest { return (earliest, true) }
        if sunRelative > latest { return (latest, true) }
        return (sunRelative, false)
    }

    /// The next active alarm at or after `now`.
    public static func nextAlarm(in plan: [PlannedDay], after now: Date) -> PlannedDay? {
        plan.first { day in
            guard let t = day.alarmTime, day.isActive else { return false }
            return t > now
        }
    }
}
