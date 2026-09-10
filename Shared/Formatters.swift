import Foundation

nonisolated enum Formatters {
    /// Times are rendered in the *location's* zone, never the device's: a sunrise alarm
    /// for Reykjavík reads "5:36 AM" even while the phone is still on Pacific time.
    /// `zone` is deliberately required — a default would let a call site silently fall
    /// back to the device and print a time the user never experiences.
    static func time(_ date: Date, in zone: TimeZone) -> String {
        date.formatted(zoned(.init(date: .omitted, time: .shortened), zone))
    }

    static func weekdayShort(_ date: Date, in zone: TimeZone) -> String {
        date.formatted(zoned(.dateTime.weekday(.abbreviated), zone))
    }

    /// `.timeZone(_:)` on a format style appends a zone *symbol*; setting the property is
    /// what actually renders the instant in that zone.
    private static func zoned(_ style: Date.FormatStyle, _ zone: TimeZone) -> Date.FormatStyle {
        var style = style
        style.timeZone = zone
        return style
    }

    static func dayLabel(_ date: Date, in zone: TimeZone, relativeTo now: Date = .now) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        if calendar.isDate(date, inSameDayAs: now) { return "Today" }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(date, inSameDayAs: tomorrow) {
            return "Tomorrow"
        }
        return date.formatted(zoned(.dateTime.weekday(.wide).month(.abbreviated).day(), zone))
    }

    /// Short label for the zone itself, e.g. "GMT+1" — shown only when the location's zone
    /// differs from the phone's, so the reader knows which clock the times belong to.
    static func zoneAbbreviation(_ zone: TimeZone, at date: Date = .now) -> String {
        zone.localizedName(for: .shortGeneric, locale: .current)
            ?? zone.abbreviation(for: date)
            ?? zone.identifier
    }

    static func duration(minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        switch (h, m) {
        case (0, _): return "\(m) min"
        case (_, 0): return "\(h) hr"
        default: return "\(h) hr \(m) min"
        }
    }

    static func duration(seconds: TimeInterval) -> String {
        duration(minutes: max(0, Int(seconds.rounded()) / 60))
    }

    static func countdown(to date: Date, from now: Date = .now) -> String {
        let seconds = date.timeIntervalSince(now)
        if seconds < 60 { return "less than a minute" }
        return duration(seconds: seconds)
    }

    static func coordinate(_ lat: Double, _ lon: Double) -> String {
        String(format: "%.2f°, %.2f°", lat, lon)
    }

    static func signedOffset(_ minutes: Int) -> String {
        let magnitude = abs(minutes)
        let text = duration(minutes: magnitude)
        if minutes == 0 { return "at" }
        return minutes < 0 ? "\(text) before" : "\(text) after"
    }
}
