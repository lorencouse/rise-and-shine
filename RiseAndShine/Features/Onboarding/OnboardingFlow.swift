import SwiftUI
import RiseCore

/// First-run setup. Edits a draft copy of the settings and commits at the end so a
/// half-finished setup never schedules anything.
struct OnboardingFlow: View {
    @Environment(AppModel.self) private var model
    @State private var step = 0
    @State private var draft = AlarmSettings()

    private let stepCount = 5

    var body: some View {
        ZStack {
            DawnBackground()
            VStack(spacing: 0) {
                ProgressDots(count: stepCount, index: step)
                    .padding(.top, 12)
                TabView(selection: $step) {
                    WelcomePage(next: advance).tag(0)
                    LocationPage(draft: $draft, next: advance).tag(1)
                    WakeTimePage(draft: $draft, next: advance).tag(2)
                    SleepPage(draft: $draft, next: advance).tag(3)
                    PermissionsPage(finish: finish).tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: step)
            }
        }
        .onAppear { draft = model.settings }
    }

    private func advance() {
        withAnimation { step = min(step + 1, stepCount - 1) }
    }

    private func finish() {
        model.settings = draft
        Task { await model.completeOnboarding() }
    }
}

private struct ProgressDots: View {
    let count: Int
    let index: Int
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == index ? Theme.sun : Color.white.opacity(0.25))
                    .frame(width: i == index ? 22 : 6, height: 6)
            }
        }
    }
}

private struct PageScaffold<Content: View>: View {
    let title: String
    let subtitle: String
    let systemImage: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 12)
            Image(systemName: systemImage)
                .font(.system(size: 52, weight: .thin))
                .foregroundStyle(Theme.sunGradient)
                .symbolRenderingMode(.hierarchical)
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                    .multilineTextAlignment(.center)
                Text(subtitle)
                    .font(.body).foregroundStyle(Theme.mist)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 28)
            content
            Spacer(minLength: 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }
}

// MARK: - Pages

private struct WelcomePage: View {
    let next: () -> Void
    var body: some View {
        PageScaffold(title: "Rise and Shine",
                     subtitle: "Wake with the sun, every day of the year. Set an offset from sunrise once, and your alarm follows the light.",
                     systemImage: "sun.horizon.fill") {
            VStack(alignment: .leading, spacing: 14) {
                feature("sunrise", "Alarm tracks sunrise", "Earlier in summer, later in winter, automatically.")
                feature("bell.badge.waves.left.and.right", "A real alarm", "Rings through Silent mode and Focus, with snooze on the Lock Screen.")
                feature("moon.zzz", "Bedtime that fits", "A wind-down nudge and bedtime based on your sleep goal.")
                feature("lock.shield", "Private by design", "Sunrise is computed on your phone. No account, no tracking.")
            }
            .padding(20)
            .background(Theme.card, in: .rect(cornerRadius: 20))
            Spacer()
            PrimaryButton(title: "Get started", action: next)
        }
    }

    private func feature(_ icon: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).foregroundStyle(Theme.sun).frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.cardTitle)
                Text(text).font(.footnote).foregroundStyle(Theme.mist)
            }
        }
    }
}

private struct LocationPage: View {
    @Environment(AppModel.self) private var model
    @Binding var draft: AlarmSettings
    let next: () -> Void
    @State private var error: String?
    @State private var query = ""
    @State private var results: [SavedLocation] = []
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        PageScaffold(title: "Where do you wake up?",
                     subtitle: "Sunrise depends on where you are. Use your location, or pick a city.",
                     systemImage: "location.fill") {
            VStack(spacing: 12) {
                if let loc = draft.location {
                    Card {
                        HStack {
                            Image(systemName: loc.followsDevice ? "location.fill" : "mappin")
                            VStack(alignment: .leading) {
                                Text(loc.name).font(.cardTitle)
                                if let preview = model.preview(draft), let s = preview.solar.sunrise {
                                    Text("Sunrise today \(Formatters.time(s))").font(.footnote).foregroundStyle(Theme.mist)
                                }
                            }
                            Spacer()
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.sun)
                        }
                    }
                }
                SecondaryButton(title: model.location.isLocating ? "Locating…" : "Use my current location", systemImage: "location") {
                    Task {
                        do { draft.location = try await model.location.currentLocation(); error = nil }
                        catch { self.error = error.localizedDescription }
                    }
                }
                if let error { Text(error).font(.footnote).foregroundStyle(Theme.horizon) }

                TextField("Or search for a city", text: $query)
                    .textFieldStyle(.plain)
                    .padding(14)
                    .background(Theme.card, in: .capsule)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .onChange(of: query) { _, q in
                        searchTask?.cancel()
                        searchTask = Task {
                            try? await Task.sleep(for: .milliseconds(350))
                            guard !Task.isCancelled else { return }
                            results = await model.location.search(q)
                        }
                    }
                ForEach(results.prefix(4), id: \.name) { place in
                    Button {
                        draft.location = place
                        query = ""; results = []
                    } label: {
                        HStack {
                            Text(place.name)
                            Spacer()
                            Image(systemName: "plus.circle")
                        }
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(Theme.card, in: .rect(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer()
            PrimaryButton(title: "Next", isEnabled: draft.location != nil, action: next)
        }
    }
}

private struct WakeTimePage: View {
    @Environment(AppModel.self) private var model
    @Binding var draft: AlarmSettings
    let next: () -> Void

    var body: some View {
        PageScaffold(title: "When do you want to wake?",
                     subtitle: "Pick how long before or after \(draft.anchor.title.lowercased()) your alarm should ring.",
                     systemImage: "alarm.fill") {
            VStack(spacing: 12) {
                Picker("Relative to", selection: $draft.anchor) {
                    ForEach(SunAnchor.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)

                Card {
                    OffsetPicker(offsetMinutes: $draft.offsetMinutes, anchorTitle: draft.anchor.title)
                }

                if let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: .now),
                   let p = model.preview(draft, on: tomorrow) {
                    let inst = AlarmPlanner.alarmInstant(settings: draft, day: p.solar)
                    HStack {
                        StatView(title: "\(draft.anchor.title) tomorrow", value: p.solar.time(for: draft.anchor).map(Formatters.time) ?? "—", systemImage: "sunrise")
                        Spacer()
                        StatView(title: "Alarm", value: inst.time.map(Formatters.time) ?? "—", systemImage: "alarm", emphasis: true)
                    }
                    .padding(.horizontal, 8)
                    if inst.clamped {
                        Text("Kept inside your wake window (\(windowText)). You can change the window in Settings.")
                            .font(.caption).foregroundStyle(Theme.sun)
                    }
                }
            }
            Spacer()
            PrimaryButton(title: "Next", action: next)
        }
    }

    private var windowText: String {
        let key = DateKey(date: .now)
        return "\(Formatters.time(draft.earliest.date(on: key)))–\(Formatters.time(draft.latest.date(on: key)))"
    }
}

private struct SleepPage: View {
    @Environment(AppModel.self) private var model
    @Binding var draft: AlarmSettings
    let next: () -> Void

    var body: some View {
        PageScaffold(title: "How much sleep?",
                     subtitle: "We'll work backwards from your alarm to suggest a bedtime and a wind-down reminder.",
                     systemImage: "moon.zzz.fill") {
            VStack(spacing: 12) {
                Card { DurationPicker(minutes: $draft.sleepGoalMinutes) }
                Card {
                    Toggle("Bedtime reminders", isOn: $draft.remindersEnabled)
                    if draft.remindersEnabled {
                        Stepper("Wind down \(draft.windDownMinutes) min before", value: $draft.windDownMinutes, in: 5...120, step: 5)
                            .font(.footnote)
                    }
                }
                WeekdayPicker(selection: $draft.activeWeekdays)
                Text("Days the alarm rings").font(.caption).foregroundStyle(Theme.faint)

                if let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: .now),
                   let p = model.preview(draft, on: tomorrow), let bed = p.bedtime {
                    Text("For tomorrow's alarm, bedtime tonight is \(Formatters.time(bed)).")
                        .font(.footnote).foregroundStyle(Theme.mist)
                }
            }
            Spacer()
            PrimaryButton(title: "Next", action: next)
        }
    }
}

private struct PermissionsPage: View {
    @Environment(AppModel.self) private var model
    let finish: () -> Void
    @State private var requesting = false

    var body: some View {
        PageScaffold(title: "One last thing",
                     subtitle: "Rise and Shine needs permission to ring alarms. Reminders are optional.",
                     systemImage: "bell.badge.fill") {
            VStack(spacing: 12) {
                permission("Alarms", detail: "Rings through Silent and Focus, like the Clock app.",
                           granted: model.alarms.authorization == .authorized,
                           denied: model.alarms.authorization == .denied) {
                    await model.alarms.requestAuthorization()
                }
                permission("Notifications", detail: "For wind-down and bedtime reminders.",
                           granted: model.reminders.authorization == .authorized,
                           denied: model.reminders.authorization == .denied) {
                    await model.reminders.requestAuthorization()
                }
            }
            Spacer()
            if model.alarms.authorization == .authorized {
                PrimaryButton(title: "Finish", systemImage: "checkmark", action: finish)
            } else if model.alarms.authorization == .denied {
                VStack(spacing: 10) {
                    SecondaryButton(title: "Open Settings to allow alarms", systemImage: "gear") { openSystemSettings() }
                    Button("Continue without alarms") { finish() }.font(.footnote).foregroundStyle(Theme.faint)
                }
            } else {
                PrimaryButton(title: requesting ? "Asking…" : "Allow alarms & reminders", systemImage: "bell", isEnabled: !requesting) {
                    requesting = true
                    Task {
                        await model.alarms.requestAuthorization()
                        await model.reminders.requestAuthorization()
                        requesting = false
                    }
                }
            }
        }
        .task { model.alarms.refreshAuthorization(); await model.reminders.refreshAuthorization() }
    }

    /// A tappable permission row. Tapping asks the system for that permission directly,
    /// or opens Settings when it was already denied, so the row is never a dead checkbox.
    private func permission(_ title: String, detail: String, granted: Bool, denied: Bool,
                            request: @escaping () async -> Void) -> some View {
        Button {
            guard !granted, !requesting else { return }
            if denied { openSystemSettings(); return }
            requesting = true
            Task {
                await request()
                requesting = false
            }
        } label: {
            Card {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(.cardTitle)
                        Text(detail).font(.footnote).foregroundStyle(Theme.mist)
                    }
                    Spacer()
                    Image(systemName: granted ? "checkmark.circle.fill" : denied ? "xmark.circle.fill" : "circle")
                        .foregroundStyle(granted ? .green : denied ? Theme.horizon : Theme.faint)
                        .font(.title3)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(granted || requesting)
        .accessibilityHint(granted ? "Already allowed" : denied ? "Opens Settings to allow" : "Asks for permission")
    }
}
