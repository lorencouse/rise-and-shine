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
                } header: {
                    Text("Alarm")
                } footer: {
                    Text("Wake time and sleep are also one tap from the home screen.")
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
                            }
                        }
                    } label: {
                        HStack {
                            Label(testLabel, systemImage: "bell.and.waves.left.and.right")
                            Spacer()
                            if testState == .scheduled {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            }
                        }
                    }
                    .disabled(testState == .scheduling)
                    if case .failed(let message) = testState {
                        Text(message).font(.footnote).foregroundStyle(Theme.horizon)
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
        case .idle, .failed: "Ring a test alarm in 10 seconds"
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
            case .denied: Button("Open Settings") { openSystemSettings() }.font(.footnote)
            case .unknown: Button("Allow", action: request).font(.footnote)
            }
        }
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
