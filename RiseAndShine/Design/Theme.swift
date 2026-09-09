import SwiftUI

/// Dawn palette. The app commits to a single dark look: it's used at night and first
/// thing in the morning, so a bright UI would be unwelcome.
nonisolated enum Theme {
    static let night = Color(red: 0.05, green: 0.06, blue: 0.14)        // deep indigo
    static let dusk = Color(red: 0.16, green: 0.13, blue: 0.32)         // violet
    static let horizon = Color(red: 0.86, green: 0.36, blue: 0.30)      // coral
    static let sunrise = Color(red: 0.98, green: 0.62, blue: 0.24)      // warm orange
    static let sun = Color(red: 1.00, green: 0.84, blue: 0.45)          // pale gold
    static let mist = Color.white.opacity(0.72)
    static let faint = Color.white.opacity(0.45)
    static let card = Color.white.opacity(0.08)
    static let cardStroke = Color.white.opacity(0.10)

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
    static let displayTime = Font.system(size: 64, weight: .thin, design: .rounded)
    static let bigTime = Font.system(size: 34, weight: .light, design: .rounded)
    static let cardTitle = Font.system(.subheadline, design: .rounded).weight(.semibold)
    static let label = Font.system(.footnote, design: .rounded)
}
