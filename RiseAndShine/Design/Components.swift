import SwiftUI

/// Frosted card used across the app.
struct Card<Content: View>: View {
    var title: String? = nil
    var systemImage: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Label {
                    Text(title.uppercased())
                        .font(.label.weight(.semibold))
                        .tracking(1.2)
                } icon: {
                    if let systemImage { Image(systemName: systemImage) }
                }
                .foregroundStyle(Theme.faint)
                .labelStyle(.titleAndIcon)
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: .rect(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Theme.cardStroke))
    }
}

/// Large filled call-to-action.
struct PrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage { Image(systemName: systemImage) }
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
                if let systemImage { Image(systemName: systemImage) }
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
            Text(value)
                .font(emphasis ? .bigTime : .system(.title3, design: .rounded).weight(.medium))
                .foregroundStyle(emphasis ? Theme.sun : .white)
                .monospacedDigit()
        }
    }
}

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
                    if on { selection.remove(day) } else { selection.insert(day) }
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

            Picker("Direction", selection: Binding(get: { isBefore }, set: { set(before: $0, hours: hours, minutes: minutes) })) {
                Text("Before \(anchorTitle.lowercased())").tag(true)
                Text("After \(anchorTitle.lowercased())").tag(false)
            }
            .pickerStyle(.segmented)
        }
    }
}

/// Hours + minutes wheel for durations like the sleep goal.
struct DurationPicker: View {
    @Binding var minutes: Int
    var hourRange: ClosedRange<Int> = 4...12
    var minuteStep = 15

    var body: some View {
        HStack(spacing: 0) {
            Picker("Hours", selection: Binding(get: { minutes / 60 }, set: { minutes = $0 * 60 + minutes % 60 })) {
                ForEach(Array(hourRange), id: \.self) { Text("\($0) hr").tag($0) }
            }
            Picker("Minutes", selection: Binding(get: { minutes % 60 }, set: { minutes = (minutes / 60) * 60 + $0 })) {
                ForEach(Array(stride(from: 0, to: 60, by: minuteStep)), id: \.self) { Text("\($0) min").tag($0) }
            }
        }
        .pickerStyle(.wheel)
        .frame(height: 130)
    }
}

/// Banner shown when a permission blocks core functionality.
struct PermissionBanner: View {
    let title: String
    let message: String
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Theme.sun)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.cardTitle)
                Text(message).font(.footnote).foregroundStyle(Theme.mist)
                Button(buttonTitle, action: action)
                    .font(.footnote.weight(.semibold))
                    .padding(.top, 4)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Theme.horizon.opacity(0.25), in: .rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.horizon.opacity(0.5)))
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
