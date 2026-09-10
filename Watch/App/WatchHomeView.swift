import SwiftUI
import RiseCore

struct WatchHomeView: View {
    @Environment(WatchModel.self) private var model

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if !model.hasSettings {
                        waiting
                    } else {
                        hero
                        if let today = model.today { light(today) }
                        actions
                        upcoming
                    }
                }
                .padding(.horizontal, 4)
            }
            .navigationTitle("Sunrise")
        }
    }

    private var waiting: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Waiting for iPhone", systemImage: "iphone.radiowaves.left.and.right")
                .font(.headline)
            Text("Open Rise and Shine on your iPhone once and your alarm appears here.")
                .font(.footnote).foregroundStyle(WatchTheme.faint)
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(model.settings.isEnabled ? "NEXT ALARM" : "ALARM OFF")
                .font(.caption2.weight(.semibold)).tracking(1)
                .foregroundStyle(model.settings.isEnabled ? WatchTheme.faint : WatchTheme.sunrise)
            if let next = model.nextAlarm, let t = next.alarmTime {
                Text(Formatters.time(t, in: model.timeZone))
                    .font(.system(size: 40, weight: .light, design: .rounded))
                    .monospacedDigit().minimumScaleFactor(0.6).lineLimit(1)
                HStack(spacing: 4) {
                    Text(Formatters.dayLabel(t, in: model.timeZone))
                    if let s = next.solar.sunrise {
                        Text("·").foregroundStyle(WatchTheme.faint)
                        Label(Formatters.time(s, in: model.timeZone), systemImage: "sunrise.fill")
                            .foregroundStyle(WatchTheme.sun)
                    }
                }
                .font(.footnote)
                if next.wasClamped {
                    Label("Held in wake window", systemImage: "arrow.left.and.right.square")
                        .font(.caption2).foregroundStyle(WatchTheme.sun)
                }
            } else {
                Text(model.settings.isEnabled ? "Nothing scheduled" : "Off")
                    .font(.title3.weight(.light))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.white.opacity(0.10), in: .rect(cornerRadius: 14))
    }

    /// Two figures side by side is all a 40 mm screen holds legibly, so daylight gets its
    /// own line underneath. The icon *is* the label; VoiceOver gets the name.
    private func light(_ day: PlannedDay) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 6) {
                stat("Sunrise", day.solar.sunrise.map { Formatters.time($0, in: model.timeZone) }, "sunrise.fill", WatchTheme.sun)
                stat("Sunset", day.solar.sunset.map { Formatters.time($0, in: model.timeZone) }, "sunset.fill", WatchTheme.sunrise)
            }
            if let length = day.solar.dayLength {
                Label("\(Formatters.duration(seconds: length)) of daylight", systemImage: "hourglass")
                    .font(.caption2)
                    .foregroundStyle(WatchTheme.faint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(.vertical, 2)
    }

    private func stat(_ title: String, _ value: String?, _ icon: String, _ tint: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(tint)
            Text(value ?? "—")
                .font(.caption2.monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) \(value ?? "unknown")")
    }

    private var actions: some View {
        VStack(spacing: 6) {
            if let next = model.nextAlarm, next.alarmTime != nil {
                Button {
                    model.skipNext()
                } label: {
                    Label("Skip \(Formatters.dayLabel(next.date.startOfDay(in: model.settings.calendar), in: model.timeZone).lowercased())", systemImage: "forward.end")
                }
                .disabled(model.pendingAction)
            }
            Toggle(isOn: Binding(get: { model.settings.isEnabled }, set: { model.setEnabled($0) })) {
                Label("Sunrise alarm", systemImage: "alarm")
            }
            .toggleStyle(.switch)
            .disabled(model.pendingAction)
            if let error = model.lastError {
                Text(error).font(.caption2).foregroundStyle(WatchTheme.faint)
            } else if !model.isReachable {
                Label("iPhone not reachable", systemImage: "iphone.slash")
                    .font(.caption2).foregroundStyle(WatchTheme.faint)
            }
        }
    }

    private var upcoming: some View {
        let days = model.plan.filter { $0.date >= DateKey(date: .now, calendar: model.settings.calendar) }.prefix(7)
        return VStack(alignment: .leading, spacing: 4) {
            Text("NEXT 7 DAYS").font(.caption2.weight(.semibold)).tracking(1).foregroundStyle(WatchTheme.faint)
            ForEach(Array(days)) { day in
                HStack {
                    Text(Formatters.weekdayShort(day.date.startOfDay(in: model.settings.calendar), in: model.timeZone))
                        .frame(width: 34, alignment: .leading)
                    Spacer()
                    switch day.status {
                    case .active: Text(day.alarmTime.map { Formatters.time($0, in: model.timeZone) } ?? "—").monospacedDigit()
                    case .skipped: Text("Skipped").foregroundStyle(WatchTheme.sun)
                    case .paused: Text("Paused").foregroundStyle(WatchTheme.faint)
                    case .weekdayOff, .disabled, .noSunEvent: Text("Off").foregroundStyle(WatchTheme.faint)
                    }
                }
                .font(.footnote)
                .opacity(day.isActive ? 1 : 0.6)
            }
        }
        .padding(.top, 4)
    }
}
