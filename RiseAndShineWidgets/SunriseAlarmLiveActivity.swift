import SwiftUI
import WidgetKit
import ActivityKit
import AlarmKit

/// The Lock Screen / Dynamic Island presentation for our AlarmKit alarms.
/// iOS drives the state (alert, snoozing countdown, paused); we only render it.
struct SunriseAlarmLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<SunriseAlarmMetadata>.self) { context in
            LockScreenView(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(WidgetTheme.night)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(phase(context).label, systemImage: phase(context).icon)
                        .font(.caption).foregroundStyle(WidgetTheme.sun)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    StateText(state: context.state, compact: true)
                        .font(.title3.monospacedDigit())
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.attributes.metadata?.offsetDescription ?? "Rise and Shine")
                        .font(.caption).foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: "sunrise.fill").foregroundStyle(WidgetTheme.sun)
            } compactTrailing: {
                StateText(state: context.state, compact: true).font(.caption.monospacedDigit())
            } minimal: {
                Image(systemName: "alarm.fill").foregroundStyle(WidgetTheme.sun)
            }
            .keylineTint(WidgetTheme.sunrise)
        }
    }
}

/// What the countdown means right now. AlarmKit uses the same countdown mode for the
/// pre-alarm and for snooze; the metadata's alarm time tells them apart.
struct ActivityPhase {
    let label: String
    let icon: String

    init(state: AlarmPresentationState, metadata: SunriseAlarmMetadata?) {
        switch state.mode {
        case .countdown(let c):
            if let alarmTime = metadata?.alarmTime, abs(c.fireDate.timeIntervalSince(alarmTime)) < 2 {
                label = "Sunrise soon"; icon = "sunrise"
            } else {
                label = "Snoozing"; icon = "zzz"
            }
        case .paused:
            label = "Paused"; icon = "pause.circle"
        default:
            label = "Sunrise"; icon = "sunrise.fill"
        }
    }
}

private func phase(_ context: ActivityViewContext<AlarmAttributes<SunriseAlarmMetadata>>) -> ActivityPhase {
    ActivityPhase(state: context.state, metadata: context.attributes.metadata)
}

private struct LockScreenView: View {
    let attributes: AlarmAttributes<SunriseAlarmMetadata>
    let state: AlarmPresentationState

    private var phase: ActivityPhase { ActivityPhase(state: state, metadata: attributes.metadata) }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: phase.icon)
                .font(.system(size: 34))
                .foregroundStyle(WidgetTheme.sunGradient)
            VStack(alignment: .leading, spacing: 4) {
                Text(attributes.presentation.alert.title)
                    .font(.headline)
                if let meta = attributes.metadata {
                    Text(phase.label == "Sunrise" ? meta.offsetDescription : "\(phase.label) · \(meta.offsetDescription)")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            Spacer()
            StateText(state: state, compact: false)
                .font(.title2.monospacedDigit().weight(.medium))
        }
        .padding()
        .foregroundStyle(.white)
    }
}

/// Renders the remaining snooze time, paused time, or "Ringing".
private struct StateText: View {
    let state: AlarmPresentationState
    let compact: Bool

    var body: some View {
        switch state.mode {
        case .countdown(let countdown):
            Text(timerInterval: Date.now...countdown.fireDate, countsDown: true)
                .frame(maxWidth: compact ? 60 : 120, alignment: .trailing)
        case .paused(let paused):
            let remaining = max(0, paused.totalCountdownDuration - paused.previouslyElapsedDuration)
            Text(Duration.seconds(remaining).formatted(.time(pattern: .minuteSecond)))
        case .alert:
            Text(compact ? "Now" : "Ringing")
        @unknown default:
            Text("")
        }
    }
}

enum WidgetTheme {
    static let night = Color(red: 0.05, green: 0.06, blue: 0.14)
    static let sunrise = Color(red: 0.98, green: 0.62, blue: 0.24)
    static let sun = Color(red: 1.00, green: 0.84, blue: 0.45)
    static var sunGradient: LinearGradient {
        LinearGradient(colors: [sun, sunrise], startPoint: .top, endPoint: .bottom)
    }
}
