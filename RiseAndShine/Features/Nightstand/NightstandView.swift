import SwiftUI
import RiseCore

/// The screen you leave facing you overnight: a dim clock, the next alarm, and — in the
/// last stretch before it rings — the gradual sunrise that gives the app its name.
///
/// Two jobs that would otherwise be separate features share one screen because they
/// share one requirement: the display has to stay on, and the app has to own its
/// brightness. Everything is deliberately still; the only motion is the light.
struct NightstandView: View {
    /// Run a compressed one-minute sunrise instead of waiting for the real alarm, so the
    /// setting can be judged at the time of day you actually set it.
    var demo = false

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    private let screen = ScreenController.shared

    /// Sampled on a timer rather than derived from `TimelineView`, because the brightness
    /// side effect belongs in one place and views should not have side effects.
    @State private var stage: GlowStage?
    @State private var now = Date.now
    /// Controls fade out so the room goes dark; a tap brings them back.
    @State private var controlsShown = true
    @State private var hideTask: Task<Void, Never>?
    @State private var demoAlarm: Date?

    /// Every 5 s: fine for a clock shown to the minute, and smooth enough for a ramp
    /// measured in tens of minutes.
    private let tick = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            background
            content
        }
        .preferredColorScheme(.dark)
        .persistentSystemOverlays(.hidden)
        .statusBarHidden()
        .contentShape(.rect)
        .onTapGesture { revealControls() }
        .gesture(
            DragGesture(minimumDistance: 40)
                .onEnded { if $0.translation.height > 60 { dismiss() } }
        )
        .onAppear(perform: start)
        .onDisappear { hideTask?.cancel(); screen.endNightstand() }
        .onReceive(tick) { advance(to: $0) }
        // Brightness is a device-wide setting the system will not put back for us, so a
        // nightstand session that ends by switching apps has to return it too.
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: start()
            default: screen.endNightstand()
            }
        }
    }

    // MARK: Light

    /// Under the glow this *is* the wake-up light, so it fills the screen edge to edge
    /// with no card, no chrome and nothing bright enough to read as an interface.
    private var background: some View {
        ZStack {
            if let stage {
                LinearGradient(
                    colors: [color(stage.sky), color(stage.sky), color(stage.horizon)],
                    startPoint: .top, endPoint: .bottom
                )
                RadialGradient(colors: [color(stage.horizon).opacity(0.9), .clear],
                               center: .init(x: 0.5, y: 1.02),
                               startRadius: 10,
                               endRadius: 260 + 500 * stage.progress)
            } else {
                Color.black
            }
        }
        .ignoresSafeArea()
        .animation(reduceMotion ? nil : .easeInOut(duration: 2), value: stage)
    }

    private func color(_ c: GlowColor) -> Color {
        Color(red: c.red, green: c.green, blue: c.blue)
    }

    /// Text stays legible over both black and a bright dawn: near-white while dark, near-
    /// black once the light is up.
    private var ink: Color {
        let p = stage?.progress ?? 0
        return p > 0.7 ? Color.black.opacity(0.75) : Color.white.opacity(0.82 - 0.3 * p)
    }

    // MARK: Content

    private var content: some View {
        VStack(spacing: 10) {
            Spacer(minLength: 0)
            clock
            if let line = alarmLine {
                Text(line)
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(ink.opacity(0.85))
                    .accessibilityIdentifier("nightstand.alarm")
            }
            // The sunrise that matters at 2 am is the one you are about to wake for, not
            // the one that already happened today.
            if let sunrise = model.nextAlarm?.solar.sunrise ?? model.today?.solar.sunrise {
                Label(Formatters.time(sunrise, in: model.timeZone), systemImage: "sunrise")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(ink.opacity(0.6))
            }
            Spacer(minLength: 0)
            controls
        }
        .padding(.horizontal, Metrics.screenPadding)
        .padding(.bottom, 24)
    }

    private var clock: some View {
        Text(Formatters.time(now, in: model.timeZone))
            .font(.system(size: 92, weight: .thin, design: .rounded))
            .minimumScaleFactor(0.4)
            .lineLimit(1)
            .foregroundStyle(ink)
            .contentTransition(.numericText())
            .accessibilityLabel("The time is \(Formatters.time(now, in: model.timeZone))")
            .accessibilityIdentifier("nightstand.clock")
    }

    private var controls: some View {
        HStack {
            Button("Done") { dismiss() }
                .accessibilityIdentifier("nightstand.done")
            Spacer()
            if let stage, !demo {
                Text(stage.isHolding ? "Sunrise light" : "Sunrise light in progress")
                    .font(.caption)
            }
        }
        .font(.system(.footnote, design: .rounded))
        .foregroundStyle(ink.opacity(0.7))
        .opacity(controlsShown ? 1 : 0)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.4), value: controlsShown)
        // Hidden controls are still reachable by VoiceOver: they are dimmed for the room,
        // not removed from the screen.
        .accessibilityHidden(false)
    }

    private var alarmLine: String? {
        if demo { return "Preview" }
        guard model.settings.isEnabled, let next = model.nextAlarm, let time = next.alarmTime else {
            return "No alarm set"
        }
        return "Alarm \(Formatters.time(time, in: model.timeZone)) · in \(Formatters.countdown(to: time, from: now))"
    }

    // MARK: Behaviour

    private func start() {
        if demo, demoAlarm == nil { demoAlarm = Date.now.addingTimeInterval(60) }
        screen.beginNightstand(brightness: model.settings.nightstandBrightness)
        advance(to: .now)
        revealControls()
    }

    /// One place where the clock, the ramp and the backlight move together.
    private func advance(to date: Date) {
        now = date
        let next = currentStage(at: date)
        stage = next
        if demo, let demoAlarm, date > demoAlarm.addingTimeInterval(4) {
            dismiss()
            return
        }
        screen.setBrightness(next?.brightness ?? model.settings.nightstandBrightness)
    }

    private func currentStage(at date: Date) -> GlowStage? {
        if demo {
            guard let demoAlarm else { return nil }
            return SunriseGlow.stage(now: date, alarm: demoAlarm, durationMinutes: 1,
                                     maxBrightness: model.settings.sunriseGlowMaxBrightness)
        }
        guard model.settings.isEnabled,
              let alarm = model.nextAlarm?.alarmTime else { return nil }
        return SunriseGlow.stage(now: date, alarm: alarm,
                                 durationMinutes: model.settings.sunriseGlowMinutes,
                                 maxBrightness: model.settings.sunriseGlowMaxBrightness)
    }

    private func revealControls() {
        controlsShown = true
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(6))
            guard !Task.isCancelled else { return }
            controlsShown = false
        }
    }
}
