import SwiftUI

// MARK: - Surfaces

/// Frosted card used across the app. `accessory` puts an action (usually a button) on the
/// title row so a section's own control lives with its content instead of in Settings.
struct Card<Content: View, Accessory: View>: View {
    var title: String? = nil
    var systemImage: String? = nil
    var isHero = false
    @ViewBuilder var content: Content
    @ViewBuilder var accessory: Accessory

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.rowGap) {
            if title != nil || Accessory.self != EmptyView.self {
                HStack(alignment: .firstTextBaseline) {
                    if let title {
                        Label {
                            Text(title.uppercased())
                                .font(.eyebrow)
                                .tracking(1.2)
                        } icon: {
                            if let systemImage { Image(systemName: systemImage) }
                        }
                        .foregroundStyle(Theme.faint)
                        .labelStyle(.titleAndIcon)
                        // Read as a heading so the VoiceOver rotor can jump card to card.
                        .accessibilityAddTraits(.isHeader)
                    }
                    Spacer(minLength: 8)
                    accessory
                }
            }
            content
        }
        .padding(Metrics.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isHero ? Theme.hero : Theme.card, in: .rect(cornerRadius: Metrics.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.cardRadius)
                .strokeBorder(isHero ? Theme.heroStroke : Theme.cardStroke)
        )
    }
}

extension Card where Accessory == EmptyView {
    init(title: String? = nil, systemImage: String? = nil, isHero: Bool = false,
         @ViewBuilder content: () -> Content) {
        self.init(title: title, systemImage: systemImage, isHero: isHero,
                  content: content, accessory: { EmptyView() })
    }
}

// MARK: - Buttons

/// Large filled call-to-action.
struct PrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.impact()
            action()
        } label: {
            HStack(spacing: 8) {
                if let systemImage { Image(systemName: systemImage).accessibilityHidden(true) }
                Text(title).fontWeight(.semibold)
            }
            .font(.system(.body, design: .rounded))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Theme.sunGradient, in: .capsule)
            .foregroundStyle(Theme.night)
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.4)
    }
}

struct SecondaryButton: View {
    let title: String
    var systemImage: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage { Image(systemName: systemImage).accessibilityHidden(true) }
                Text(title)
            }
            .font(.system(.body, design: .rounded))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.card, in: .capsule)
            .overlay(Capsule().strokeBorder(Theme.cardStroke))
            .foregroundStyle(.white)
        }
    }
}

/// A tappable pill that both *shows* a setting and *is* the way to change it. Home uses
/// these so the two settings that define the app are one tap away, not four.
struct ControlChip<Label: View>: View {
    var systemImage: String
    var tint: Color = Theme.sun
    let action: () -> Void
    @ViewBuilder var label: Label

    var body: some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(.footnote)
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
                label
                    .font(.system(.footnote, design: .rounded).weight(.medium))
                    .foregroundStyle(.white)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.faint)
                    .accessibilityHidden(true)
            }
            .lineLimit(1)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Color.white.opacity(0.10), in: .rect(cornerRadius: Metrics.chipRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.chipRadius)
                    .strokeBorder(Color.white.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
    }
}

extension ControlChip where Label == Text {
    init(_ text: String, systemImage: String, tint: Color = Theme.sun, action: @escaping () -> Void) {
        self.init(systemImage: systemImage, tint: tint, action: action) { Text(text) }
    }
}

// MARK: - Values

/// A labelled value, e.g. "Sunrise  6:42 AM".
struct StatView: View {
    let title: String
    let value: String
    var systemImage: String? = nil
    var emphasis = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                if let systemImage { Image(systemName: systemImage).font(.caption) }
                Text(title)
            }
            .font(.label)
            .foregroundStyle(Theme.faint)
            .lineLimit(1)
            Text(value)
                .font(emphasis ? .bigTime() : .system(.title3, design: .rounded).weight(.medium))
                .foregroundStyle(emphasis ? Theme.sun : .white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Four-across stat rows crowd and truncate on small phones and at large type sizes.
/// A two-column grid keeps every value legible without scaling the text down.
struct MetricGrid: View {
    struct Item: Identifiable {
        let id = UUID()
        let title: String
        let value: String
        let systemImage: String
    }

    let items: [Item]
    var columns = 2

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: Metrics.rowGap, alignment: .leading),
                           count: columns),
            alignment: .leading,
            spacing: Metrics.rowGap
        ) {
            ForEach(items) { item in
                StatView(title: item.title, value: item.value, systemImage: item.systemImage)
                    .accessibilityElement(children: .combine)
            }
        }
    }
}

/// Wind down → bedtime → alarm as one connected strip, so the night reads as a single
/// span instead of three unrelated numbers.
struct SleepTimeline: View {
    struct Stop {
        let time: String
        let label: String
        let systemImage: String
        var tint: Color = .white
    }

    let stops: [Stop]
    /// Rendered under the strip, e.g. "8 hr in bed".
    var caption: String?

    var body: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .top) {
                // The stops are equal-width columns, so the outer dot centres sit one half
                // column in. Inset the rule by exactly that, or it overshoots the end dots.
                GeometryReader { proxy in
                    Capsule()
                        .fill(LinearGradient(colors: [Theme.moon.opacity(0.2), Theme.moon.opacity(0.55), Theme.sun],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(height: 2)
                        .padding(.horizontal, proxy.size.width / CGFloat(max(stops.count, 1) * 2))
                        .padding(.top, 5)
                }
                .frame(height: 12)
                .allowsHitTesting(false)

                HStack(alignment: .top, spacing: 0) {
                    ForEach(Array(stops.enumerated()), id: \.offset) { index, stop in
                        VStack(spacing: 6) {
                            Circle()
                                .fill(stop.tint)
                                .frame(width: 8, height: 8)
                                .overlay(Circle().stroke(Theme.night, lineWidth: 3))
                            Image(systemName: stop.systemImage)
                                .font(.caption)
                                .foregroundStyle(stop.tint.opacity(0.9))
                            Text(stop.time)
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(.white)
                            Text(stop.label)
                                .font(.caption2)
                                .foregroundStyle(Theme.faint)
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(stop.label) \(stop.time)")
                        .id(index)
                    }
                }
            }
            if let caption {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(Theme.mist)
            }
        }
    }
}

// MARK: - Weekdays

/// Seven tappable weekday chips. Uses Calendar weekday numbering (1 = Sunday).
struct WeekdayPicker: View {
    @Binding var selection: Set<Int>
    private let calendar = Calendar.current

    private var orderedWeekdays: [Int] {
        let first = calendar.firstWeekday
        return (0..<7).map { ((first - 1 + $0) % 7) + 1 }
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(orderedWeekdays, id: \.self) { day in
                let on = selection.contains(day)
                Button {
                    Haptics.selection()
                    withAnimation(Motion.respectingReduceMotion(Motion.quick)) {
                        if on { selection.remove(day) } else { selection.insert(day) }
                    }
                } label: {
                    Text(calendar.veryShortWeekdaySymbols[day - 1])
                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(on ? Theme.sunrise : Theme.card, in: .circle)
                        .foregroundStyle(on ? Theme.night : Theme.mist)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(calendar.weekdaySymbols[day - 1])
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }
}

/// Read-only "M T W T F" summary for the Home chips.
nonisolated enum WeekdaySummary {
    static func text(for selection: Set<Int>, calendar: Calendar = .current) -> String {
        if selection.isEmpty { return "No days" }
        if selection == Set(1...7) { return "Every day" }
        if selection == [2, 3, 4, 5, 6] { return "Weekdays" }
        if selection == [1, 7] { return "Weekends" }
        let first = calendar.firstWeekday
        let ordered = (0..<7).map { ((first - 1 + $0) % 7) + 1 }
        return ordered
            .filter(selection.contains)
            .map { calendar.veryShortWeekdaySymbols[$0 - 1] }
            .joined(separator: " ")
    }
}

// MARK: - Pickers

/// Wheel picker for a signed minute offset: direction + hours + minutes.
struct OffsetPicker: View {
    @Binding var offsetMinutes: Int
    let anchorTitle: String

    private var isBefore: Bool { offsetMinutes <= 0 }
    private var hours: Int { abs(offsetMinutes) / 60 }
    private var minutes: Int { abs(offsetMinutes) % 60 }

    private func set(before: Bool, hours: Int, minutes: Int) {
        let magnitude = hours * 60 + minutes
        offsetMinutes = before ? -magnitude : magnitude
    }

    var body: some View {
        VStack(spacing: 8) {
            Picker("Direction", selection: Binding(get: { isBefore }, set: { set(before: $0, hours: hours, minutes: minutes) })) {
                Text("Before \(anchorTitle.lowercased())").tag(true)
                Text("After \(anchorTitle.lowercased())").tag(false)
            }
            .pickerStyle(.segmented)

            HStack(spacing: 0) {
                Picker("Hours", selection: Binding(get: { hours }, set: { set(before: isBefore, hours: $0, minutes: minutes) })) {
                    ForEach(0..<4) { Text("\($0) hr").tag($0) }
                }
                Picker("Minutes", selection: Binding(get: { minutes }, set: { set(before: isBefore, hours: hours, minutes: $0) })) {
                    ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { Text("\($0) min").tag($0) }
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 130)
        }
    }
}

/// Hours + minutes wheel for durations like the sleep goal.
struct DurationPicker: View {
    @Binding var minutes: Int
    var hourRange: ClosedRange<Int> = 4...12
    var minuteStep = 15

    /// Widened to include the stored value, so a goal outside the default range still
    /// shows a selected row instead of a blank wheel.
    private var visibleHours: ClosedRange<Int> {
        let h = minutes / 60
        return min(hourRange.lowerBound, h)...max(hourRange.upperBound, h)
    }

    var body: some View {
        HStack(spacing: 0) {
            Picker("Hours", selection: Binding(get: { minutes / 60 }, set: { minutes = $0 * 60 + minutes % 60 })) {
                ForEach(Array(visibleHours), id: \.self) { Text("\($0) hr").tag($0) }
            }
            Picker("Minutes", selection: Binding(get: { minutes % 60 }, set: { minutes = (minutes / 60) * 60 + $0 })) {
                ForEach(Array(stride(from: 0, to: 60, by: minuteStep)), id: \.self) { Text("\($0) min").tag($0) }
            }
        }
        .pickerStyle(.wheel)
        .frame(height: 130)
    }
}

// MARK: - Status

/// Banner shown when a permission blocks core functionality. `isBlocking` distinguishes
/// "nothing will ring" (loud, coral) from "you could set this up" (quiet, gold).
struct PermissionBanner: View {
    let title: String
    let message: String
    let buttonTitle: String
    var isBlocking = true
    let action: () -> Void

    private var tint: Color { isBlocking ? Theme.horizon : Theme.sun }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isBlocking ? "exclamationmark.triangle.fill" : "info.circle.fill")
                    .foregroundStyle(tint)
                    .font(.body)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.cardTitle)
                        .foregroundStyle(.white)
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(Theme.mist)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(buttonTitle)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(tint)
                        .padding(.top, 3)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.faint)
                    .padding(.top, 3)
                    .accessibilityHidden(true)
            }
            .multilineTextAlignment(.leading)
            .padding(14)
            .background(tint.opacity(0.18), in: .rect(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(tint.opacity(0.45)))
        }
        .buttonStyle(.plain)
        .accessibilityHint(buttonTitle)
    }
}

extension View {
    /// Opens the app's page in Settings.
    func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
