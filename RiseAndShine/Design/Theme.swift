import SwiftUI

/// Dawn palette. The app commits to a single dark look: it's used at night and first
/// thing in the morning, so a bright UI would be unwelcome.
nonisolated enum Theme {
    static let night = Color(red: 0.05, green: 0.06, blue: 0.14)        // deep indigo
    static let dusk = Color(red: 0.16, green: 0.13, blue: 0.32)         // violet
    static let horizon = Color(red: 0.86, green: 0.36, blue: 0.30)      // coral
    static let sunrise = Color(red: 0.98, green: 0.62, blue: 0.24)      // warm orange
    static let sun = Color(red: 1.00, green: 0.84, blue: 0.45)          // pale gold
    static let moon = Color(red: 0.62, green: 0.70, blue: 0.98)         // cool blue, for sleep

    static let mist = Color.white.opacity(0.72)
    static let faint = Color.white.opacity(0.45)
    static let card = Color.white.opacity(0.08)
    static let cardStroke = Color.white.opacity(0.10)
    /// Slightly lifted surface for the hero, so it reads above the ordinary cards.
    static let hero = Color.white.opacity(0.12)
    static let heroStroke = Color.white.opacity(0.16)

    static var skyGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: night, location: 0.0),
                .init(color: dusk, location: 0.55),
                .init(color: horizon.opacity(0.55), location: 0.95),
                .init(color: sunrise.opacity(0.35), location: 1.0)
            ],
            startPoint: .top, endPoint: .bottom
        )
    }

    static var sunGradient: LinearGradient {
        LinearGradient(colors: [sun, sunrise], startPoint: .top, endPoint: .bottom)
    }
}

/// Layout rhythm. One place to change the spacing scale, so cards, stacks and screens
/// stay in step with each other.
nonisolated enum Metrics {
    static let screenPadding: CGFloat = 20
    /// Between top-level sections on Home.
    static let sectionGap: CGFloat = 14
    /// Between rows inside a card.
    static let rowGap: CGFloat = 12
    static let cardPadding: CGFloat = 16
    static let cardRadius: CGFloat = 22
    static let chipRadius: CGFloat = 14
    /// Apple's minimum comfortable hit target.
    static let tapTarget: CGFloat = 44
}

nonisolated enum Motion {
    static let card = Animation.spring(response: 0.35, dampingFraction: 0.85)
    static let quick = Animation.easeInOut(duration: 0.18)
    /// What Reduce Motion gets instead of either: a short fade, no spring and no travel.
    static let reduced = Animation.easeInOut(duration: 0.15)

    /// For `withAnimation` calls made outside a view, where the environment's
    /// `accessibilityReduceMotion` can't be read.
    @MainActor
    static func respectingReduceMotion(_ animation: Animation) -> Animation {
        UIAccessibility.isReduceMotionEnabled ? reduced : animation
    }
}

extension View {
    /// `.animation(_:value:)` that turns into `Motion.reduced` when Reduce Motion is on, so
    /// cards that grow or slide fade instead.
    func motion<V: Equatable>(_ animation: Animation, value: V) -> some View {
        modifier(ReduceMotionAnimation(animation: animation, value: value))
    }
}

private struct ReduceMotionAnimation<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animation: Animation
    let value: V

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? Motion.reduced : animation, value: value)
    }
}

/// Small wrapper so feedback is consistent and easy to remove.
@MainActor
enum Haptics {
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
}

struct DawnBackground: View {
    var body: some View {
        ZStack {
            Theme.skyGradient
            // A soft glow near the horizon.
            RadialGradient(colors: [Theme.sunrise.opacity(0.35), .clear],
                           center: .init(x: 0.5, y: 1.05), startRadius: 10, endRadius: 420)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Type ramp

extension Font {
    /// Big clock faces. Sizes come from `@ScaledMetric` at the call site so they follow
    /// Dynamic Type; these are the defaults at the standard size.
    static func displayTime(_ size: CGFloat = 68) -> Font { .system(size: size, weight: .thin, design: .rounded) }
    static func bigTime(_ size: CGFloat = 32) -> Font { .system(size: size, weight: .light, design: .rounded) }
    static let cardTitle = Font.system(.subheadline, design: .rounded).weight(.semibold)
    static let label = Font.system(.footnote, design: .rounded)
    /// All-caps section labels.
    static let eyebrow = Font.system(.caption, design: .rounded).weight(.semibold)
}
