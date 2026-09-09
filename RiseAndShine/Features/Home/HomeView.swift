import SwiftUI
import RiseCore

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ZStack {
                DawnBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        header
                        permissionBanners
                        NextAlarmCard()
                        if let today = model.today {
                            Card(title: "Today's light", systemImage: "sun.horizon") {
                                SunArcView(day: today.solar, alarmTime: model.nextAlarmToday?.alarmTime)
                                daylightRow(today.solar)
                            }
                        }
                        TonightCard()
                        UpcomingCard()
                        if let error = model.lastError {
                            Text(error).font(.footnote).foregroundStyle(Theme.horizon).padding(.horizontal)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
                .refreshable { await model.refresh() }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("Settings")
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(isPresented: $showSettings) { SettingsView() }
            .task { await model.refresh() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .font(.system(.title2, design: .rounded).weight(.semibold))
            HStack(spacing: 4) {
                Image(systemName: model.settings.location?.followsDevice == true ? "location.fill" : "mappin")
                Text(model.settings.location?.name ?? "No location")
            }
            .font(.footnote)
            .foregroundStyle(Theme.faint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    @ViewBuilder
    private var permissionBanners: some View {
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
                buttonTitle: "Allow"
            ) { Task { await model.alarms.requestAuthorization(); await model.refresh() } }
        }
        if !model.hasLocation {
            PermissionBanner(
                title: "Set a location",
                message: "Sunrise depends on where you are. Choose your location in Settings.",
                buttonTitle: "Choose location"
            ) { showSettings = true }
        }
    }

    private func daylightRow(_ solar: SolarDay) -> some View {
        HStack {
            StatView(title: "First light", value: solar.civilDawn.map(Formatters.time) ?? "—", systemImage: "sunrise")
            Spacer()
            StatView(title: "Sunrise", value: solar.sunrise.map(Formatters.time) ?? "—", systemImage: "sun.max")
            Spacer()
            StatView(title: "Sunset", value: solar.sunset.map(Formatters.time) ?? "—", systemImage: "sunset")
            Spacer()
            StatView(title: "Daylight", value: solar.dayLength.map(Formatters.duration(seconds:)) ?? "—", systemImage: "hourglass")
        }
    }
}

private extension AppModel {
    /// The alarm shown on today's arc: today's if still ahead, otherwise nothing.
    var nextAlarmToday: PlannedDay? {
        guard let today, let t = today.alarmTime, t > .now else { return nil }
        return today
    }
}

// MARK: - Next alarm

struct NextAlarmCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Card {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(model.settings.isEnabled ? "NEXT ALARM" : "ALARM OFF")
                        .font(.label.weight(.semibold)).tracking(1.2).foregroundStyle(Theme.faint)
                    if let next = model.nextAlarm, let time = next.alarmTime {
                        Text(Formatters.time(time))
                            .font(.displayTime).foregroundStyle(.white).monospacedDigit()
                            .contentTransition(.numericText())
                        Text("\(Formatters.dayLabel(time)) · \(subtitle(for: next))")
                            .font(.footnote).foregroundStyle(Theme.mist)
                        TimelineView(.periodic(from: .now, by: 60)) { ctx in
                            Text("Rings in \(Formatters.countdown(to: time, from: ctx.date))")
                                .font(.footnote).foregroundStyle(Theme.faint)
                        }
                    } else if !model.settings.isEnabled {
                        Text("—").font(.displayTime).foregroundStyle(Theme.faint)
                        Text("Turn the alarm on to wake with the sun.").font(.footnote).foregroundStyle(Theme.mist)
                    } else {
                        Text("—").font(.displayTime).foregroundStyle(Theme.faint)
                        Text(model.hasLocation ? "No active days in the next \(model.settings.horizonDays) days." : "Choose a location to see your alarm.")
                            .font(.footnote).foregroundStyle(Theme.mist)
                    }
                }
                Spacer()
                Toggle("Alarm enabled", isOn: $model.settings.isEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
            if let next = model.nextAlarm, next.wasClamped {
                Label("Kept inside your wake window (\(windowText))", systemImage: "arrow.left.and.right.square")
                    .font(.caption).foregroundStyle(Theme.sun)
            }
        }
    }

    private var windowText: String {
        let s = model.settings
        let e = s.earliest.date(on: DateKey(date: .now)), l = s.latest.date(on: DateKey(date: .now))
        return "\(Formatters.time(e))–\(Formatters.time(l))"
    }

    private func subtitle(for day: PlannedDay) -> String {
        let anchor = model.settings.anchor
        guard let anchorTime = day.solar.time(for: anchor) else { return model.settings.offsetDescription }
        return "\(model.settings.offsetDescription) (\(Formatters.time(anchorTime)))"
    }
}

// MARK: - Tonight

struct TonightCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let night = model.tonight, let bed = night.bedtime, let wind = night.windDownTime {
            Card(title: "Tonight", systemImage: "moon.stars") {
                HStack {
                    StatView(title: "Wind down", value: Formatters.time(wind), systemImage: "book")
                    Spacer()
                    StatView(title: "Bedtime", value: Formatters.time(bed), systemImage: "bed.double", emphasis: true)
                    Spacer()
                    StatView(title: "Sleep goal", value: Formatters.duration(minutes: model.settings.sleepGoalMinutes), systemImage: "zzz")
                }
                if !model.settings.remindersEnabled {
                    Text("Reminders are off. Turn them on in Settings to get a nudge.")
                        .font(.caption).foregroundStyle(Theme.faint)
                } else if model.reminders.authorization == .denied {
                    Text("Notifications are blocked, so bedtime reminders won't show.")
                        .font(.caption).foregroundStyle(Theme.horizon)
                }
            }
        }
    }
}

// MARK: - Upcoming

struct UpcomingCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Card(title: "Next \(min(model.upcoming.count, 7)) days", systemImage: "calendar") {
            VStack(spacing: 0) {
                ForEach(Array(model.upcoming.prefix(7))) { day in
                    UpcomingRow(day: day)
                    if day.id != model.upcoming.prefix(7).last?.id {
                        Divider().overlay(Theme.cardStroke)
                    }
                }
            }
            Text("Swipe or tap a day to skip it once.")
                .font(.caption2).foregroundStyle(Theme.faint)
        }
    }
}

struct UpcomingRow: View {
    @Environment(AppModel.self) private var model
    let day: PlannedDay

    private var isSkipped: Bool { day.status == .skipped }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Formatters.dayLabel(day.date.startOfDay()))
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                HStack(spacing: 4) {
                    Image(systemName: "sunrise").font(.caption2)
                    Text(day.solar.sunrise.map(Formatters.time) ?? "no sunrise")
                }
                .font(.caption).foregroundStyle(Theme.faint)
            }
            Spacer()
            statusView
        }
        .padding(.vertical, 10)
        .contentShape(.rect)
        .contextMenu {
            if day.status == .active || isSkipped {
                Button(isSkipped ? "Restore this day" : "Skip this day", systemImage: isSkipped ? "arrow.uturn.backward" : "forward.end") {
                    model.toggleSkip(day)
                }
            }
        }
        .onTapGesture {
            if day.status == .active || isSkipped { model.toggleSkip(day) }
        }
        .opacity(day.isActive ? 1 : 0.6)
    }

    @ViewBuilder
    private var statusView: some View {
        switch day.status {
        case .active:
            HStack(spacing: 6) {
                if day.wasClamped { Image(systemName: "arrow.left.and.right.square").font(.caption).foregroundStyle(Theme.sun) }
                Text(day.alarmTime.map(Formatters.time) ?? "—")
                    .font(.system(.title3, design: .rounded).weight(.medium)).monospacedDigit()
            }
        case .skipped:
            Label("Skipped", systemImage: "forward.end").font(.caption).foregroundStyle(Theme.faint)
        case .weekdayOff:
            Text("Off").font(.caption).foregroundStyle(Theme.faint)
        case .disabled:
            Text("Alarm off").font(.caption).foregroundStyle(Theme.faint)
        case .noSunEvent:
            Text("No sunrise").font(.caption).foregroundStyle(Theme.faint)
        }
    }
}
