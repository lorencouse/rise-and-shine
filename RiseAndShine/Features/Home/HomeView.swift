import SwiftUI
import RiseCore

/// Home is ordered by how often you need it: the alarm and its two defining settings
/// first, then today's light, then tonight, then the week. Everything the user changes
/// weekly is a tap away on this screen; Settings holds only what you set once.
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var sheet: HomeSheet?

    var body: some View {
        NavigationStack {
            ZStack {
                DawnBackground()
                ScrollView {
                    VStack(spacing: Metrics.sectionGap) {
                        permissionBanners
                        NextAlarmHero(sheet: $sheet)
                        TimeZoneNote()
                        TodayLightCard()
                        TonightCard(sheet: $sheet)
                        UpcomingCard()
                        if let error = model.lastError {
                            Label(error, systemImage: "exclamationmark.circle")
                                .font(.footnote)
                                .foregroundStyle(Theme.horizon)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, Metrics.screenPadding)
                    .padding(.bottom, 40)
                    .animation(Motion.card, value: model.settings.isEnabled)
                }
                .refreshable { await model.refresh() }
            }
            .navigationTitle(Date.now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { locationButton }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { sheet = .settings } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("Settings")
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(item: $sheet) { which in
                switch which {
                case .wakeTime: WakeTimeSheet()
                case .days: DaysSheet()
                case .sleep: SleepSheet()
                case .settings: SettingsView()
                }
            }
            .task { await model.refresh() }
        }
    }

    /// The location lives in the nav bar rather than in a card: it's context, not content,
    /// and it's still tappable for the one case that matters — you travelled.
    private var locationButton: some View {
        Button { sheet = .settings } label: {
            HStack(spacing: 4) {
                Image(systemName: model.settings.location?.followsDevice == true ? "location.fill" : "mappin")
                    .font(.caption2)
                Text(model.settings.location?.name ?? "No location")
                    .lineLimit(1)
            }
            .font(.footnote)
            .foregroundStyle(Theme.mist)
        }
        .accessibilityLabel("Location: \(model.settings.location?.name ?? "not set"). Opens settings.")
    }

    @ViewBuilder
    private var permissionBanners: some View {
        if !model.hasLocation {
            PermissionBanner(
                title: "Set a location",
                message: "Sunrise depends on where you are. Without it there's nothing to schedule.",
                buttonTitle: "Choose location"
            ) { sheet = .settings }
        }
        if model.alarms.authorization == .denied {
            PermissionBanner(
                title: "Alarms are turned off",
                message: "Rise and Shine can't wake you until alarm access is allowed in Settings.",
                buttonTitle: "Open Settings"
            ) { openSystemSettings() }
        } else if model.alarms.authorization == .notDetermined {
            PermissionBanner(
                title: "Allow alarms",
                message: "Alarms ring through Silent mode and Focus, just like the Clock app.",
                buttonTitle: "Allow alarms",
                isBlocking: false
            ) { Task { await model.alarms.requestAuthorization(); await model.refresh() } }
        }
    }
}

// MARK: - Hero

/// The one thing you open the app to see, plus the two settings that produce it. The
/// chips underneath make "30 min before sunrise" a control, not a caption.
struct NextAlarmHero: View {
    @Environment(AppModel.self) private var model
    @Binding var sheet: HomeSheet?

    var body: some View {
        @Bindable var model = model
        Card(isHero: true) {
            HStack(alignment: .firstTextBaseline) {
                Text(model.settings.isEnabled ? "NEXT ALARM" : "ALARM OFF")
                    .font(.eyebrow).tracking(1.2)
                    .foregroundStyle(model.settings.isEnabled ? Theme.faint : Theme.horizon)
                    .contentTransition(.opacity)
                Spacer()
                Toggle("Sunrise alarm", isOn: $model.settings.isEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(Theme.sunrise)
                    .onChange(of: model.settings.isEnabled) { _, on in
                        Haptics.impact(on ? .medium : .light)
                    }
            }

            timeBlock

            // Direct manipulation: the settings that define the alarm sit under it. Side by
            // side when they fit, stacked at accessibility text sizes — a truncated
            // "Dawn…" would hide the very value the chip exists to show.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    offsetChip
                    daysChip
                    Spacer(minLength: 0)
                }
                VStack(alignment: .leading, spacing: 8) {
                    offsetChip
                    daysChip
                }
            }
            .padding(.top, 2)

            if let next = model.nextAlarm, next.wasClamped {
                Label("Held inside your wake window (\(windowText))",
                      systemImage: "arrow.left.and.right.square")
                    .font(.caption).foregroundStyle(Theme.sun)
            }
        }
    }

    private var offsetChip: some View {
        ControlChip(compactOffset, systemImage: "sun.horizon.fill") { sheet = .wakeTime }
    }

    private var daysChip: some View {
        ControlChip(WeekdaySummary.text(for: model.settings.activeWeekdays),
                    systemImage: "calendar", tint: Theme.moon) { sheet = .days }
    }

    @ViewBuilder
    private var timeBlock: some View {
        if let next = model.nextAlarm, let time = next.alarmTime {
            VStack(alignment: .leading, spacing: 2) {
                Text(Formatters.time(time, in: model.timeZone))
                    .font(.displayTime)
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(Formatters.dayLabel(time, in: model.timeZone))
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(Theme.mist)
                    Text("·").foregroundStyle(Theme.faint)
                    TimelineView(.periodic(from: .now, by: 60)) { ctx in
                        Text("in \(Formatters.countdown(to: time, from: ctx.date))")
                            .font(.footnote)
                            .foregroundStyle(Theme.faint)
                            .monospacedDigit()
                    }
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Next alarm \(Formatters.time(time, in: model.timeZone)), \(Formatters.dayLabel(time, in: model.timeZone))")
        } else if !model.settings.isEnabled, let wouldBe = wouldRingTomorrow {
            // Switched off, but the settings still say something. Showing the time the
            // alarm *would* ring makes the switch a preview rather than a dead end.
            VStack(alignment: .leading, spacing: 2) {
                Text(Formatters.time(wouldBe, in: model.timeZone))
                    .font(.displayTime)
                    .foregroundStyle(Theme.faint)
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text("Would ring tomorrow. Turn the alarm on to keep it.")
                    .font(.footnote)
                    .foregroundStyle(Theme.faint)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Alarm off. Would ring at \(Formatters.time(wouldBe, in: model.timeZone)) tomorrow.")
        } else {
            // An empty hero is where users get stuck, so say what to do, not just "—".
            VStack(alignment: .leading, spacing: 6) {
                Text(emptyHeadline)
                    .font(.system(size: 30, weight: .light, design: .rounded))
                    .foregroundStyle(Theme.mist)
                Text(emptyDetail)
                    .font(.footnote)
                    .foregroundStyle(Theme.faint)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 6)
        }
    }

    /// What the current settings would produce tomorrow, ignoring the master switch.
    private var wouldRingTomorrow: Date? {
        guard let tomorrow = model.settings.calendar.date(byAdding: .day, value: 1, to: .now),
              let plan = model.preview(model.settings, on: tomorrow) else { return nil }
        return AlarmPlanner.alarmInstant(settings: model.settings, day: plan.solar).time
    }

    /// "Sunrise − 30 min" rather than "30 min before sunrise": two chips have to share one
    /// row, and the anchor is the word worth leading with.
    private var compactOffset: String {
        let minutes = model.settings.offsetMinutes
        let anchor = model.settings.anchor.title
        guard minutes != 0 else { return "At \(anchor.lowercased())" }
        let sign = minutes < 0 ? "−" : "+"
        return "\(anchor) \(sign) \(Formatters.duration(minutes: abs(minutes)))"
    }

    private var emptyHeadline: String {
        if !model.settings.isEnabled { return "Alarm off" }
        if !model.hasLocation { return "No location" }
        if model.settings.activeWeekdays.isEmpty { return "No days on" }
        return "Nothing scheduled"
    }

    private var emptyDetail: String {
        if !model.settings.isEnabled { return "Flip the switch to wake with the sun again." }
        if !model.hasLocation { return "Choose where you wake up and the sunrise times follow." }
        if model.settings.activeWeekdays.isEmpty { return "Pick at least one day below." }
        return "No active mornings in the next \(model.settings.horizonDays) days."
    }

    private var windowText: String {
        let s = model.settings
        let calendar = s.calendar
        let key = DateKey(date: .now, calendar: calendar)
        return "\(Formatters.time(s.earliest.date(on: key, calendar: calendar), in: model.timeZone))–\(Formatters.time(s.latest.date(on: key, calendar: calendar), in: model.timeZone))"
    }
}

/// Shown only when the location's clock disagrees with the phone's — while travelling, or
/// with a city picked manually. Without it a Reykjavík sunrise of "5:36 AM" looks wrong to
/// someone whose phone says it's 10:36 PM.
struct TimeZoneNote: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if model.hasLocation, model.timeZoneDiffersFromDevice, let name = model.settings.location?.name {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "globe")
                    .font(.caption)
                    .foregroundStyle(Theme.moon)
                Text("Times are shown in \(name) time (\(Formatters.zoneAbbreviation(model.timeZone))). Your phone is set to \(Formatters.zoneAbbreviation(.current)).")
                    .font(.caption)
                    .foregroundStyle(Theme.mist)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Theme.card, in: .rect(cornerRadius: 14))
            .accessibilityElement(children: .combine)
        }
    }
}

// MARK: - Today's light

struct TodayLightCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let today = model.today {
            let solar = today.solar
            Card(title: "Today's light", systemImage: "sun.horizon") {
                SunArcView(day: solar, alarmTime: model.alarmMarkerForToday, timeZone: model.timeZone)
                MetricGrid(items: [
                    .init(title: "First light", value: solar.civilDawn.map { Formatters.time($0, in: model.timeZone) } ?? "—", systemImage: "sunrise"),
                    .init(title: "Sunrise", value: solar.sunrise.map { Formatters.time($0, in: model.timeZone) } ?? "—", systemImage: "sun.max"),
                    .init(title: "Sunset", value: solar.sunset.map { Formatters.time($0, in: model.timeZone) } ?? "—", systemImage: "sunset"),
                    .init(title: "Daylight", value: solar.dayLength.map(Formatters.duration(seconds:)) ?? "—", systemImage: "hourglass")
                ])
                if let drift = model.daylightDrift {
                    Label(drift, systemImage: "chart.line.uptrend.xyaxis")
                        .font(.caption)
                        .foregroundStyle(Theme.faint)
                }
            }
        }
    }
}

// MARK: - Tonight

struct TonightCard: View {
    @Environment(AppModel.self) private var model
    @Binding var sheet: HomeSheet?

    var body: some View {
        Card(title: "Tonight", systemImage: "moon.stars") {
            if let night = model.tonight, let bed = night.bedtime, let wind = night.windDownTime,
               let wake = night.alarmTime {
                SleepTimeline(
                    stops: [
                        .init(time: Formatters.time(wind, in: model.timeZone), label: "Wind down", systemImage: "book", tint: Theme.moon),
                        .init(time: Formatters.time(bed, in: model.timeZone), label: "Bedtime", systemImage: "bed.double", tint: Theme.moon),
                        .init(time: Formatters.time(wake, in: model.timeZone), label: "Alarm", systemImage: "alarm", tint: Theme.sun)
                    ],
                    caption: "\(Formatters.duration(minutes: model.settings.sleepGoalMinutes)) in bed"
                )
                if !model.settings.remindersEnabled {
                    Text("Reminders are off — these times are a plan, not a nudge.")
                        .font(.caption).foregroundStyle(Theme.faint)
                } else if model.reminders.authorization == .denied {
                    Text("Notifications are blocked, so bedtime reminders won't show.")
                        .font(.caption).foregroundStyle(Theme.horizon)
                }
            } else {
                Text("No alarm tomorrow morning, so there's no bedtime to hit.")
                    .font(.footnote).foregroundStyle(Theme.faint)
            }
        } accessory: {
            Button("Edit") { sheet = .sleep }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.sunrise)
        }
    }
}

// MARK: - Upcoming

struct UpcomingCard: View {
    @Environment(AppModel.self) private var model

    private var days: [PlannedDay] { Array(model.upcoming.prefix(7)) }

    var body: some View {
        Card(title: "Next 7 days", systemImage: "calendar") {
            VStack(spacing: 0) {
                ForEach(days) { day in
                    UpcomingRow(day: day)
                    if day.id != days.last?.id {
                        Divider().overlay(Theme.cardStroke)
                    }
                }
            }
        }
    }
}

/// One morning. The skip control is an explicit button rather than a tap anywhere on the
/// row: skipping is destructive-ish, and an invisible tap target on a list of times is
/// easy to trigger by accident while scrolling.
struct UpcomingRow: View {
    @Environment(AppModel.self) private var model
    let day: PlannedDay

    private var isSkipped: Bool { day.status == .skipped }
    /// This morning's alarm is still in the list after it rings; skipping it is meaningless.
    private var hasRung: Bool { (day.alarmTime ?? .distantFuture) <= .now }
    private var canSkip: Bool { !hasRung && (day.status == .active || isSkipped) }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Formatters.dayLabel(day.date.startOfDay(in: model.settings.calendar), in: model.timeZone))
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .strikethrough(isSkipped, color: Theme.faint)
                HStack(spacing: 4) {
                    Image(systemName: "sunrise").font(.caption2)
                    Text(day.solar.sunrise.map { Formatters.time($0, in: model.timeZone) } ?? "no sunrise")
                }
                .font(.caption).foregroundStyle(Theme.faint)
            }
            Spacer(minLength: 8)
            statusView
            if canSkip { skipButton }
        }
        .padding(.vertical, 10)
        .contentShape(.rect)
        .opacity(day.isActive && !hasRung ? 1 : 0.55)
        .animation(Motion.quick, value: day.status)
        .accessibilityElement(children: .combine)
    }

    private var dayName: String {
        Formatters.dayLabel(day.date.startOfDay(in: model.settings.calendar), in: model.timeZone)
    }

    private var skipButton: some View {
        Button {
            Haptics.impact(isSkipped ? .light : .medium)
            withAnimation(Motion.quick) { model.toggleSkip(day) }
        } label: {
            Image(systemName: isSkipped ? "arrow.uturn.backward" : "forward.end")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(isSkipped ? Theme.sun : Theme.faint)
                .frame(width: 34, height: 34)
                .background(Theme.card, in: .circle)
                .overlay(Circle().strokeBorder(Theme.cardStroke))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isSkipped ? "Restore \(dayName)" : "Skip \(dayName)")
    }

    @ViewBuilder
    private var statusView: some View {
        switch day.status {
        case .active:
            HStack(spacing: 6) {
                if day.wasClamped && !hasRung {
                    Image(systemName: "arrow.left.and.right.square")
                        .font(.caption).foregroundStyle(Theme.sun)
                        .accessibilityLabel("Held inside wake window")
                }
                VStack(alignment: .trailing, spacing: 1) {
                    Text(day.alarmTime.map { Formatters.time($0, in: model.timeZone) } ?? "—")
                        .font(.system(.title3, design: .rounded).weight(.medium))
                        .monospacedDigit()
                    if hasRung {
                        Text("Rang").font(.caption2).foregroundStyle(Theme.faint)
                    }
                }
            }
        case .skipped:
            Text("Skipped").font(.caption).foregroundStyle(Theme.sun)
        case .weekdayOff:
            Text("Off").font(.caption).foregroundStyle(Theme.faint)
        case .disabled:
            Text("Alarm off").font(.caption).foregroundStyle(Theme.faint)
        case .noSunEvent:
            Text("No sunrise").font(.caption).foregroundStyle(Theme.faint)
        }
    }
}
