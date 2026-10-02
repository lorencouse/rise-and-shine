import SwiftUI
import RiseCore

/// First-run setup. Edits a draft copy of the settings and commits at the end so a
/// half-finished setup never schedules anything.
struct OnboardingFlow: View {
    @Environment(AppModel.self) private var model
    @State private var step = 0
    @State private var draft = AlarmSettings()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let stepCount = 5

    /// Pages slide sideways; with Reduce Motion the step just changes.
    private var pageAnimation: Animation? { reduceMotion ? nil : .easeInOut }

    var body: some View {
        ZStack {
            DawnBackground()
            VStack(spacing: 0) {
                // A one-way flow with no way back is the classic onboarding trap: users
                // pick something wrong on step 2 and have to reinstall to fix it.
                ZStack {
                    ProgressDots(count: stepCount, index: step)
                    HStack {
                        Button {
                            withAnimation(pageAnimation) { step = max(step - 1, 0) }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Theme.mist)
                                .frame(width: Metrics.tapTarget, height: Metrics.tapTarget)
                        }
                        .opacity(step == 0 ? 0 : 1)
                        .disabled(step == 0)
                        .accessibilityLabel("Back")
                        Spacer()
                    }
                }
                .padding(.top, 4)
                .padding(.horizontal, 8)
                TabView(selection: $step) {
                    WelcomePage(next: advance).tag(0)
                    LocationPage(draft: $draft, next: advance).tag(1)
                    WakeTimePage(draft: $draft, next: advance).tag(2)
                    SleepPage(draft: $draft, next: advance).tag(3)
                    PermissionsPage(finish: finish).tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(pageAnimation, value: step)
            }
        }
        .onAppear { draft = model.settings }
    }

    private func advance() {
        withAnimation(pageAnimation) { step = min(step + 1, stepCount - 1) }
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(index + 1) of \(count)")
    }
}

private struct PageScaffold<Content: View>: View {
    let title: String
    let subtitle: String
    let systemImage: String
    @ViewBuilder var content: Content

    var body: some View {
        // Scrolling matters here: these pages carry wheel pickers and a search field, and
        // on a small phone with the keyboard up a fixed layout clips the primary button.
        // `minHeight` centres a short page without trapping a tall one.
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: systemImage)
                        .font(.system(size: 48, weight: .thin))
                        .foregroundStyle(Theme.sunGradient)
                        .symbolRenderingMode(.hierarchical)
                        .accessibilityHidden(true)
                    VStack(spacing: 8) {
                        Text(title)
                            .font(.system(.title, design: .rounded).weight(.semibold))
                            .multilineTextAlignment(.center)
                            .accessibilityAddTraits(.isHeader)
                        Text(subtitle)
                            .font(.subheadline).foregroundStyle(Theme.mist)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 24)
                    content
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Metrics.screenPadding)
                .padding(.vertical, 20)
                .frame(minHeight: proxy.size.height, alignment: .center)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollBounceBehavior(.basedOnSize)
        }
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
                feature("bell.and.waves.left.and.right.fill", "A real alarm", "Rings through Silent mode and Focus, with snooze on the Lock Screen.")
                feature("moon.zzz", "Bedtime that fits", "A wind-down nudge and bedtime based on your sleep goal.")
                feature("lock.shield", "Private by design", "Sunrise is computed on your phone. No account, no tracking.")
            }
            .padding(20)
            .background(Theme.card, in: .rect(cornerRadius: 20))
            PrimaryButton(title: "Get started", action: next)
        }
    }

    private func feature(_ icon: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).foregroundStyle(Theme.sun).frame(width: 26)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.cardTitle)
                Text(text).font(.footnote).foregroundStyle(Theme.mist)
            }
        }
        .accessibilityElement(children: .combine)
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
                                .accessibilityHidden(true)
                            VStack(alignment: .leading) {
                                Text(loc.name).font(.cardTitle)
                                if let preview = model.preview(draft), let s = preview.solar.sunrise {
                                    Text("Sunrise today \(Formatters.time(s, in: draft.timeZone))").font(.footnote).foregroundStyle(Theme.mist)
                                }
                            }
                            Spacer()
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.sun)
                                .accessibilityHidden(true)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Chosen: \(accessibilityDescription(loc))")
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
                ForEach(results.prefix(4), id: \.self) { place in
                    Button {
                        draft.location = place
                        query = ""; results = []
                    } label: {
                        HStack {
                            Text(place.name)
                            Spacer()
                            Image(systemName: "plus.circle")
                                .accessibilityHidden(true)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(Theme.card, in: .rect(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Chooses this city")
                }
            }
            PrimaryButton(title: "Next", isEnabled: draft.location != nil, action: next)
        }
    }

    private func accessibilityDescription(_ loc: SavedLocation) -> String {
        guard let preview = model.preview(draft), let s = preview.solar.sunrise else { return loc.name }
        return "\(loc.name), sunrise today \(Formatters.time(s, in: draft.timeZone))"
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

                if let tomorrow = draft.calendar.date(byAdding: .day, value: 1, to: .now),
                   let p = model.preview(draft, on: tomorrow) {
                    let inst = AlarmPlanner.alarmInstant(settings: draft, day: p.solar)
                    HStack {
                        StatView(title: "\(draft.anchor.title) tomorrow", value: p.solar.time(for: draft.anchor).map { Formatters.time($0, in: draft.timeZone) } ?? "—", systemImage: "sunrise")
                            .accessibilityElement(children: .combine)
                        Spacer()
                        StatView(title: "Alarm", value: inst.time.map { Formatters.time($0, in: draft.timeZone) } ?? "—", systemImage: "alarm", emphasis: true)
                            .accessibilityElement(children: .combine)
                    }
                    .padding(.horizontal, 8)
                    if inst.clamped {
                        Text("Kept inside your wake window (\(windowText)). You can change the window in Settings.")
                            .font(.caption).foregroundStyle(Theme.sun)
                    } else {
                        Text("Sunrise drifts by hours over the year, so the alarm stays inside a wake window of \(windowText). You can change it later.")
                            .font(.caption).foregroundStyle(Theme.faint)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            PrimaryButton(title: "Next", action: next)
        }
    }

    private var windowText: String {
        let calendar = draft.calendar
        let key = DateKey(date: .now, calendar: calendar)
        return "\(Formatters.time(draft.earliest.date(on: key, calendar: calendar), in: draft.timeZone))–\(Formatters.time(draft.latest.date(on: key, calendar: calendar), in: draft.timeZone))"
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

                if let tomorrow = draft.calendar.date(byAdding: .day, value: 1, to: .now),
                   let p = model.preview(draft, on: tomorrow), let bed = p.bedtime {
                    Text("For tomorrow's alarm, bedtime tonight is \(Formatters.time(bed, in: draft.timeZone)).")
                        .font(.footnote).foregroundStyle(Theme.mist)
                }
            }
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
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(granted || requesting)
        .accessibilityValue(granted ? "Allowed" : denied ? "Not allowed" : "Not asked yet")
        .accessibilityHint(granted ? "Already allowed" : denied ? "Opens Settings to allow" : "Asks for permission")
    }
}
