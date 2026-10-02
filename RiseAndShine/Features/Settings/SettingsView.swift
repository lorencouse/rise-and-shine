import SwiftUI
import RiseCore

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var showReset = false
    @State private var testState: TestState = .idle

    private enum TestState: Equatable { case idle, scheduling, scheduled, failed(String) }

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            Form {
                Section {
                    Toggle(isOn: $model.settings.isEnabled) {
                        Label("Sunrise alarm", systemImage: "alarm.fill")
                    }
                }

                Section {
                    NavigationLink { WakeTimeSettingsView() } label: {
                        row("Wake time", value: model.settings.offsetDescription, systemImage: "sunrise.fill")
                    }
                    NavigationLink { SleepSettingsView() } label: {
                        row("Sleep & bedtime", value: Formatters.duration(minutes: model.settings.sleepGoalMinutes), systemImage: "bed.double.fill")
                    }
                    NavigationLink { SoundPickerView() } label: {
                        row("Alarm sound", value: displayName(model.settings.soundFile), systemImage: "speaker.wave.2.fill")
                    }
                    NavigationLink { NightstandSettingsView() } label: {
                        row("Nightstand", value: model.settings.sunriseGlowMinutes > 0
                            ? "Light \(Formatters.duration(minutes: model.settings.sunriseGlowMinutes)) before"
                            : "Clock only", systemImage: "moon.stars.fill")
                    }
                    .accessibilityIdentifier("settings.nightstandLink")
                } header: {
                    Text("Alarm")
                } footer: {
                    Text("Wake time and sleep are also one tap from the home screen.")
                }

                Section {
                    NavigationLink { WakeHistoryView() } label: {
                        row("Wake history", value: "\(model.alarms.history.completed.count) mornings", systemImage: "clock.arrow.circlepath")
                    }
                    .accessibilityIdentifier("settings.wakeHistoryLink")
                } header: {
                    Text("History")
                } footer: {
                    Text("Recorded on your phone from when the alarm rang, snoozed and stopped, and kept in your own iCloud so a new phone starts with it. Nothing is uploaded to us.")
                }

                Section {
                    NavigationLink { LocationSettingsView() } label: {
                        row("Location", value: model.settings.location?.name ?? "Not set", systemImage: "location.fill")
                    }
                } header: {
                    Text("Place")
                } footer: {
                    Text("Sunrise is computed from these coordinates. Following your device keeps the alarm right when you travel.")
                }

                Section {
                    Toggle(isOn: Binding(
                        get: { model.settings.calendarEventsEnabled },
                        set: { on in
                            model.settings.calendarEventsEnabled = on
                            if on { Task { await model.calendar.requestAuthorization(); await model.refresh() } }
                        }
                    )) {
                        Label("Sleep events in Calendar", systemImage: "calendar.badge.plus")
                    }
                    if model.settings.calendarEventsEnabled, model.calendar.authorization == .denied {
                        Button("Calendar access is off. Open Settings") { openSystemSettings() }.font(.footnote)
                    }
                } header: {
                    Text("Calendar")
                } footer: {
                    Text("One \"Sleep\" event per night, from bedtime to the alarm, in a \"Rise and Shine\" calendar you can hide or delete. Updated as sunrise moves.")
                }

                if model.health.authorization != .unavailable {
                    Section {
                        Toggle(isOn: Binding(
                            get: { model.settings.healthSleepEnabled },
                            set: { on in
                                model.settings.healthSleepEnabled = on
                                if on { Task { await model.health.requestAuthorization(); await model.refresh() } }
                            }
                        )) {
                            Label("Sleep from Health", systemImage: "heart.text.square")
                        }
                        if model.settings.healthSleepEnabled, let slept = model.lastNightSleepMinutes {
                            LabeledContent("Last night", value: Formatters.duration(minutes: slept))
                        }
                    } header: {
                        Text("Health")
                    } footer: {
                        Text("Reads sleep recorded by your Apple Watch or another app, to compare with your sleep goal. Read only; nothing is written to Health. If Health shows no data, check the app is allowed under Health › Sharing › Apps.")
                    }
                }

                Section("Permissions") {
                    permissionRow("Alarms", state: alarmState) {
                        Task { await model.alarms.requestAuthorization(); await model.refresh() }
                    }
                    permissionRow("Notifications", state: reminderState) {
                        Task { await model.reminders.requestAuthorization(); await model.refresh() }
                    }
                }

                Section {
                    Button {
                        testState = .scheduling
                        Task {
                            await model.testAlarm()
                            if let error = model.lastError {
                                testState = .failed(error)
                                Haptics.notify(.error)
                            } else {
                                testState = .scheduled
                                Haptics.notify(.success)
                                // Back to idle once the test has rung, so the row can be used again.
                                try? await Task.sleep(for: .seconds(20))
                                if testState == .scheduled { testState = .idle }
                            }
                        }
                    } label: {
                        HStack {
                            Label(testLabel, systemImage: "bell.and.waves.left.and.right")
                            Spacer()
                            if testState == .scheduled {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                    .accessibilityHidden(true)
                            }
                        }
                    }
                    .accessibilityIdentifier("settings.testAlarm")
                    .disabled(testState == .scheduling)
                    if case .failed(let message) = testState {
                        Text(message).font(.footnote).foregroundStyle(Theme.horizon)
                            .accessibilityLabel("Test alarm failed: \(message)")
                    }
                    Stepper("Schedule \(model.settings.horizonDays) days ahead", value: $model.settings.horizonDays, in: 3...30)
                } header: {
                    Text("Advanced")
                } footer: {
                    Text("Alarms are stored by iOS and ring even if the app is closed or the phone restarts. The app tops up future days whenever it opens or refreshes in the background. \(model.alarms.scheduledCount) alarm(s) currently scheduled.")
                }

                Section {
                    Button("Reset all settings", role: .destructive) { showReset = true }
                }

                Section("About") {
                    LabeledContent("Version", value: Bundle.main.versionString)
                    Text("Sunrise times are calculated on your device using the NOAA solar algorithm. Nothing leaves your phone.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.night)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .confirmationDialog("Reset all settings?", isPresented: $showReset, titleVisibility: .visible) {
                Button("Reset and cancel all alarms", role: .destructive) {
                    Task { await model.resetEverything(); dismiss() }
                }
            } message: {
                Text("This removes every scheduled alarm and reminder and returns you to setup.")
            }
        }
        .task { await model.reminders.refreshAuthorization(); model.alarms.refreshAuthorization() }
    }

    private var testLabel: String {
        switch testState {
        case .idle, .failed: model.settings.preAlarmMinutes > 0
            ? "Test: countdown now, ring in \(model.settings.preAlarmMinutes) min"
            : "Ring a test alarm in 10 seconds"
        case .scheduling: "Scheduling…"
        case .scheduled: "Test alarm set — lock your phone"
        }
    }

    private func row(_ title: String, value: String, systemImage: String) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
            Spacer()
            Text(value).foregroundStyle(.secondary).lineLimit(1)
        }
    }

    private enum PermissionState { case granted, denied, unknown }
    private var alarmState: PermissionState {
        switch model.alarms.authorization { case .authorized: .granted; case .denied: .denied; case .notDetermined: .unknown }
    }
    private var reminderState: PermissionState {
        switch model.reminders.authorization { case .authorized: .granted; case .denied: .denied; case .notDetermined: .unknown }
    }

    @ViewBuilder
    private func permissionRow(_ title: String, state: PermissionState, request: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
            Spacer()
            switch state {
            case .granted: Label("Allowed", systemImage: "checkmark.circle.fill").foregroundStyle(.green).labelStyle(.iconOnly)
                .accessibilityHidden(true)
            case .denied: Button("Open Settings") { openSystemSettings() }.font(.footnote)
            case .unknown: Button("Allow", action: request).font(.footnote)
            }
        }
        // One element ("Alarms, Allow, button"), not a bare "Allow" with the permission's
        // name a swipe away. Combining drops the child button's title from the label, so
        // the state/action goes in the value.
        .accessibilityElement(children: .combine)
        .accessibilityValue(state == .granted ? "Allowed" : state == .denied ? "Open Settings" : "Allow")
    }

    private func displayName(_ file: String) -> String {
        (file as NSString).deletingPathExtension
    }
}

extension Bundle {
    var versionString: String {
        let v = infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let b = infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(v) (\(b))"
    }
}

// MARK: - History

struct WakeHistoryView: View {
    @Environment(AppModel.self) private var model
    @State private var confirmClear = false

    var body: some View {
        let history = model.alarms.history
        Form {
            if history.completed.isEmpty {
                Section {
                    Text("Nothing yet. Mornings appear here after the alarm rings and you stop it.")
                        .accessibilityIdentifier("history.empty")
                        .foregroundStyle(.secondary)
                }
            } else {
                Section {
                    LabeledContent("Up with the alarm", value: "\(history.cleanStreak) in a row")
                    if let s = history.averageSnoozes { LabeledContent("Average snoozes", value: String(format: "%.1f", s)) }
                    if let l = history.averageLinger { LabeledContent("Ring to stop", value: Formatters.duration(seconds: l)) }
                    if let s = history.averageSleepMinutes {
                        LabeledContent("Average sleep", value: "\(Formatters.duration(minutes: s)) of \(Formatters.duration(minutes: model.settings.sleepGoalMinutes))")
                    }
                }
                Section("Mornings") {
                    ForEach(history.completed) { r in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(Formatters.dayLabel(r.date.startOfDay(in: model.settings.calendar), in: model.timeZone))
                                .font(.subheadline.weight(.medium))
                            HStack(spacing: 10) {
                                if let rang = r.rang { Label(Formatters.time(rang, in: model.timeZone), systemImage: "bell") }
                                if let stopped = r.stopped { Label(Formatters.time(stopped, in: model.timeZone), systemImage: "stop") }
                                if r.snoozes > 0 { Label("\(r.snoozes)", systemImage: "zzz") }
                                if let slept = r.sleepMinutes { Label(Formatters.duration(minutes: slept), systemImage: "moon.zzz") }
                            }
                            .font(.caption).foregroundStyle(.secondary)
                        }
                        // The icons carry the meaning ("bell 6:30, stop 6:34"), so spell it out.
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(morningDescription(r))
                    }
                }
                Section {
                    Button("Clear history", role: .destructive) { confirmClear = true }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.night)
        .navigationTitle("Wake history")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Clear wake history?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Clear", role: .destructive) { model.alarms.clearHistory() }
        }
    }

    private func morningDescription(_ r: WakeRecord) -> String {
        var parts = [Formatters.dayLabel(r.date.startOfDay(in: model.settings.calendar), in: model.timeZone)]
        if let rang = r.rang { parts.append("rang \(Formatters.time(rang, in: model.timeZone))") }
        if let stopped = r.stopped { parts.append("stopped \(Formatters.time(stopped, in: model.timeZone))") }
        if r.snoozes > 0 { parts.append("snoozed \(r.snoozes) \(r.snoozes == 1 ? "time" : "times")") }
        if let slept = r.sleepMinutes { parts.append("slept \(Formatters.duration(minutes: slept))") }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Wake time

struct WakeTimeSettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Form {
            Section {
                Picker("Relative to", selection: $model.settings.anchor) {
                    ForEach(SunAnchor.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Text(model.settings.anchor.detail).font(.footnote).foregroundStyle(.secondary)
                OffsetPicker(offsetMinutes: $model.settings.offsetMinutes, anchorTitle: model.settings.anchor.title)
            } header: {
                Text("Wake up")
            } footer: {
                if let p = model.preview(model.settings, on: model.settings.calendar.date(byAdding: .day, value: 1, to: .now) ?? .now),
                   let t = AlarmPlanner.alarmInstant(settings: model.settings, day: p.solar).time {
                    Text("Tomorrow that's \(Formatters.time(t, in: model.timeZone))\(p.wasClamped ? ", after the wake window is applied" : "").")
                }
            }

            Section {
                Toggle("Keep alarm within a window", isOn: $model.settings.clampEnabled)
                if model.settings.clampEnabled {
                    ClockTimeRow(title: "No earlier than", time: $model.settings.earliest)
                    ClockTimeRow(title: "No later than", time: $model.settings.latest)
                }
            } header: {
                Text("Wake window")
            } footer: {
                Text("Sunrise drifts by hours across the year. The window stops the alarm from ringing at 4:30 in June or 8:30 in December. Where the sun never rises, the alarm falls back to the latest time.")
            }

            Section {
                WeekdayPicker(selection: $model.settings.activeWeekdays)
                    .listRowBackground(Color.clear)
            } header: {
                Text("Days")
            } footer: {
                if model.settings.activeWeekdays.isEmpty { Text("No days selected: the alarm will never ring.") }
            }

            Section("Snooze") {
                Stepper("\(model.settings.snoozeMinutes) minutes", value: $model.settings.snoozeMinutes, in: 1...30)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.night)
        .navigationTitle("Wake time")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ClockTimeRow: View {
    let title: String
    @Binding var time: ClockTime

    private var dateBinding: Binding<Date> {
        Binding(
            get: { time.date(on: DateKey(date: .now)) },
            set: { d in
                let c = Calendar.current.dateComponents([.hour, .minute], from: d)
                time = ClockTime(hour: c.hour ?? 0, minute: c.minute ?? 0)
            }
        )
    }

    var body: some View {
        DatePicker(title, selection: dateBinding, displayedComponents: .hourAndMinute)
    }
}

// MARK: - Sleep

struct SleepSettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Form {
            Section {
                DurationPicker(minutes: $model.settings.sleepGoalMinutes)
            } header: {
                Text("Sleep goal")
            } footer: {
                if let next = model.nextAlarm, let bed = next.bedtime {
                    Text("For your next alarm, bedtime is \(Formatters.time(bed, in: model.timeZone)).")
                }
            }
            Section {
                Toggle("Wind-down and bedtime reminders", isOn: $model.settings.remindersEnabled)
                if model.settings.remindersEnabled {
                    Stepper("Wind down \(model.settings.windDownMinutes) min before bed", value: $model.settings.windDownMinutes, in: 5...120, step: 5)
                }
            } header: {
                Text("Reminders")
            } footer: {
                Text("Reminders are normal notifications. Unlike the alarm they respect Focus modes, so a Sleep Focus will quiet them.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.night)
        .navigationTitle("Sleep & bedtime")
        .navigationBarTitleDisplayMode(.inline)
    }
}
