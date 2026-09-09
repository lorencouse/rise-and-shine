import Foundation

nonisolated enum Formatters {
    static func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    static func weekdayShort(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated))
    }

    static func dayLabel(_ date: Date, relativeTo now: Date = .now, calendar: Calendar = .current) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "Today" }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(date, inSameDayAs: tomorrow) {
            return "Tomorrow"
        }
        return date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
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
