# Rise and Shine

A sunrise alarm clock for iPhone. Choose an offset from sunrise (or dawn, or first light) once, and the alarm follows the sun through the year. Real alarms via **AlarmKit** (iOS 26+): they ring through Silent mode and Focus, show the full-screen Lock Screen alert with Snooze/Stop, and appear on Apple Watch and in the Dynamic Island.

Sunrise is computed on-device with the NOAA solar algorithm. No network, no account, no analytics.

## Requirements

- Xcode 26 or newer (the Command Line Tools alone cannot build iOS apps).
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`.
- An Apple Developer account for on-device testing and App Store distribution.
- A physical iPhone on iOS 26 for alarm testing. The simulator can run the UI but AlarmKit alerts and Live Activities should be verified on hardware.

## Getting started

```sh
xcodegen generate          # writes RiseAndShine.xcodeproj (git-ignored)
open RiseAndShine.xcodeproj
```

Then in Xcode select your team under *Signing & Capabilities* for both the app and the widget extension (or set `DEVELOPMENT_TEAM` in `project.yml`). The App Group `group.com.lomaco.riseandshine` must exist on your developer account; Xcode creates it automatically with automatic signing.

## Layout

| Path | What |
| --- | --- |
| `project.yml` | Single source of truth for targets, bundle ids, Info.plist keys and entitlements. Edit this, never the generated project. |
| `Packages/RiseCore` | Pure-Foundation Swift package: `SolarCalculator` (NOAA), `AlarmPlanner`, `AlarmSettings`, `DateKey`. Fully unit-tested and buildable without Xcode. |
| `RiseAndShine/` | The iOS app (SwiftUI). `App/` root and `AppModel`; `Services/` AlarmKit, notifications, location, background refresh; `Features/` Home, Settings, Onboarding; `Design/` theme and components. |
| `RiseAndShineWidgets/` | Widget extension: the AlarmKit Live Activity (Lock Screen / Dynamic Island) and a Next Alarm home/lock screen widget. |
| `Shared/` | Files compiled into both the app and the widget: App Group paths, shared JSON store, alarm metadata. |
| `RiseAndShine/Resources/AlarmSounds` | Bundled alarm sounds (CAF). |

## How alarms work

1. `AppModel.recompute()` builds a `PlannedDay` for each of the next 14 days: sun events, alarm time (with the wake-window clamp), bedtime and wind-down.
2. `AlarmScheduler.sync` reconciles those with the system: one fixed-date AlarmKit alarm per active morning, cancelling days that were skipped or fell out of the window. The day → alarm-id map lives in the App Group.
3. Alarms belong to iOS once scheduled, so they survive the app being killed or the phone restarting. The app extends the horizon on every launch and via Background App Refresh.
4. Wind-down and bedtime reminders are ordinary time-sensitive notifications (they respect a Sleep Focus on purpose).

## Testing the core without Xcode

```sh
cd Packages/RiseCore
swift run RiseCoreCheck     # prints ✓/✗ against NOAA reference values
```

With Xcode installed, `swift test` (or ⌘U in Xcode) runs the full Swift Testing suite.

## Release checklist

- [ ] Set `DEVELOPMENT_TEAM` and confirm bundle ids in `project.yml`.
- [ ] Replace the 1024×1024 app icon in `Assets.xcassets/AppIcon.appiconset` if desired.
- [ ] Test on device: alarm rings in Silent + Sleep Focus, snooze countdown shows in Dynamic Island, widget updates after an alarm passes.
- [ ] App Store Connect: privacy label "Data Not Collected"; Location (precise) used for app functionality only.
- [ ] Bump `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` in `project.yml`, regenerate, archive.
