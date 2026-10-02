import Foundation

/// A colour on the dawn ramp, in linear-ish sRGB components 0...1. Plain `Double`s rather
/// than a `Color` so this file stays Foundation-only and testable without SwiftUI.
public struct GlowColor: Sendable, Equatable {
    public var red: Double
    public var green: Double
    public var blue: Double

    public init(_ red: Double, _ green: Double, _ blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    static func lerp(_ a: GlowColor, _ b: GlowColor, _ t: Double) -> GlowColor {
        GlowColor(a.red + (b.red - a.red) * t,
                  a.green + (b.green - a.green) * t,
                  a.blue + (b.blue - a.blue) * t)
    }
}

/// Everything the screen needs to render the artificial sunrise at one instant.
public struct GlowStage: Sendable, Equatable {
    /// 0 at the start of the ramp, 1 at the alarm and for the hold after it.
    public var progress: Double
    /// Screen brightness to request, 0...1.
    public var brightness: Double
    /// The light at the horizon: ember through orange to a warm white.
    public var horizon: GlowColor
    /// The sky above it, which stays much darker until late in the ramp.
    public var sky: GlowColor
    /// True once the alarm time has passed and the ramp is holding at full.
    public var isHolding: Bool

    public init(progress: Double, brightness: Double, horizon: GlowColor, sky: GlowColor, isHolding: Bool) {
        self.progress = progress
        self.brightness = brightness
        self.horizon = horizon
        self.sky = sky
        self.isHolding = isHolding
    }
}

/// The gradual screen sunrise: a light that starts near-black and reaches full at the
/// alarm, so you surface before the sound rather than out of it.
///
/// Pure arithmetic over `now`, deliberately: the view samples it on a timer and the tests
/// sample it at chosen instants, and neither needs a clock of its own.
public enum SunriseGlow {

    /// How long the ramp stays at full after the alarm time, so the room is still lit
    /// while you stop the alarm and get up.
    public static let holdMinutes = 30

    /// The dimmest the screen goes at the very start. Not zero: a black screen in a dark
    /// room reads as "off", and the point is to be visibly, faintly getting lighter.
    public static let minBrightness = 0.015

    // The ramp, as stops on `progress`. Night is barely blue; the horizon runs red →
    // orange → warm white, which is roughly what the eastern sky actually does.
    private static let horizonStops: [(Double, GlowColor)] = [
        (0.00, GlowColor(0.10, 0.06, 0.16)),
        (0.35, GlowColor(0.45, 0.13, 0.18)),
        (0.65, GlowColor(0.88, 0.36, 0.16)),
        (0.85, GlowColor(0.99, 0.62, 0.24)),
        (1.00, GlowColor(1.00, 0.88, 0.68))
    ]

    private static let skyStops: [(Double, GlowColor)] = [
        (0.00, GlowColor(0.02, 0.02, 0.05)),
        (0.45, GlowColor(0.08, 0.06, 0.16)),
        (0.75, GlowColor(0.24, 0.16, 0.32)),
        (1.00, GlowColor(0.72, 0.60, 0.56))
    ]

    /// When the ramp begins for an alarm at `alarm`.
    public static func start(alarm: Date, durationMinutes: Int) -> Date? {
        guard durationMinutes > 0 else { return nil }
        return alarm.addingTimeInterval(-Double(durationMinutes) * 60)
    }

    /// How far along the ramp `now` is, or `nil` when the glow should not be showing at
    /// all — it is switched off, the alarm is still further out than the ramp, or the
    /// hold after the alarm has expired.
    public static func progress(now: Date, alarm: Date, durationMinutes: Int) -> Double? {
        guard durationMinutes > 0, let start = start(alarm: alarm, durationMinutes: durationMinutes) else { return nil }
        if now < start { return nil }
        if now > alarm.addingTimeInterval(Double(holdMinutes) * 60) { return nil }
        if now >= alarm { return 1 }
        let elapsed = now.timeIntervalSince(start)
        let total = alarm.timeIntervalSince(start)
        guard total > 0 else { return 1 }
        return min(max(elapsed / total, 0), 1)
    }

    /// The full stage to render, or `nil` outside the ramp.
    ///
    /// Brightness is squared against progress on purpose: perceived brightness is far
    /// from linear in the backlight, and a linear ramp reads as "already bright" within
    /// the first minute or two.
    public static func stage(now: Date, alarm: Date, durationMinutes: Int,
                             maxBrightness: Double) -> GlowStage? {
        guard let p = progress(now: now, alarm: alarm, durationMinutes: durationMinutes) else { return nil }
        let ceiling = min(max(maxBrightness, minBrightness), 1)
        let brightness = minBrightness + (ceiling - minBrightness) * p * p
        return GlowStage(progress: p,
                         brightness: brightness,
                         horizon: interpolate(horizonStops, at: p),
                         sky: interpolate(skyStops, at: p),
                         isHolding: now >= alarm)
    }

    private static func interpolate(_ stops: [(Double, GlowColor)], at p: Double) -> GlowColor {
        guard let first = stops.first, let last = stops.last else { return GlowColor(0, 0, 0) }
        if p <= first.0 { return first.1 }
        if p >= last.0 { return last.1 }
        for (lower, upper) in zip(stops, stops.dropFirst()) where p <= upper.0 {
            let span = upper.0 - lower.0
            let t = span > 0 ? (p - lower.0) / span : 0
            return GlowColor.lerp(lower.1, upper.1, t)
        }
        return last.1
    }
}
