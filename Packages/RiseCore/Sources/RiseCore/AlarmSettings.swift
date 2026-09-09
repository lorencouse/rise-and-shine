import Foundation

/// A saved place. Coordinates drive the solar math; the name is only for display.
public struct SavedLocation: Sendable, Codable, Equatable {
    public var name: String
    public var latitude: Double
    public var longitude: Double
    /// When true the app refreshes coordinates from Core Location on each launch.
    public var followsDevice: Bool
    /// The place's own zone, e.g. "Atlantic/Reykjavik". Optional because locations saved
    /// before this existed decode without it; `timeZone` falls back to the device's.
    public var timeZoneIdentifier: String?

    public init(name: String, latitude: Double, longitude: Double, followsDevice: Bool,
                timeZoneIdentifier: String? = nil) {
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.followsDevice = followsDevice
        self.timeZoneIdentifier = timeZoneIdentifier
    }

    /// The zone sun events and wake windows are reckoned in. "Sunrise" and "no earlier
    /// than 5:30" are statements about the place, not about wherever the phone is.
    public var timeZone: TimeZone {
        timeZoneIdentifier.flatMap(TimeZone.init(identifier:)) ?? .current
    }
}

/// Minutes after midnight, 0..<1440. Used for the earliest/latest clamp.
public struct ClockTime: Sendable, Codable, Equatable, Comparable, Hashable {
    public var minutes: Int

    public init(minutes: Int) {
        self.minutes = ((minutes % 1440) + 1440) % 1440
    }

    public init(hour: Int, minute: Int) {
        self.init(minutes: hour * 60 + minute)
    }

    public var hour: Int { minutes / 60 }
    public var minute: Int { minutes % 60 }

    public static func < (lhs: ClockTime, rhs: ClockTime) -> Bool { lhs.minutes < rhs.minutes }

    /// The instant at this clock time on the given day.
    public func date(on key: DateKey, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .minute, value: minutes, to: key.startOfDay(in: calendar)) ?? key.startOfDay(in: calendar)
    }
}

/// Everything the user controls. Stored as JSON in the shared App Group container so the
/// widget extension can read it too.
public struct AlarmSettings: Sendable, Codable, Equatable {
    public static let currentVersion = 1

    public var version: Int = AlarmSettings.currentVersion

    /// Master switch for the sunrise alarm.
    public var isEnabled: Bool = true

    /// Which morning moment the offset is relative to.
    public var anchor: SunAnchor = .sunrise

    /// Signed offset in minutes from the anchor. Negative = before the anchor.
    public var offsetMinutes: Int = -30

    /// Keep the alarm inside a window regardless of where the sun is. Essential at
    /// higher latitudes where sunrise swings between ~4 am and ~9 am across the year.
    public var clampEnabled: Bool = true
    public var earliest: ClockTime = ClockTime(hour: 5, minute: 30)
    public var latest: ClockTime = ClockTime(hour: 8, minute: 0)

    /// Weekdays the alarm fires. 1 = Sunday … 7 = Saturday (Calendar weekday numbering).
    public var activeWeekdays: Set<Int> = [2, 3, 4, 5, 6]

    /// One-off days the user has asked to skip.
    public var skippedDays: Set<DateKey> = []

    /// Snooze duration for the alarm's secondary button.
    public var snoozeMinutes: Int = 9

    /// Sleep goal used to derive bedtime.
    public var sleepGoalMinutes: Int = 8 * 60

    /// How long before bedtime the wind-down reminder fires.
    public var windDownMinutes: Int = 30

    /// Whether to post wind-down and bedtime reminders (regular notifications).
    public var remindersEnabled: Bool = true

    /// File name (with extension) of the bundled alarm sound.
    public var soundFile: String = "Phone Chime 1.mp3"

    /// How many days ahead to keep system alarms scheduled.
    public var horizonDays: Int = 14

    public var location: SavedLocation? = nil

    public var onboardingCompleted: Bool = false

    public init() {}

    /// The zone every time in the plan is computed and displayed in.
    public var timeZone: TimeZone { location?.timeZone ?? .current }

    /// A calendar in the location's zone. Day boundaries, the active-weekday check and the
    /// wake-window clamp all have to agree with the place the sun is rising over.
    public var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    /// The offset as a human phrase, e.g. "30 min before sunrise".
    public var offsetDescription: String {
        let magnitude = abs(offsetMinutes)
        let hours = magnitude / 60
        let mins = magnitude % 60
        var parts: [String] = []
        if hours > 0 { parts.append("\(hours) hr") }
        if mins > 0 || hours == 0 { parts.append("\(mins) min") }
        let amount = parts.joined(separator: " ")
        let anchorName = anchor.title.lowercased()
        if offsetMinutes == 0 { return "At \(anchorName)" }
        return "\(amount) \(offsetMinutes < 0 ? "before" : "after") \(anchorName)"
    }
}
