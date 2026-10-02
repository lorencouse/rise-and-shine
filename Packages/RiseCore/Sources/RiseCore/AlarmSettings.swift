import Foundation

/// A saved place. Coordinates drive the solar math; the name is only for display.
public struct SavedLocation: Sendable, Codable, Equatable, Hashable {
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

    /// Great-circle distance to another place, in metres (haversine, spherical Earth).
    public func distance(to other: SavedLocation) -> Double {
        let r = 6_371_000.0
        let φ1 = latitude * .pi / 180, φ2 = other.latitude * .pi / 180
        let dφ = (other.latitude - latitude) * .pi / 180
        let dλ = (other.longitude - longitude) * .pi / 180
        let a = sin(dφ / 2) * sin(dφ / 2) + cos(φ1) * cos(φ2) * sin(dλ / 2) * sin(dλ / 2)
        return 2 * r * atan2(sqrt(a), sqrt(1 - a))
    }

    /// Whether a fresh device fix is different enough to replace `self`. Every fix moves
    /// by a few metres and the reverse-geocoded name can flicker, so adopting each one
    /// would rewrite settings and resync alarms on every launch for no change in sunrise.
    public func isMeaningfullyDifferent(from fresh: SavedLocation, thresholdMetres: Double = 1_000) -> Bool {
        if followsDevice != fresh.followsDevice { return true }
        if let a = timeZoneIdentifier, let b = fresh.timeZoneIdentifier, a != b { return true }
        if timeZoneIdentifier == nil, fresh.timeZoneIdentifier != nil { return true }
        return distance(to: fresh) > thresholdMetres
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
    ///
    /// Set by wall clock, not by adding minutes to midnight: on a DST transition day the
    /// two differ by an hour, and "no earlier than 5:30" has to mean 5:30 on the clock.
    public func date(on key: DateKey, calendar: Calendar = .current) -> Date {
        let start = key.startOfDay(in: calendar)
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: start)
            ?? calendar.date(byAdding: .minute, value: minutes, to: start)
            ?? start
    }
}

/// The sun-relative rule that produces an alarm: anchor, offset and wake window. The main
/// settings carry one of these inline (for compatibility with saved files); an optional
/// second one applies on weekends.
public struct WakeProfile: Sendable, Codable, Equatable {
    public var anchor: SunAnchor = .sunrise
    public var offsetMinutes: Int = -30
    public var clampEnabled: Bool = true
    public var earliest: ClockTime = ClockTime(hour: 5, minute: 30)
    public var latest: ClockTime = ClockTime(hour: 8, minute: 0)

    public init(anchor: SunAnchor = .sunrise, offsetMinutes: Int = -30, clampEnabled: Bool = true,
                earliest: ClockTime = ClockTime(hour: 5, minute: 30), latest: ClockTime = ClockTime(hour: 8, minute: 0)) {
        self.anchor = anchor
        self.offsetMinutes = offsetMinutes
        self.clampEnabled = clampEnabled
        self.earliest = earliest
        self.latest = latest
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

    /// Mornings that ring at a fixed clock time instead of following the sun (an early
    /// flight). An override wins over the weekday list and a pause; a skip wins over it.
    public var dayOverrides: [DateKey: ClockTime] = [:]

    /// Vacation mode: no alarms on days before this date. `nil` when not paused.
    public var pausedUntil: DateKey? = nil

    /// A different rule for Saturday and Sunday. `nil` means weekends use the main rule.
    public var weekendProfile: WakeProfile? = nil

    /// Snooze duration for the alarm's secondary button.
    public var snoozeMinutes: Int = 9

    /// Minutes of Live Activity countdown shown before the alarm rings ("sunrise in 18 min").
    /// 0 turns it off.
    public var preAlarmMinutes: Int = 0

    /// Places the user has picked before, most recent first, for one-tap switching.
    public var savedPlaces: [SavedLocation] = []

    /// Minutes of gradual screen sunrise before the alarm, shown in nightstand mode.
    /// 0 turns it off. Independent of `preAlarmMinutes`, which is the Live Activity.
    public var sunriseGlowMinutes: Int = 0

    /// How bright the glow gets at the alarm, 0...1.
    public var sunriseGlowMaxBrightness: Double = 0.85

    /// Enter nightstand mode by itself when the phone is charging with the app open.
    public var nightstandAutoEnabled: Bool = true

    /// Screen brightness held by nightstand mode outside the glow ramp.
    public var nightstandBrightness: Double = 0.12

    /// Mirror each planned night (bedtime → alarm) into the user's calendar.
    public var calendarEventsEnabled: Bool = false

    /// Read sleep analysis from Health to show actual sleep against the goal.
    public var healthSleepEnabled: Bool = false

    /// Sleep goal used to derive bedtime.
    public var sleepGoalMinutes: Int = 8 * 60

    /// How long before bedtime the wind-down reminder fires.
    public var windDownMinutes: Int = 30

    /// Whether to post wind-down and bedtime reminders (regular notifications).
    public var remindersEnabled: Bool = true

    /// File name (with extension) of the bundled alarm sound.
    public var soundFile: String = "Phone Chime 1.caf"

    /// How many days ahead to keep system alarms scheduled.
    public var horizonDays: Int = 14

    public var location: SavedLocation? = nil

    public var onboardingCompleted: Bool = false

    public init() {}

    /// Every key is optional *and* fault-tolerant on the way in. Fields added after a
    /// release are missing from files already on users' phones, and a field whose shape
    /// changed would otherwise throw — either way the decode would fail, the app would see
    /// no settings and drop the user back into onboarding with their alarms cancelled.
    /// A bad field falls back to its default; the rest of the file survives.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AlarmSettings()

        func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
            ((try? c.decodeIfPresent(T.self, forKey: key)) ?? nil) ?? fallback
        }
        func optional<T: Decodable>(_ key: CodingKeys, _ type: T.Type) -> T? {
            (try? c.decodeIfPresent(T.self, forKey: key)) ?? nil
        }

        version = value(.version, d.version)
        isEnabled = value(.isEnabled, d.isEnabled)
        anchor = value(.anchor, d.anchor)
        offsetMinutes = value(.offsetMinutes, d.offsetMinutes)
        clampEnabled = value(.clampEnabled, d.clampEnabled)
        earliest = value(.earliest, d.earliest)
        latest = value(.latest, d.latest)
        activeWeekdays = value(.activeWeekdays, d.activeWeekdays)
        skippedDays = value(.skippedDays, d.skippedDays)
        dayOverrides = value(.dayOverrides, d.dayOverrides)
        pausedUntil = optional(.pausedUntil, DateKey.self)
        weekendProfile = optional(.weekendProfile, WakeProfile.self)
        snoozeMinutes = value(.snoozeMinutes, d.snoozeMinutes)
        preAlarmMinutes = value(.preAlarmMinutes, d.preAlarmMinutes)
        savedPlaces = value(.savedPlaces, d.savedPlaces)
        sunriseGlowMinutes = value(.sunriseGlowMinutes, d.sunriseGlowMinutes)
        sunriseGlowMaxBrightness = value(.sunriseGlowMaxBrightness, d.sunriseGlowMaxBrightness)
        nightstandAutoEnabled = value(.nightstandAutoEnabled, d.nightstandAutoEnabled)
        nightstandBrightness = value(.nightstandBrightness, d.nightstandBrightness)
        calendarEventsEnabled = value(.calendarEventsEnabled, d.calendarEventsEnabled)
        healthSleepEnabled = value(.healthSleepEnabled, d.healthSleepEnabled)
        sleepGoalMinutes = value(.sleepGoalMinutes, d.sleepGoalMinutes)
        windDownMinutes = value(.windDownMinutes, d.windDownMinutes)
        remindersEnabled = value(.remindersEnabled, d.remindersEnabled)
        soundFile = value(.soundFile, d.soundFile)
        horizonDays = value(.horizonDays, d.horizonDays)
        location = optional(.location, SavedLocation.self)
        onboardingCompleted = value(.onboardingCompleted, d.onboardingCompleted)
    }

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
    public var offsetDescription: String { baseProfile.offsetDescription }

    /// The main rule, assembled from the inline fields.
    public var baseProfile: WakeProfile {
        get { WakeProfile(anchor: anchor, offsetMinutes: offsetMinutes, clampEnabled: clampEnabled, earliest: earliest, latest: latest) }
        set {
            anchor = newValue.anchor
            offsetMinutes = newValue.offsetMinutes
            clampEnabled = newValue.clampEnabled
            earliest = newValue.earliest
            latest = newValue.latest
        }
    }

    /// Saturday and Sunday in `Calendar.Component.weekday` numbering.
    public static let weekendWeekdays: Set<Int> = [1, 7]

    /// The rule that applies to a given day.
    public func profile(for day: DateKey, calendar: Calendar) -> WakeProfile {
        if let weekendProfile, Self.weekendWeekdays.contains(day.weekday(in: calendar)) {
            return weekendProfile
        }
        return baseProfile
    }

    /// Remember a place, newest first, without duplicates (same spot within ~1 km), capped.
    public mutating func remember(_ place: SavedLocation, limit: Int = 8) {
        var fixed = place
        fixed.followsDevice = false
        savedPlaces.removeAll { $0.distance(to: fixed) < 1_000 }
        savedPlaces.insert(fixed, at: 0)
        if savedPlaces.count > limit { savedPlaces.removeLast(savedPlaces.count - limit) }
    }

    /// True when `day` falls inside a pause.
    public func isPaused(_ day: DateKey) -> Bool {
        guard let pausedUntil else { return false }
        return day < pausedUntil
    }
}
