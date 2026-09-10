import WidgetKit
import SwiftUI
import RiseCore

@main
struct RiseAndShineWatchWidgets: WidgetBundle {
    var body: some Widget {
        WatchNextAlarmWidget()
    }
}

/// Next alarm and sunrise as a watch complication. Reads the settings the watch app saved
/// and does the solar math itself, so it stays right even if the app hasn't run today.
struct WatchNextAlarmWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WatchNextAlarm", provider: Provider()) { entry in
            WatchNextAlarmView(entry: entry)
                .containerBackground(for: .widget) { Color.black }
        }
        .configurationDisplayName("Sunrise Alarm")
        .description("Your next alarm and the sunrise it follows.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }

    nonisolated struct Entry: TimelineEntry {
        let date: Date
        let alarm: Date?
        let sunrise: Date?
        let enabled: Bool
        let timeZone: TimeZone
    }

    nonisolated struct Provider: TimelineProvider {
        func placeholder(in context: Context) -> Entry {
            Entry(date: .now, alarm: .now.addingTimeInterval(8 * 3600), sunrise: .now.addingTimeInterval(8.5 * 3600), enabled: true, timeZone: .current)
        }
        func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) { completion(entry(at: .now)) }
        func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
            let now = Date.now
            var entries = [entry(at: now)]
            for day in plan(from: now) {
                if let t = day.alarmTime, t > now { entries.append(entry(at: t.addingTimeInterval(60))) }
                if entries.count >= 6 { break }
            }
            completion(Timeline(entries: entries, policy: .atEnd))
        }

        private func plan(from date: Date) -> [PlannedDay] {
            guard let settings = SharedStore.shared.loadSettings(), let loc = settings.location else { return [] }
            let days = SolarCalculator.solarDays(from: date, count: 8, latitude: loc.latitude, longitude: loc.longitude, timeZone: settings.timeZone)
            return AlarmPlanner.plan(settings: settings, days: days, calendar: settings.calendar)
        }

        private func entry(at date: Date) -> Entry {
            let settings = SharedStore.shared.loadSettings()
            let next = AlarmPlanner.nextAlarm(in: plan(from: date), after: date)
            return Entry(date: date, alarm: next?.alarmTime, sunrise: next?.solar.sunrise,
                         enabled: settings?.isEnabled ?? false, timeZone: settings?.timeZone ?? .current)
        }
    }
}

struct WatchNextAlarmView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WatchNextAlarmWidget.Entry

    private var alarmText: String { entry.alarm.map { Formatters.time($0, in: entry.timeZone) } ?? (entry.enabled ? "—" : "Off") }
    private var sunriseText: String { entry.sunrise.map { Formatters.time($0, in: entry.timeZone) } ?? "—" }

    var body: some View {
        switch family {
        case .accessoryInline:
            Label("\(alarmText) · ☀︎ \(sunriseText)", systemImage: "alarm")
        case .accessoryCorner:
            Text(alarmText).font(.caption.monospacedDigit()).minimumScaleFactor(0.6)
                .widgetLabel { Label("Sunrise \(sunriseText)", systemImage: "sunrise.fill") }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Label(entry.alarm.map { Formatters.dayLabel($0, in: entry.timeZone) } ?? "No alarm", systemImage: "alarm").font(.caption2)
                Text(alarmText).font(.title3.monospacedDigit().weight(.semibold))
                Label("Sunrise \(sunriseText)", systemImage: "sunrise.fill").font(.caption2)
            }
        default:
            VStack(spacing: 0) {
                Image(systemName: "sunrise.fill").font(.caption)
                Text(alarmText).font(.caption2.monospacedDigit()).minimumScaleFactor(0.6)
            }
        }
    }
}
