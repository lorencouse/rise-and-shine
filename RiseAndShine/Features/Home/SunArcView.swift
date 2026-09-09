import SwiftUI
import RiseCore

/// Today's sun path: an arc from sunrise to sunset with the current sun position,
/// the alarm marker, and twilight shading. Purely decorative but communicates at a
/// glance where the alarm lands relative to the light.
struct SunArcView: View {
    let day: SolarDay
    let alarmTime: Date?
    /// The location's zone. The arc's x-axis is a civil day *there*, so every instant has
    /// to be placed against that midnight, not the phone's.
    let timeZone: TimeZone
    var now: Date = .now

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            Canvas { ctx, size in
                draw(in: &ctx, size: size, now: context.date)
            }
            .frame(height: 150)
            .accessibilityLabel(accessibilityText)
        }
    }

    private var accessibilityText: String {
        var parts: [String] = []
        if let s = day.sunrise { parts.append("Sunrise \(Formatters.time(s, in: timeZone))") }
        if let s = day.sunset { parts.append("sunset \(Formatters.time(s, in: timeZone))") }
        if let a = alarmTime { parts.append("alarm \(Formatters.time(a, in: timeZone))") }
        return parts.joined(separator: ", ")
    }

    /// Maps an instant to 0…1 across the civil day.
    private func fraction(_ date: Date) -> CGFloat {
        let start = day.date.startOfDay(in: calendar)
        let f = date.timeIntervalSince(start) / 86400
        return CGFloat(min(max(f, 0), 1))
    }

    private func point(for f: CGFloat, in rect: CGRect) -> CGPoint {
        // A sine hump peaking at solar noon, flattened to the rect.
        let noonF = fraction(day.solarNoon)
        let riseF = day.sunrise.map(fraction) ?? noonF - 0.25
        let setF = day.sunset.map(fraction) ?? noonF + 0.25
        let halfWidth = max((setF - riseF) / 2, 0.05)
        let x = rect.minX + f * rect.width
        // Sun altitude proxy: cos of distance from noon normalised by half day length.
        let d = (f - noonF) / halfWidth
        let h = cos(d * .pi / 2)              // 1 at noon, 0 at rise/set, negative at night
        let y = rect.maxY - h * (rect.height * 0.85)
        return CGPoint(x: x, y: y)
    }

    private func draw(in ctx: inout GraphicsContext, size: CGSize, now: Date) {
        let inset: CGFloat = 12
        let rect = CGRect(x: inset, y: 16, width: size.width - inset * 2, height: size.height - 40)
        let horizonY = rect.maxY

        // Twilight. Drawn as a glow sitting on the horizon at dawn and dusk rather than as
        // vertical bands: hard-edged rectangles read as chart furniture, a glow reads as light.
        func glow(from a: Date?, to b: Date?, strength: Double) {
            guard let a, let b else { return }
            let x0 = rect.minX + fraction(a) * rect.width
            let x1 = rect.minX + fraction(b) * rect.width
            let centre = CGPoint(x: (x0 + x1) / 2, y: horizonY)
            let radius = max(abs(x1 - x0), 18)
            let box = CGRect(x: centre.x - radius, y: centre.y - radius,
                             width: radius * 2, height: radius * 2)
            ctx.fill(Path(ellipseIn: box),
                     with: .radialGradient(Gradient(colors: [Theme.sunrise.opacity(strength), .clear]),
                                           center: centre, startRadius: 0, endRadius: radius))
        }
        glow(from: day.astronomicalDawn, to: day.sunrise, strength: 0.16)
        glow(from: day.civilDawn, to: day.sunrise, strength: 0.20)
        glow(from: day.sunset, to: day.civilDusk, strength: 0.20)
        glow(from: day.sunset, to: day.astronomicalDusk, strength: 0.16)

        // Horizon
        var horizon = Path()
        horizon.move(to: CGPoint(x: rect.minX, y: horizonY))
        horizon.addLine(to: CGPoint(x: rect.maxX, y: horizonY))
        ctx.stroke(horizon, with: .color(.white.opacity(0.18)), lineWidth: 1)

        // Full path (faint) and lit path (bright, above horizon only)
        var full = Path()
        var lit = Path()
        let steps = 120
        for i in 0...steps {
            let f = CGFloat(i) / CGFloat(steps)
            let p = point(for: f, in: rect)
            if i == 0 { full.move(to: p) } else { full.addLine(to: p) }
            if p.y <= horizonY {
                if lit.isEmpty { lit.move(to: p) } else { lit.addLine(to: p) }
            }
        }
        ctx.stroke(full, with: .color(.white.opacity(0.10)), style: StrokeStyle(lineWidth: 1.5, dash: [3, 4]))
        ctx.stroke(lit, with: .linearGradient(Gradient(colors: [Theme.horizon, Theme.sun, Theme.horizon]),
                                              startPoint: CGPoint(x: rect.minX, y: 0),
                                              endPoint: CGPoint(x: rect.maxX, y: 0)),
                   style: StrokeStyle(lineWidth: 2.5, lineCap: .round))

        // Alarm marker
        if let alarmTime {
            let p = point(for: fraction(alarmTime), in: rect)
            let y = min(p.y, horizonY)
            var tick = Path()
            tick.move(to: CGPoint(x: p.x, y: y - 14))
            tick.addLine(to: CGPoint(x: p.x, y: horizonY + 4))
            ctx.stroke(tick, with: .color(.white.opacity(0.7)), style: StrokeStyle(lineWidth: 1.5, dash: [2, 3]))
            let bell = ctx.resolve(Image(systemName: "alarm.fill").symbolRenderingMode(.monochrome))
            ctx.draw(bell, at: CGPoint(x: p.x, y: y - 22))
            let label = ctx.resolve(Text(Formatters.time(alarmTime, in: timeZone)).font(.caption2.monospacedDigit()).foregroundStyle(Theme.mist))
            ctx.draw(label, at: CGPoint(x: p.x, y: horizonY + 14))
        }

        // Sunrise / sunset labels
        if let s = day.sunrise {
            let p = point(for: fraction(s), in: rect)
            let t = ctx.resolve(Text(Formatters.time(s, in: timeZone)).font(.caption2.monospacedDigit()).foregroundStyle(Theme.faint))
            ctx.draw(t, at: CGPoint(x: p.x, y: horizonY + 14), anchor: alarmTime == nil ? .center : .trailing)
        }
        if let s = day.sunset {
            let p = point(for: fraction(s), in: rect)
            let t = ctx.resolve(Text(Formatters.time(s, in: timeZone)).font(.caption2.monospacedDigit()).foregroundStyle(Theme.faint))
            ctx.draw(t, at: CGPoint(x: p.x, y: horizonY + 14))
        }

        // Sun (current position) — only if today
        if calendar.isDate(now, inSameDayAs: day.date.startOfDay(in: calendar)) {
            let p = point(for: fraction(now), in: rect)
            let above = p.y <= horizonY
            let radius: CGFloat = above ? 9 : 6
            let circle = Path(ellipseIn: CGRect(x: p.x - radius, y: p.y - radius, width: radius * 2, height: radius * 2))
            if above {
                let glow = Path(ellipseIn: CGRect(x: p.x - 18, y: p.y - 18, width: 36, height: 36))
                ctx.fill(glow, with: .radialGradient(Gradient(colors: [Theme.sun.opacity(0.6), .clear]),
                                                     center: p, startRadius: 0, endRadius: 18))
                ctx.fill(circle, with: .color(Theme.sun))
            } else {
                ctx.fill(circle, with: .color(.white.opacity(0.25)))
            }
        }
    }
}
