import SwiftUI
import RiseCore

/// The sheets Home can present. Routing them through one enum keeps the presentation
/// state on Home to a single `@State` and makes every entry point explicit.
enum HomeSheet: Identifiable, Hashable {
    case wakeTime
    case days
    case sleep
    case settings
    case trends
    /// Pin one morning to a fixed clock time.
    case customTime(DateKey)

    var id: String {
        switch self {
        case .wakeTime: "wakeTime"
        case .days: "days"
        case .sleep: "sleep"
        case .settings: "settings"
        case .trends: "trends"
        case .customTime(let key): "customTime-\(key)"
        }
    }
}

// MARK: - Shared chrome

/// Common wrapper: dark background, inline title, a Done button. Sheets are for quick
/// edits, so they open at `.medium` and can be dragged up when a picker needs room.
struct QuickSheet<Content: View>: View {
    let title: String
    var detents: Set<PresentationDetent> = [.medium, .large]
    @ViewBuilder var content: Content

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.night.ignoresSafeArea()
                Theme.skyGradient.opacity(0.4).ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: Metrics.sectionGap) {
                        content
                    }
                    .padding(.horizontal, Metrics.screenPadding)
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
        .presentationDetents(detents)
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.night)
    }
}

/// "Tomorrow 6:12 AM" — the answer to the only question the user actually has while
/// dragging a picker. Every quick-edit sheet carries one.
private struct PreviewStrip: View {
    @Environment(AppModel.self) private var model
    var settings: AlarmSettings
    @ScaledMetric(relativeTo: .title) private var bigSize: CGFloat = 32

    private var tomorrow: Date {
        settings.calendar.date(byAdding: .day, value: 1, to: .now) ?? .now
    }

    var body: some View {
        let plan = model.preview(settings, on: tomorrow)
        // Show the time even on a day the alarm is off (weekday not selected, say), so
        // dragging a picker always moves a number instead of showing a dash.
        let alarmTime = plan.flatMap { AlarmPlanner.alarmInstant(settings: settings, day: $0.solar).time }
        Card(isHero: true) {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("TOMORROW'S ALARM")
                        .font(.eyebrow).tracking(1.2).foregroundStyle(Theme.faint)
                    Text(alarmTime.map { Formatters.time($0, in: settings.timeZone) } ?? "—")
                        .font(.bigTime(bigSize))
                        .foregroundStyle(Theme.sun)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
                Spacer(minLength: 0)
                if let solar = plan?.solar, let anchorTime = solar.time(for: settings.anchor) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(settings.anchor.title.uppercased())
                            .font(.eyebrow).tracking(1.2).foregroundStyle(Theme.faint)
                        Text(Formatters.time(anchorTime, in: settings.timeZone))
                            .font(.system(.title3, design: .rounded).weight(.medium))
                            .foregroundStyle(Theme.mist)
                            .monospacedDigit()
                    }
                }
            }
            if plan?.wasClamped == true {
                Label("Held inside your wake window", systemImage: "arrow.left.and.right.square")
                    .font(.caption).foregroundStyle(Theme.sun)
            }
        }
        .animation(Motion.card, value: alarmTime)
    }
}

// MARK: - Wake time

/// The app's central setting. Reachable in one tap from the Home hero.
struct WakeTimeSheet: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        QuickSheet(title: "Wake time", detents: [.large]) {
            PreviewStrip(settings: model.settings)

            Card(title: "Relative to", systemImage: "sun.horizon") {
                Picker("Relative to", selection: $model.settings.anchor) {
                    ForEach(SunAnchor.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Text(model.settings.anchor.detail)
                    .font(.footnote)
                    .foregroundStyle(Theme.mist)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Card(title: "Offset", systemImage: "arrow.up.and.down") {
                OffsetPicker(offsetMinutes: $model.settings.offsetMinutes,
                             anchorTitle: model.settings.anchor.title)
            }

            Card(title: "Wake window", systemImage: "arrow.left.and.right.square") {
                Toggle("Keep the alarm inside a window", isOn: $model.settings.clampEnabled)
                    .font(.system(.subheadline, design: .rounded))
                if model.settings.clampEnabled {
                    ClockTimeRow(title: "No earlier than", time: $model.settings.earliest)
                    ClockTimeRow(title: "No later than", time: $model.settings.latest)
                }
                Text("Sunrise drifts by hours across the year. The window stops the alarm ringing at 4:30 in June or 8:30 in December.")
                    .font(.caption)
                    .foregroundStyle(Theme.faint)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .animation(Motion.card, value: model.settings.clampEnabled)

            Card(title: "Snooze", systemImage: "zzz") {
                Stepper("\(model.settings.snoozeMinutes) minutes", value: $model.settings.snoozeMinutes, in: 1...30)
                    .font(.system(.subheadline, design: .rounded))
            }

            Card(title: "Countdown before the alarm", systemImage: "timer") {
                Picker("Countdown", selection: $model.settings.preAlarmMinutes) {
                    Text("Off").tag(0)
                    Text("10 min").tag(10)
                    Text("20 min").tag(20)
                    Text("30 min").tag(30)
                    Text("1 hr").tag(60)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("sheet.countdown")
                Text("Shows \"sunrise soon\" with a live countdown on the Lock Screen and in the Dynamic Island before the alarm rings. Silent until the alarm itself.")
                    .font(.caption).foregroundStyle(Theme.faint)
                    .fixedSize(horizontal: false, vertical: true)
            }

            WeekendCard()
        }
    }
}

/// Saturday and Sunday can follow their own rule. Off by default, since one rule for every
/// day is the app's whole pitch; on, it reveals a second copy of the same controls.
private struct WeekendCard: View {
    @Environment(AppModel.self) private var model

    private var isOn: Binding<Bool> {
        Binding(
            get: { model.settings.weekendProfile != nil },
            set: { on in
                // Start the weekend rule from the weekday one, nudged later: that's what
                // nearly everyone wants, and it makes the change visible immediately.
                model.settings.weekendProfile = on ? {
                    var p = model.settings.baseProfile
                    p.offsetMinutes += 60
                    return p
                }() : nil
            }
        )
    }

    private var profile: Binding<WakeProfile> {
        Binding(
            get: { model.settings.weekendProfile ?? model.settings.baseProfile },
            set: { model.settings.weekendProfile = $0 }
        )
    }

    var body: some View {
        Card(title: "Weekends", systemImage: "calendar.badge.clock") {
            Toggle("Different rule on Saturday and Sunday", isOn: isOn)
                .font(.system(.subheadline, design: .rounded))
            if model.settings.weekendProfile != nil {
                Picker("Relative to", selection: profile.anchor) {
                    ForEach(SunAnchor.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                OffsetPicker(offsetMinutes: profile.offsetMinutes, anchorTitle: profile.wrappedValue.anchor.title)
                Toggle("Keep inside a window", isOn: profile.clampEnabled)
                    .font(.system(.subheadline, design: .rounded))
                if profile.wrappedValue.clampEnabled {
                    ClockTimeRow(title: "No earlier than", time: profile.earliest)
                    ClockTimeRow(title: "No later than", time: profile.latest)
                }
            } else {
                Text("Weekends use the same rule as weekdays.")
                    .font(.caption).foregroundStyle(Theme.faint)
            }
        }
        .animation(Motion.card, value: model.settings.weekendProfile != nil)
        .animation(Motion.card, value: model.settings.weekendProfile?.clampEnabled)
    }
}

// MARK: - Days

struct DaysSheet: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        QuickSheet(title: "Days", detents: [.medium, .large]) {
            Card(title: "Alarm rings on", systemImage: "calendar") {
                WeekdayPicker(selection: $model.settings.activeWeekdays)
                HStack(spacing: 8) {
                    presetButton("Weekdays", days: [2, 3, 4, 5, 6])
                    presetButton("Every day", days: Set(1...7))
                    presetButton("Weekends", days: [1, 7])
                }
                if model.settings.activeWeekdays.isEmpty {
                    Label("No days selected — the alarm will never ring.", systemImage: "exclamationmark.triangle")
                        .font(.caption).foregroundStyle(Theme.horizon)
                }
            }

            PauseCard()

            Card(title: "Custom mornings", systemImage: "pin") {
                if model.overriddenUpcoming.isEmpty {
                    Text("None. Touch and hold a morning on the home screen to give it a fixed time, for an early flight or a late start.")
                        .font(.footnote).foregroundStyle(Theme.faint)
                } else {
                    ForEach(model.overriddenUpcoming) { day in
                        HStack {
                            Text(Formatters.dayLabel(day.date.startOfDay(in: model.settings.calendar), in: model.timeZone))
                                .font(.system(.subheadline, design: .rounded))
                            Spacer()
                            Text(day.alarmTime.map { Formatters.time($0, in: model.timeZone) } ?? "—")
                                .font(.system(.subheadline, design: .rounded)).monospacedDigit()
                                .foregroundStyle(Theme.mist)
                            Button("Clear") { model.clearOverride(day.date) }
                                .font(.footnote.weight(.semibold))
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            Card(title: "Skipped days", systemImage: "forward.end") {
                if model.skippedUpcoming.isEmpty {
                    Text("Nothing skipped. Use the skip button beside a day on the home screen to sit one morning out.")
                        .font(.footnote).foregroundStyle(Theme.faint)
                } else {
                    ForEach(model.skippedUpcoming) { day in
                        HStack {
                            Text(Formatters.dayLabel(day.date.startOfDay(in: model.settings.calendar), in: model.timeZone))
                                .font(.system(.subheadline, design: .rounded))
                            Spacer()
                            Button("Restore") { model.toggleSkip(day) }
                                .font(.footnote.weight(.semibold))
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
    }

    private func presetButton(_ title: String, days: Set<Int>) -> some View {
        @Bindable var model = model
        let isOn = model.settings.activeWeekdays == days
        return Button {
            Haptics.selection()
            withAnimation(Motion.quick) { model.settings.activeWeekdays = days }
        } label: {
            Text(title)
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(isOn ? Theme.sunrise.opacity(0.9) : Theme.card, in: .capsule)
                .foregroundStyle(isOn ? Theme.night : Theme.mist)
        }
        .buttonStyle(.plain)
    }
}

/// Vacation mode. A date rather than a toggle, because an alarm that stays off after the
/// holiday is exactly the failure this app exists to prevent.
private struct PauseCard: View {
    @Environment(AppModel.self) private var model

    private var isPaused: Binding<Bool> {
        Binding(
            get: { model.settings.pausedUntil != nil },
            set: { on in
                model.settings.pausedUntil = on
                    ? DateKey(date: .now, calendar: model.settings.calendar).adding(days: 7, in: model.settings.calendar)
                    : nil
            }
        )
    }

    /// The picker works in Dates; settings hold a DateKey. Convert in the location's
    /// calendar so the day shown is the day that resumes there.
    private var resumeDate: Binding<Date> {
        Binding(
            get: { (model.settings.pausedUntil ?? DateKey(date: .now, calendar: model.settings.calendar)).startOfDay(in: model.settings.calendar) },
            set: { model.settings.pausedUntil = DateKey(date: $0, calendar: model.settings.calendar) }
        )
    }

    private var tomorrow: Date {
        DateKey(date: .now, calendar: model.settings.calendar).adding(days: 1, in: model.settings.calendar)
            .startOfDay(in: model.settings.calendar)
    }

    var body: some View {
        Card(title: "Pause", systemImage: "pause.circle") {
            Toggle("Pause alarms until a date", isOn: isPaused)
                .font(.system(.subheadline, design: .rounded))
            if let until = model.settings.pausedUntil {
                DatePicker("Resume on", selection: resumeDate, in: tomorrow..., displayedComponents: .date)
                    .font(.system(.subheadline, design: .rounded))
                Text("No alarms until \(Formatters.dayLabel(until.startOfDay(in: model.settings.calendar), in: model.timeZone)). Custom mornings still ring.")
                    .font(.caption).foregroundStyle(Theme.faint)
            } else {
                Text("For holidays. The alarm comes back by itself on the day you pick.")
                    .font(.caption).foregroundStyle(Theme.faint)
            }
        }
        .animation(Motion.card, value: model.settings.pausedUntil != nil)
    }
}

// MARK: - Custom time

/// One morning at a fixed clock time, ignoring the sun. Reached by long-pressing a row.
struct CustomTimeSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let day: DateKey
    @State private var time: ClockTime = ClockTime(hour: 6, minute: 0)

    private var dayName: String {
        Formatters.dayLabel(day.startOfDay(in: model.settings.calendar), in: model.timeZone)
    }

    var body: some View {
        QuickSheet(title: dayName, detents: [.medium]) {
            Card(title: "Ring at", systemImage: "pin") {
                ClockTimeRow(title: "Alarm", time: $time)
                Text("Just this morning. The sunrise rule takes over again the next day.")
                    .font(.caption).foregroundStyle(Theme.faint)
            }
            HStack(spacing: 10) {
                PrimaryButton(title: "Set time", systemImage: "checkmark") {
                    model.setOverride(day, time: time)
                    Haptics.notify(.success)
                    dismiss()
                }
                if model.settings.dayOverrides[day] != nil {
                    SecondaryButton(title: "Clear", systemImage: "xmark") {
                        model.clearOverride(day)
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            // Start from the time the sun rule would give, so a small tweak is a small drag.
            if let existing = model.settings.dayOverrides[day] {
                time = existing
            } else if let planned = model.plan.first(where: { $0.date == day }),
                      let t = AlarmPlanner.alarmInstant(profile: model.settings.profile(for: day, calendar: model.settings.calendar),
                                                        day: planned.solar, calendar: model.settings.calendar).time {
                let c = model.settings.calendar.dateComponents([.hour, .minute], from: t)
                time = ClockTime(hour: c.hour ?? 6, minute: c.minute ?? 0)
            }
        }
    }
}

// MARK: - Sleep

struct SleepSheet: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        QuickSheet(title: "Sleep") {
            if let next = model.nextAlarm, let bed = next.bedtime, let wind = next.windDownTime,
               let wake = next.alarmTime {
                Card(isHero: true) {
                    SleepTimeline(
                        stops: [
                            .init(time: Formatters.time(wind, in: model.timeZone), label: "Wind down", systemImage: "book", tint: Theme.moon),
                            .init(time: Formatters.time(bed, in: model.timeZone), label: "Bedtime", systemImage: "bed.double", tint: Theme.moon),
                            .init(time: Formatters.time(wake, in: model.timeZone), label: "Alarm", systemImage: "alarm", tint: Theme.sun)
                        ],
                        caption: "\(Formatters.duration(minutes: model.settings.sleepGoalMinutes)) in bed"
                    )
                }
            }

            Card(title: "Sleep goal", systemImage: "zzz") {
                DurationPicker(minutes: $model.settings.sleepGoalMinutes)
            }

            Card(title: "Reminders", systemImage: "bell.badge") {
                Toggle("Wind-down and bedtime reminders", isOn: $model.settings.remindersEnabled)
                    .font(.system(.subheadline, design: .rounded))
                if model.settings.remindersEnabled {
                    Stepper("Wind down \(model.settings.windDownMinutes) min before bed",
                            value: $model.settings.windDownMinutes, in: 5...120, step: 5)
                        .font(.system(.subheadline, design: .rounded))
                }
                Text("Reminders are ordinary notifications — unlike the alarm they respect Focus modes, so a Sleep Focus quiets them.")
                    .font(.caption).foregroundStyle(Theme.faint)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .animation(Motion.card, value: model.settings.remindersEnabled)
        }
    }
}
