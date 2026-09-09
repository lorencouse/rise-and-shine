import Foundation

/// A calendar day with no time or zone, e.g. 2026-09-09. Used as a stable identifier for
/// per-day plans and alarms so that a schedule survives time-zone changes and DST.
public struct DateKey: Hashable, Sendable, Codable, Comparable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public init(date: Date, calendar: Calendar = .current) {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: c.year ?? 1970, month: c.month ?? 1, day: c.day ?? 1)
    }

    /// Parses "yyyy-MM-dd".
    public init?(string: String) {
        let parts = string.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        self.init(year: parts[0], month: parts[1], day: parts[2])
    }

    public var description: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    public func startOfDay(in calendar: Calendar = .current) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
    }

    public func adding(days: Int, in calendar: Calendar = .current) -> DateKey {
        let start = startOfDay(in: calendar)
        let shifted = calendar.date(byAdding: .day, value: days, to: start) ?? start
        return DateKey(date: shifted, calendar: calendar)
    }

    /// 1 = Sunday … 7 = Saturday, matching `Calendar.Component.weekday`.
    public func weekday(in calendar: Calendar = .current) -> Int {
        calendar.component(.weekday, from: startOfDay(in: calendar))
    }

    public static func < (lhs: DateKey, rhs: DateKey) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}
