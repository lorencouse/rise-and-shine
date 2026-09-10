import SwiftUI
import Charts
import RiseCore

/// How alarm, sunrise and sunset move over a week, a month or a year. The week is the real
/// plan (skips, pauses and custom mornings included); the month and year draw the sunrise
/// rule, so the curve is the shape of the year rather than a record of one-off choices.
struct TrendsSheet: View {
    @Environment(AppModel.self) private var model
    @State private var range: TrendRange = .week
    @State private var points: [TrendPoint] = []
    @State private var loading = false

    var body: some View {
        QuickSheet(title: "Trends", detents: [.large]) {
            Picker("Range", selection: $range) {
                ForEach(TrendRange.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)

            Card(isHero: true) {
                if points.isEmpty {
                    ProgressView().frame(maxWidth: .infinity).frame(height: 260)
                } else {
                    TrendChart(range: range, points: points, window: window, timeZone: model.timeZone)
                    legend
                }
            }
            if !points.isEmpty { summary }
            Text(range.caption(location: model.settings.location?.name))
                .font(.caption).foregroundStyle(Theme.faint)
                .fixedSize(horizontal: false, vertical: true)
        }
        .task(id: range) {
            loading = true
            points = await TrendPoint.compute(range: range, settings: model.settings, plan: model.plan)
            loading = false
        }
    }

    private var window: (earliest: Int, latest: Int)? {
        let p = model.settings.baseProfile
        return p.clampEnabled ? (p.earliest.minutes, p.latest.minutes) : nil
    }

    private var legend: some View {
        HStack(spacing: 14) {
            key(color: .white, text: "Alarm")
            key(color: Theme.sunrise, text: "Sunrise")
            key(color: Theme.horizon, text: "Sunset")
            if window != nil { key(color: Theme.moon, text: "Wake window") }
        }
        .font(.caption2).foregroundStyle(Theme.faint)
    }

    private func key(color: Color, text: String) -> some View {
        HStack(spacing: 5) {
            Capsule().fill(color).frame(width: 12, height: 3)
            Text(text)
        }
    }

    private var summary: some View {
        let alarms = points.compactMap(\.alarm)
        let sunrises = points.compactMap(\.sunrise)
        let sunsets = points.compactMap(\.sunset)
        let daylight = points.compactMap(\.daylight)
        return Card(title: "Over this \(range.noun)", systemImage: "arrow.up.and.down") {
            MetricGrid(items: [
                .init(title: "Alarm", value: span(alarms), systemImage: "alarm"),
                .init(title: "Sunrise", value: span(sunrises), systemImage: "sunrise"),
                .init(title: "Sunset", value: span(sunsets), systemImage: "sunset"),
                .init(title: "Daylight", value: daylight.min().flatMap { lo in daylight.max().map { hi in
                    lo == hi ? Formatters.duration(minutes: lo) : "\(Formatters.duration(minutes: lo)) – \(Formatters.duration(minutes: hi))" } } ?? "—",
                      systemImage: "hourglass")
            ])
            if let first = alarms.first, let last = alarms.last, first != last {
                let delta = last - first
                Text("Your alarm ends the \(range.noun) \(Formatters.duration(minutes: abs(delta))) \(delta < 0 ? "earlier" : "later") than it starts it.")
                    .font(.caption).foregroundStyle(Theme.faint)
            } else if let first = sunrises.first, let last = sunrises.last, first != last {
                let delta = last - first
                Text("Sunrise moves \(Formatters.duration(minutes: abs(delta))) \(delta < 0 ? "earlier" : "later") over the \(range.noun).")
                    .font(.caption).foregroundStyle(Theme.faint)
            }
        }
    }

    private func span(_ values: [Int]) -> String {
        guard let lo = values.min(), let hi = values.max() else { return "—" }
        if lo == hi { return TrendPoint.clock(lo) }
        return "\(TrendPoint.clock(lo)) – \(TrendPoint.clock(hi))"
    }
}

nonisolated enum TrendRange: String, CaseIterable, Identifiable {
    case week, month, year
    var id: String { rawValue }

    var title: String {
        switch self {
        case .week: "Week"
        case .month: "Month"
        case .year: "Year"
        }
    }

    var noun: String { rawValue }

    /// Days drawn and where they start relative to today.
    var span: (start: Int, count: Int) {
        switch self {
        case .week: (0, 7)
        case .month: (0, 31)
        case .year: (-30, 365)
        }
    }

    func caption(location: String?) -> String {
        let zone = "Times are in \(location ?? "the location")'s zone."
        switch self {
        case .week: return "The next seven mornings as planned, including skips, pauses and custom times. \(zone)"
        case .month: return "The sunrise rule for every day, weekends included, ignoring one-off changes. \(zone)"
        case .year: return "Weekdays only, sunrise rule, so a weekend rule doesn't turn the line into a sawtooth. \(zone)"
        }
    }
}

/// One day: all values are minutes after that day's local midnight, so the y-axis reads as a clock.
struct TrendPoint: Identifiable, Sendable {
    let date: Date
    let key: DateKey
    let sunrise: Int?
    let sunset: Int?
    let alarm: Int?
    /// Marks a real, scheduled alarm (week view) as opposed to the rule's would-be time.
    let alarmIsPlanned: Bool
    var id: Date { date }

    var daylight: Int? {
        guard let sunrise, let sunset else { return nil }
        return sunset - sunrise
    }

    static func clock(_ minutes: Int) -> String {
        var c = DateComponents(); c.hour = minutes / 60; c.minute = minutes % 60
        let d = Calendar(identifier: .gregorian).date(from: c) ?? .now
        return d.formatted(date: .omitted, time: .shortened)
    }

    static func compute(range: TrendRange, settings: AlarmSettings, plan: [PlannedDay]) async -> [TrendPoint] {
        guard let loc = settings.location else { return [] }
        let zone = settings.timeZone
        let planned = Dictionary(uniqueKeysWithValues: plan.map { ($0.date, $0) })
        return await Task.detached(priority: .userInitiated) {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = zone
            let (startOffset, count) = range.span
            let start = calendar.date(byAdding: .day, value: startOffset, to: .now) ?? .now
            let days = SolarCalculator.solarDays(from: start, count: count, latitude: loc.latitude, longitude: loc.longitude, timeZone: zone)
            var rule = settings
            rule.dayOverrides = [:]
            rule.pausedUntil = nil

            return days.compactMap { day -> TrendPoint? in
                let midnight = day.date.startOfDay(in: calendar)
                func minutes(_ d: Date?) -> Int? { d.map { Int(($0.timeIntervalSince(midnight) / 60).rounded()) } }
                let alarm: Date?
                let isPlanned: Bool
                switch range {
                case .week:
                    // The actual plan; days outside the horizon fall back to the rule.
                    if let p = planned[day.date] { alarm = p.alarmTime; isPlanned = true }
                    else { alarm = AlarmPlanner.plan(settings: settings, day: day, calendar: calendar).alarmTime; isPlanned = true }
                case .month:
                    alarm = AlarmPlanner.alarmInstant(settings: rule, day: day, calendar: calendar).time; isPlanned = false
                case .year:
                    guard !AlarmSettings.weekendWeekdays.contains(day.date.weekday(in: calendar)) else { return nil }
                    alarm = AlarmPlanner.alarmInstant(settings: rule, day: day, calendar: calendar).time; isPlanned = false
                }
                return TrendPoint(date: midnight, key: day.date, sunrise: minutes(day.sunrise), sunset: minutes(day.sunset),
                                  alarm: minutes(alarm), alarmIsPlanned: isPlanned)
            }
        }.value
    }
}

struct TrendChart: View {
    let range: TrendRange
    let points: [TrendPoint]
    let window: (earliest: Int, latest: Int)?
    let timeZone: TimeZone

    var body: some View {
        Chart {
            if let window {
                RectangleMark(yStart: .value("Earliest", window.earliest), yEnd: .value("Latest", window.latest))
                    .foregroundStyle(Theme.moon.opacity(0.10))
                RuleMark(y: .value("Earliest", window.earliest))
                    .foregroundStyle(Theme.moon.opacity(0.5)).lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))
                RuleMark(y: .value("Latest", window.latest))
                    .foregroundStyle(Theme.moon.opacity(0.5)).lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))
            }
            ForEach(points) { p in
                if let s = p.sunset {
                    LineMark(x: .value("Date", p.date), y: .value("Sunset", s), series: .value("Series", "Sunset"))
                        .foregroundStyle(Theme.horizon.opacity(0.9))
                        .interpolationMethod(range == .week ? .linear : .catmullRom)
                    if range == .week {
                        PointMark(x: .value("Date", p.date), y: .value("Sunset", s)).foregroundStyle(Theme.horizon).symbolSize(30)
                    }
                }
                if let s = p.sunrise {
                    LineMark(x: .value("Date", p.date), y: .value("Sunrise", s), series: .value("Series", "Sunrise"))
                        .foregroundStyle(Theme.sunrise.opacity(0.9))
                        .interpolationMethod(range == .week ? .linear : .catmullRom)
                    if range == .week {
                        PointMark(x: .value("Date", p.date), y: .value("Sunrise", s)).foregroundStyle(Theme.sunrise).symbolSize(30)
                    }
                }
                if let a = p.alarm {
                    if range == .week {
                        // Discrete mornings: dots with the time on top; a gap is a day off.
                        PointMark(x: .value("Date", p.date), y: .value("Alarm", a))
                            .foregroundStyle(.white).symbolSize(60)
                            .annotation(position: .top, spacing: 4) {
                                Text(TrendPoint.clock(a)).font(.caption2.monospacedDigit()).foregroundStyle(Theme.mist)
                            }
                    } else {
                        LineMark(x: .value("Date", p.date), y: .value("Alarm", a), series: .value("Series", "Alarm"))
                            .foregroundStyle(.white).lineStyle(StrokeStyle(lineWidth: 2))
                            .interpolationMethod(.catmullRom)
                    }
                }
            }
            if range != .week {
                RuleMark(x: .value("Today", Calendar.current.startOfDay(for: .now)))
                    .foregroundStyle(Theme.sun.opacity(0.7))
                    .annotation(position: .top, alignment: .center) {
                        Text("Today").font(.caption2).foregroundStyle(Theme.sun)
                    }
            }
        }
        .chartYScale(domain: yDomain)
        .chartYAxis {
            AxisMarks(position: .leading, values: Array(stride(from: yDomain.lowerBound, through: yDomain.upperBound, by: yStride))) { value in
                AxisGridLine().foregroundStyle(.white.opacity(0.08))
                AxisValueLabel {
                    if let m = value.as(Int.self) { Text(TrendPoint.clock(m)).font(.caption2).foregroundStyle(Theme.faint) }
                }
            }
        }
        .chartXAxis {
            switch range {
            case .week:
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated), centered: false).foregroundStyle(Theme.faint)
                }
            case .month:
                AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                    AxisGridLine().foregroundStyle(.white.opacity(0.08))
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day()).foregroundStyle(Theme.faint)
                }
            case .year:
                AxisMarks(values: .stride(by: .month, count: 2)) { _ in
                    AxisGridLine().foregroundStyle(.white.opacity(0.08))
                    AxisValueLabel(format: .dateTime.month(.narrow)).foregroundStyle(Theme.faint)
                }
            }
        }
        .frame(height: 280)
        .accessibilityLabel("Chart of alarm, sunrise and sunset over the \(range.noun)")
    }

    /// Whole hours bracketing every series and the window. Sunset pushes the range to
    /// ~14 h, so the axis strides by two hours once it gets that tall.
    private var yDomain: ClosedRange<Int> {
        var values = points.flatMap { [$0.sunrise, $0.sunset, $0.alarm].compactMap { $0 } }
        if let window { values += [window.earliest, window.latest] }
        let lo = ((values.min() ?? 300) / 60 - 1) * 60
        let hi = ((values.max() ?? 1200) / 60 + 1) * 60
        return max(lo, 0)...min(hi, 1440)
    }

    private var yStride: Int { (yDomain.upperBound - yDomain.lowerBound) > 600 ? 120 : 60 }
}
