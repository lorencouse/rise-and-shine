import SwiftUI
import RiseCore

/// Home is ordered by how often you need it: the alarm and its two defining settings
/// first, then today's light, then tonight, then the week. Everything the user changes
/// weekly is a tap away on this screen; Settings holds only what you set once.
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var sheet: HomeSheet?
    /// The day the hero and light card are showing. `nil` is the resting state: the next
    /// alarm and today's light. Swiping either card pages through days.
    @State private var focus = DayFocus()
    @State private var showNightstand = false
    /// Auto-entry offers itself once per plugging-in, not every time the view redraws.
    @State private var offeredNightstand = false
    private let screen = ScreenController.shared

    var body: some View {
        NavigationStack {
            ZStack {
                DawnBackground()
                ScrollView {
                    VStack(spacing: Metrics.sectionGap) {
                        permissionBanners
                        NextAlarmHero(sheet: $sheet, focus: $focus)
                        TimeZoneNote()
                        TodayLightCard(sheet: $sheet, focus: $focus)
                        TonightCard(sheet: $sheet)
                        UpcomingCard(sheet: $sheet)
                        RecentMorningsCard()
                        if let error = model.lastError {
                            Label(error, systemImage: "exclamationmark.circle")
                                .font(.footnote)
                                .foregroundStyle(Theme.horizon)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, Metrics.screenPadding)
                    .padding(.bottom, 40)
                    .motion(Motion.card, value: model.settings.isEnabled)
                }
                .refreshable { await model.refresh() }
                .accessibilityIdentifier("home.scroll")
            }
            .navigationTitle(Date.now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { locationButton }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showNightstand = true } label: { Image(systemName: "moon.stars") }
                        .accessibilityLabel("Nightstand mode")
                        .accessibilityIdentifier("home.nightstand")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { sheet = .settings } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("Settings")
                        .accessibilityIdentifier("home.settings")
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .fullScreenCover(isPresented: $showNightstand) {
                NightstandView().environment(model)
            }
            .sheet(item: $sheet) { which in
                switch which {
                case .wakeTime: WakeTimeSheet()
                case .days: DaysSheet()
                case .sleep: SleepSheet()
                case .settings: SettingsView()
                case .trends: TrendsSheet()
                case .customTime(let day): CustomTimeSheet(day: day)
                }
            }
            // Plugging in at night is the gesture that means "this is now a clock".
            // Only then, and only once per connection, so it never hijacks the app.
            .onChange(of: screen.isCharging) { _, charging in
                guard charging else { offeredNightstand = false; return }
                guard !offeredNightstand,
                      model.settings.nightstandAutoEnabled,
                      model.isNightWindow, sheet == nil else { return }
                offeredNightstand = true
                showNightstand = true
            }
            // No `.task { refresh }` here: the scene-phase handler in the App already
            // refreshes on every activation, including launch.
            .onOpenURL { url in
                guard let link = AppGroup.DeepLink(url: url) else { return }
                switch link {
                case .home: sheet = nil
                case .wakeTime: sheet = .wakeTime
                case .days: sheet = .days
                case .sleep: sheet = .sleep
                case .skipNext:
                    sheet = .days
                    Task { await model.skipNext() }
                }
            }
        }
    }

    /// The location lives in the nav bar rather than in a card: it's context, not content,
    /// and it's still tappable for the one case that matters — you travelled.
    private var locationButton: some View {
        Menu {
            Button {
                Task { try? await model.useDeviceLocation() }
            } label: {
                Label("Use my location", systemImage: "location.fill")
            }
            if !model.settings.savedPlaces.isEmpty {
                Section("Saved places") {
                    ForEach(model.settings.savedPlaces, id: \.self) { place in
                        Button {
                            model.setLocation(place)
                        } label: {
                            if model.settings.location == place {
                                Label(place.name, systemImage: "checkmark")
                            } else {
                                Text(place.name)
                            }
                        }
                    }
                }
            }
            Button { sheet = .settings } label: { Label("Search for a city…", systemImage: "magnifyingglass") }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: model.settings.location?.followsDevice == true ? "location.fill" : "mappin")
                    .font(.caption2)
                Text(model.settings.location?.name ?? "No location")
                    .accessibilityIdentifier("home.locationName")
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
/// Which day Home is looking at, and which way it got there (for the slide direction).
struct DayFocus: Equatable {
    /// `nil` = resting state (next alarm / today).
    var day: DateKey? = nil
    var direction: Direction = .forward
    enum Direction { case forward, backward }

    static let backLimit = 60
    static let forwardLimit = 365

    var isResting: Bool { day == nil }
}

/// Horizontal swipe → page a day. Lives on the cards, not the screen, so the ScrollView
/// keeps vertical drags. The threshold and the "more horizontal than vertical" test keep a
/// sloppy scroll from flipping days.
struct DayPagingGesture: ViewModifier {
    @Environment(AppModel.self) private var model
    @Binding var focus: DayFocus

    func body(content: Content) -> some View {
        content.simultaneousGesture(
            DragGesture(minimumDistance: 24, coordinateSpace: .local)
                .onEnded { value in
                    let dx = value.translation.width, dy = value.translation.height
                    guard abs(dx) > 50, abs(dx) > abs(dy) * 1.5 else { return }
                    focus.step(dx < 0 ? 1 : -1, model: model)
                }
        )
    }
}

extension DayFocus {
    /// The day being shown, resolved against the model's resting choice.
    func resolved(_ model: AppModel) -> DateKey {
        day ?? model.nextAlarm?.date ?? model.todayKey
    }

    mutating func step(_ delta: Int, model: AppModel) {
        let calendar = model.settings.calendar
        let today = model.todayKey
        let target = resolved(model).adding(days: delta, in: calendar)
        let back = today.adding(days: -Self.backLimit, in: calendar)
        let forward = today.adding(days: Self.forwardLimit, in: calendar)
        guard target >= back, target <= forward else { Haptics.notify(.warning); return }
        direction = delta > 0 ? .forward : .backward
        Haptics.selection()
        // Landing back on the resting day returns to the resting state, so the countdown
        // and "NEXT ALARM" come back rather than a frozen copy of the same day.
        let resting = model.nextAlarm?.date ?? today
        withAnimation(Motion.respectingReduceMotion(Motion.card)) { day = target == resting ? nil : target }
    }

    mutating func reset() {
        direction = .backward
        withAnimation(Motion.respectingReduceMotion(Motion.card)) { day = nil }
    }
}

struct NextAlarmHero: View {
    @Environment(AppModel.self) private var model
    @Binding var sheet: HomeSheet?
    @Binding var focus: DayFocus
    @ScaledMetric(relativeTo: .largeTitle) private var displaySize: CGFloat = 68
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var focusedKey: DateKey { focus.resolved(model) }
    private var focusedDay: PlannedDay? { model.plannedDay(for: focusedKey) }

    private var eyebrow: String {
        if focus.isResting { return model.settings.isEnabled ? "NEXT ALARM" : "ALARM OFF" }
        return Formatters.dayLabel(focusedKey.startOfDay(in: model.settings.calendar), in: model.timeZone).uppercased()
    }

    /// Paging slides the old day out and the new one in from the side it came from. With
    /// Reduce Motion the days crossfade in place instead.
    private var slide: AnyTransition {
        if reduceMotion { return .opacity }
        return .asymmetric(
            insertion: .move(edge: focus.direction == .forward ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: focus.direction == .forward ? .leading : .trailing).combined(with: .opacity)
        )
    }

    var body: some View {
        @Bindable var model = model
        Card(isHero: true) {
            HStack(alignment: .center, spacing: 6) {
                pageButton(systemImage: "chevron.left", delta: -1)
                Text(eyebrow)
                    .accessibilityIdentifier("home.eyebrow")
                    .font(.eyebrow).tracking(1.2)
                    .foregroundStyle(!focus.isResting ? Theme.sun : model.settings.isEnabled ? Theme.faint : Theme.horizon)
                    .contentTransition(.opacity)
                    .lineLimit(1)
                pageButton(systemImage: "chevron.right", delta: 1)
                if !focus.isResting {
                    Button("Today") { focus.reset() }
                        .accessibilityIdentifier("home.today")
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.bordered).buttonBorderShape(.capsule)
                        .controlSize(.mini)
                        .tint(Theme.sun)
                }
                Spacer()
                Toggle("Sunrise alarm", isOn: $model.settings.isEnabled)
                    .accessibilityIdentifier("home.alarmToggle")
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(Theme.sunrise)
                    .onChange(of: model.settings.isEnabled) { _, on in
                        Haptics.impact(on ? .medium : .light)
                    }
            }

            if focus.isResting, let live = model.alarms.liveState {
                LiveStateBanner(state: live)
            }

            ZStack(alignment: .leading) {
                if focus.isResting {
                    timeBlock.transition(slide)
                } else if let day = focusedDay {
                    FocusedDayBlock(day: day, displaySize: displaySize, sheet: $sheet)
                        .id(day.date)
                        .transition(slide)
                }
            }
            .clipped()
            .motion(Motion.card, value: focus)

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

            let shown = focus.isResting ? model.nextAlarm : focusedDay
            if let shown, shown.isActive, shown.isOverridden {
                Label("Custom time for this morning", systemImage: "pin.fill")
                    .font(.caption).foregroundStyle(Theme.sun)
            } else if let shown, shown.isActive, shown.wasClamped {
                Label("Held inside your wake window (\(windowText))",
                      systemImage: "arrow.left.and.right.square")
                    .font(.caption).foregroundStyle(Theme.sun)
            }
            if let weekend = model.settings.weekendProfile {
                Text("Weekends: \(weekend.offsetDescription.lowercased())")
                    .font(.caption).foregroundStyle(Theme.faint)
            }
        }
        .modifier(DayPagingGesture(focus: $focus))
        .accessibilityAction(named: "Next day") { focus.step(1, model: model) }
        .accessibilityAction(named: "Previous day") { focus.step(-1, model: model) }
    }

    private func pageButton(systemImage: String, delta: Int) -> some View {
        Button { focus.step(delta, model: model) } label: {
            Image(systemName: systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.faint)
                .frame(width: 28, height: 28)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(delta > 0 ? "Next day" : "Previous day")
        .accessibilityIdentifier(delta > 0 ? "home.pageNext" : "home.pagePrev")
    }

    private var offsetChip: some View {
        ControlChip(compactOffset, systemImage: "sun.horizon.fill") { sheet = .wakeTime }
            .accessibilityIdentifier("home.wakeTimeChip")
    }

    private var daysChip: some View {
        ControlChip(daysChipText, systemImage: model.settings.pausedUntil == nil ? "calendar" : "pause.circle",
                    tint: Theme.moon) { sheet = .days }
            .accessibilityIdentifier("home.daysChip")
    }

    private var daysChipText: String {
        if let until = model.settings.pausedUntil {
            return "Paused until \(Formatters.weekdayShort(until.startOfDay(in: model.settings.calendar), in: model.timeZone))"
        }
        return WeekdaySummary.text(for: model.settings.activeWeekdays)
    }

    @ViewBuilder
    private var timeBlock: some View {
        if let next = model.nextAlarm, let time = next.alarmTime {
            VStack(alignment: .leading, spacing: 2) {
                Text(Formatters.time(time, in: model.timeZone))
                    .accessibilityIdentifier("home.heroTime")
                    .font(.displayTime(displaySize))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .contentTransition(reduceMotion ? .opacity : .numericText())
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
                    .font(.displayTime(displaySize))
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
        if model.isFullyPaused { return "Paused" }
        if model.settings.activeWeekdays.isEmpty { return "No days on" }
        return "Nothing scheduled"
    }

    private var emptyDetail: String {
        if !model.settings.isEnabled { return "Flip the switch to wake with the sun again." }
        if !model.hasLocation { return "Choose where you wake up and the sunrise times follow." }
        if model.isFullyPaused, let until = model.settings.pausedUntil {
            return "Alarms resume on \(Formatters.dayLabel(until.startOfDay(in: model.settings.calendar), in: model.timeZone))."
        }
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

/// The hero's centre when paged away from the next alarm: that day's alarm, or why there
/// isn't one, plus its sunrise and sunset. Past days say what happened if we know.
struct FocusedDayBlock: View {
    @Environment(AppModel.self) private var model
    let day: PlannedDay
    let displaySize: CGFloat
    @Binding var sheet: HomeSheet?

    private var isPast: Bool { day.date < model.todayKey }
    private var hasRung: Bool { (day.alarmTime ?? .distantFuture) <= .now }
    private var record: WakeRecord? { model.alarms.history[day.date] }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let time = day.alarmTime {
                Text(Formatters.time(time, in: model.timeZone))
                    .font(.displayTime(displaySize))
                    .foregroundStyle(hasRung ? Theme.faint : .white)
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            } else {
                Text(headline)
                    .font(.system(size: 30, weight: .light, design: .rounded))
                    .foregroundStyle(Theme.mist)
                    .padding(.vertical, 6)
            }
            HStack(spacing: 6) {
                Text(subline)
                    .font(.footnote).foregroundStyle(Theme.faint)
                    .lineLimit(2)
                Spacer(minLength: 0)
                if !isPast && !hasRung && (day.status == .active || day.status == .skipped) {
                    Button {
                        Haptics.impact(.light)
                        model.toggleSkip(day)
                    } label: {
                        Label(day.status == .skipped ? "Restore" : "Skip", systemImage: day.status == .skipped ? "arrow.uturn.backward" : "forward.end")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.bordered).buttonBorderShape(.capsule).controlSize(.small)
                    .tint(Theme.sun)
                    Button {
                        sheet = .customTime(day.date)
                    } label: {
                        Image(systemName: "pin").font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.bordered).buttonBorderShape(.circle).controlSize(.small)
                    .tint(Theme.moon)
                    .accessibilityLabel("Set a custom time")
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var headline: String {
        switch day.status {
        case .disabled: "Alarm off"
        case .weekdayOff: "Day off"
        case .skipped: "Skipped"
        case .paused: "Paused"
        case .noSunEvent: "No sunrise"
        case .active: "—"
        }
    }

    private var subline: String {
        var parts: [String] = []
        if let record, let rang = record.rang {
            parts.append("Rang \(Formatters.time(rang, in: model.timeZone))\(record.snoozes > 0 ? ", snoozed \(record.snoozes)×" : "")")
        } else if hasRung {
            parts.append("Rang")
        }
        if let s = day.solar.sunrise { parts.append("Sunrise \(Formatters.time(s, in: model.timeZone))") }
        if let s = day.solar.sunset { parts.append("Sunset \(Formatters.time(s, in: model.timeZone))") }
        return parts.joined(separator: " · ")
    }
}

/// "Ringing" or "Snoozing" while iOS has one of our alarms in flight. The hero otherwise
/// already points at the *next* morning, which reads as if nothing is happening.
struct LiveStateBanner: View {
    let state: AlarmScheduler.LiveState

    private var text: String {
        switch state {
        case .ringing: "Ringing now"
        case .snoozing: "Snoozing. Stop or snooze again from the Lock Screen."
        case .paused: "Snooze paused"
        }
    }

    private var icon: String {
        switch state {
        case .ringing: "bell.and.waves.left.and.right.fill"
        case .snoozing: "zzz"
        case .paused: "pause.circle"
        }
    }

    var body: some View {
        Label(text, systemImage: icon)
            .font(.system(.footnote, design: .rounded).weight(.semibold))
            .foregroundStyle(Theme.night)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Theme.sun, in: .capsule)
            .symbolEffect(.pulse, isActive: state == .ringing)
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
    @Binding var sheet: HomeSheet?
    @Binding var focus: DayFocus

    /// Resting state shows today; paged, it follows the hero so the two cards agree.
    private var key: DateKey { focus.isResting ? model.todayKey : focus.resolved(model) }

    private var title: String {
        key == model.todayKey ? "Today's light"
            : "Light \(Formatters.dayLabel(key.startOfDay(in: model.settings.calendar), in: model.timeZone))"
    }

    private var alarmMarker: Date? {
        key == model.todayKey ? model.alarmMarkerForToday : model.plannedDay(for: key)?.alarmTime
    }

    var body: some View {
        if let shown = model.plannedDay(for: key) {
            let solar = shown.solar
            Card(title: title, systemImage: "sun.horizon") {
                SunArcView(day: solar, alarmTime: alarmMarker, timeZone: model.timeZone)
                    .id(key)
                MetricGrid(items: [
                    .init(title: "Dawn", value: solar.civilDawn.map { Formatters.time($0, in: model.timeZone) } ?? "—", systemImage: "sunrise"),
                    .init(title: "Sunrise", value: solar.sunrise.map { Formatters.time($0, in: model.timeZone) } ?? "—", systemImage: "sun.max"),
                    .init(title: "Sunset", value: solar.sunset.map { Formatters.time($0, in: model.timeZone) } ?? "—", systemImage: "sunset"),
                    .init(title: "Daylight", value: solar.dayLength.map(Formatters.duration(seconds:)) ?? "—", systemImage: "hourglass")
                ])
                if let drift = model.daylightDrift(for: key) {
                    Label(drift, systemImage: "chart.line.uptrend.xyaxis")
                        .font(.caption)
                        .foregroundStyle(Theme.faint)
                }
            } accessory: {
                Button("Trends") { sheet = .trends }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.sunrise)
            }
            .modifier(DayPagingGesture(focus: $focus))
            .motion(Motion.card, value: key)
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
                if let slept = model.lastNightSleepMinutes {
                    let goal = model.settings.sleepGoalMinutes
                    let delta = slept - goal
                    Label("Last night \(Formatters.duration(minutes: slept))\(abs(delta) >= 10 ? ", \(Formatters.duration(minutes: abs(delta))) \(delta < 0 ? "under" : "over") your goal" : ", on goal")",
                          systemImage: "heart.text.square")
                        .font(.caption).foregroundStyle(delta < -30 ? Theme.horizon : Theme.faint)
                }
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

// MARK: - Recent mornings

/// Appears once there is at least one completed morning. Quiet by design: a streak and two
/// averages, not a dashboard.
struct RecentMorningsCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let history = model.alarms.history
        if !history.completed.isEmpty {
            Card(title: "Recent mornings", systemImage: "sun.max") {
                MetricGrid(items: [
                    .init(title: "Up with the alarm", value: "\(history.cleanStreak) in a row", systemImage: "flame"),
                    .init(title: "Snoozes", value: history.averageSnoozes.map { String(format: "%.1f avg", $0) } ?? "—", systemImage: "zzz"),
                    .init(title: history.averageSleepMinutes != nil ? "Avg sleep" : "Time to stop",
                          value: history.averageSleepMinutes.map { Formatters.duration(minutes: $0) }
                              ?? history.averageLinger.map { Formatters.duration(seconds: $0) } ?? "—",
                          systemImage: history.averageSleepMinutes != nil ? "moon.zzz" : "hourglass"),
                    .init(title: "Mornings", value: "\(history.completed.count)", systemImage: "calendar")
                ])
                if let last = history.completed.first, let rang = last.rang {
                    Text("Last: \(Formatters.dayLabel(last.date.startOfDay(in: model.settings.calendar), in: model.timeZone)), rang \(Formatters.time(rang, in: model.timeZone))\(last.snoozes > 0 ? ", snoozed \(last.snoozes)×" : "").")
                        .accessibilityIdentifier("home.recentMornings.last")
                        .font(.caption).foregroundStyle(Theme.faint)
                }
            }
        }
    }
}

// MARK: - Upcoming

struct UpcomingCard: View {
    @Environment(AppModel.self) private var model
    @Binding var sheet: HomeSheet?

    private var days: [PlannedDay] { Array(model.upcoming.prefix(7)) }

    var body: some View {
        Card(title: "Next 7 days", systemImage: "calendar") {
            VStack(spacing: 0) {
                ForEach(days) { day in
                    UpcomingRow(day: day, sheet: $sheet)
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
    @Binding var sheet: HomeSheet?

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
        .motion(Motion.quick, value: day.status)
        .accessibilityElement(children: .combine)
        .accessibilityHint(hasRung || day.status == .disabled ? "" : "Touch and hold for a custom time")
        .contextMenu {
            if !hasRung && day.status != .disabled {
                Button {
                    sheet = .customTime(day.date)
                } label: {
                    Label(day.isOverridden ? "Change custom time…" : "Set a custom time…", systemImage: "pin")
                }
                if day.isOverridden {
                    Button { model.clearOverride(day.date) } label: {
                        Label("Back to sunrise rule", systemImage: "sun.horizon")
                    }
                }
                if canSkip {
                    Button { model.toggleSkip(day) } label: {
                        Label(isSkipped ? "Restore" : "Skip this morning", systemImage: isSkipped ? "arrow.uturn.backward" : "forward.end")
                    }
                }
            }
        }
    }

    private var dayName: String {
        Formatters.dayLabel(day.date.startOfDay(in: model.settings.calendar), in: model.timeZone)
    }

    private var skipButton: some View {
        Button {
            Haptics.impact(isSkipped ? .light : .medium)
            withAnimation(Motion.respectingReduceMotion(Motion.quick)) { model.toggleSkip(day) }
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
                if day.isOverridden && !hasRung {
                    Image(systemName: "pin.fill")
                        .font(.caption).foregroundStyle(Theme.sun)
                        .accessibilityLabel("Custom time")
                } else if day.wasClamped && !hasRung {
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
        case .paused:
            Text("Paused").font(.caption).foregroundStyle(Theme.faint)
        }
    }
}
