import WidgetKit
import SwiftUI
import RiseCore

/// Home Screen and Lock Screen widget: the next alarm and sunrise.
struct NextAlarmWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NextAlarm", provider: NextAlarmProvider()) { entry in
            NextAlarmView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(colors: [WidgetTheme.night, Color(red: 0.16, green: 0.13, blue: 0.32)],
                                   startPoint: .top, endPoint: .bottom)
                }
        }
        .configurationDisplayName("Next Sunrise Alarm")
        .description("Your next alarm and the sunrise it follows.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline, .accessoryCircular])
    }
}

nonisolated struct NextAlarmEntry: TimelineEntry {
    let date: Date
    let alarm: Date?
    let sunrise: Date?
    let bedtime: Date?
    let locationName: String
    let enabled: Bool
    /// The location's zone, so the widget shows the same clock as the app rather than
    /// the phone's when the two differ.
    let timeZone: TimeZone
}

/// WidgetKit calls the provider off the main actor, so opt out of the project's MainActor default.
nonisolated struct NextAlarmProvider: TimelineProvider {
    func placeholder(in context: Context) -> NextAlarmEntry {
        NextAlarmEntry(date: .now, alarm: .now.addingTimeInterval(8 * 3600), sunrise: .now.addingTimeInterval(8.5 * 3600),
                       bedtime: .now.addingTimeInterval(3600), locationName: "Your city", enabled: true,
                       timeZone: .current)
    }

    func getSnapshot(in context: Context, completion: @escaping (NextAlarmEntry) -> Void) {
        completion(entry(at: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NextAlarmEntry>) -> Void) {
        let now = Date.now
        var entries = [entry(at: now)]
        // Roll over right after each alarm so the widget advances without the app.
        let plan = SharedStore.shared.loadPlan()
        for day in plan {
            if let t = day.alarmTime, t > now { entries.append(entry(at: t.addingTimeInterval(60))) }
            if entries.count >= 6 { break }
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func entry(at date: Date) -> NextAlarmEntry {
        let store = SharedStore.shared
        let settings = store.loadSettings()
        let plan = store.loadPlan()
        let next = AlarmPlanner.nextAlarm(in: plan, after: date)
        let tonight = plan.first { ($0.bedtime ?? .distantPast) > date && $0.isActive }
        return NextAlarmEntry(date: date,
                              alarm: next?.alarmTime,
                              sunrise: next?.solar.sunrise,
                              bedtime: tonight?.bedtime,
                              locationName: settings?.location?.name ?? "",
                              enabled: settings?.isEnabled ?? false,
                              timeZone: settings?.timeZone ?? .current)
    }
}

struct NextAlarmView: View {
    @Environment(\.widgetFamily) private var family
    let entry: NextAlarmEntry

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = entry.timeZone
        return calendar
    }

    private func clock(_ date: Date) -> String {
        date.formatted(zoned(.init(date: .omitted, time: .shortened)))
    }

    /// Setting the style's `timeZone` renders the instant in that zone; `.timeZone(_:)`
    /// would merely append a zone symbol.
    private func zoned(_ style: Date.FormatStyle) -> Date.FormatStyle {
        var style = style
        style.timeZone = entry.timeZone
        return style
    }

    private var alarmText: String { entry.alarm.map(clock) ?? "—" }
    private var sunriseText: String { entry.sunrise.map(clock) ?? "—" }
    private var dayText: String {
        guard let a = entry.alarm else { return entry.enabled ? "No alarm set" : "Alarm off" }
        if calendar.isDateInToday(a) { return "Today" }
        if calendar.isDateInTomorrow(a) { return "Tomorrow" }
        return a.formatted(zoned(.dateTime.weekday(.wide)))
    }

    var body: some View {
        switch family {
        case .accessoryInline:
            Label("\(alarmText) · sunrise \(sunriseText)", systemImage: "sunrise")
        case .accessoryCircular:
            VStack(spacing: 0) {
                Image(systemName: "sunrise.fill").font(.caption)
                Text(alarmText).font(.caption2.monospacedDigit()).minimumScaleFactor(0.6)
            }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Label(dayText, systemImage: "alarm").font(.caption2)
                Text(alarmText).font(.title3.monospacedDigit().weight(.semibold))
                Text("Sunrise \(sunriseText)").font(.caption2)
            }
        case .systemMedium:
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(dayText.uppercased()).font(.caption2.weight(.semibold)).tracking(1).foregroundStyle(.secondary)
                    Text(alarmText).font(.system(size: 40, weight: .light, design: .rounded)).monospacedDigit()
                    Label(entry.locationName, systemImage: "location").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 10) {
                    stat("Sunrise", sunriseText, "sunrise.fill")
                    if let b = entry.bedtime { stat("Bedtime", clock(b), "bed.double.fill") }
                }
            }
            .foregroundStyle(.white)
        default: // systemSmall
            VStack(alignment: .leading, spacing: 4) {
                Label(dayText, systemImage: "alarm").font(.caption2).foregroundStyle(.secondary)
                Text(alarmText).font(.system(size: 30, weight: .light, design: .rounded)).monospacedDigit().minimumScaleFactor(0.7)
                Spacer(minLength: 0)
                HStack(spacing: 4) {
                    Image(systemName: "sunrise.fill").foregroundStyle(WidgetTheme.sun)
                    Text(sunriseText).monospacedDigit()
                }
                .font(.caption)
            }
            .foregroundStyle(.white)
        }
    }

    private func stat(_ title: String, _ value: String, _ icon: String) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Label(title, systemImage: icon).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.headline.monospacedDigit())
        }
    }
}
