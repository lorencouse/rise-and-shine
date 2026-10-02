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

Then in Xcode select your team under *Signing & Capabilities* for both the app and the widget extension (or set `DEVELOPMENT_TEAM` in `project.yml`). The App Group `group.com.lomaco.riseandshine.shared` must exist on your developer account; Xcode creates it automatically with automatic signing.

## Layout

| Path | What |
| --- | --- |
| `project.yml` | Single source of truth for targets, bundle ids, Info.plist keys and entitlements. Edit this, never the generated project. |
| `Packages/RiseCore` | Pure-Foundation Swift package: `SolarCalculator` (NOAA), `AlarmPlanner`, `AlarmSettings`, `DateKey`. Fully unit-tested and buildable without Xcode. |
| `RiseAndShine/` | The iOS app (SwiftUI). `App/` root and `AppModel`; `Services/` AlarmKit, notifications, location, background refresh; `Features/` Home, Settings, Onboarding, Nightstand; `Design/` theme and components. |
| `RiseAndShineWidgets/` | Widget extension: the AlarmKit Live Activity (Lock Screen / Dynamic Island) and a Next Alarm home/lock screen widget. |
| `Shared/` | Files compiled into both the app and the widget: App Group paths, shared JSON store, alarm metadata. |
| `RiseAndShine/Resources/AlarmSounds` | Bundled alarm sounds (CAF). |

## How alarms work

1. `AppModel.recompute()` builds a `PlannedDay` for each of the next 14 days: sun events, alarm time (with the wake-window clamp), bedtime and wind-down.
2. `AlarmScheduler.sync` reconciles those with the system: one fixed-date AlarmKit alarm per active morning, cancelling days that were skipped or fell out of the window, and any alarm the map no longer tracks (e.g. after the App Group changes). The day → alarm-id map lives in the App Group.
3. Alarms belong to iOS once scheduled, so they survive the app being killed or the phone restarting. The app extends the horizon on every launch and via Background App Refresh.
4. Wind-down and bedtime reminders are ordinary time-sensitive notifications (they respect a Sleep Focus on purpose).

## What syncs

Settings and wake history are mirrored through **your own** iCloud key-value store, so a
second device or a new phone starts with your alarm and your record of past mornings.
Nothing goes to a server of ours, and there is no account to make: `CloudSettings` is
last-write-wins on a timestamp, `CloudHistory` merges per morning, because two devices
usually hold different halves of the same one. Both need the
`com.apple.developer.ubiquity-kvstore-identifier` entitlement, which a personal team
cannot sign — it is commented out in `project.yml` until the paid team.

## Nightstand and the sunrise light

Tap the moon on Home, or plug the phone in during the night window and it offers itself
once. Nightstand keeps the display awake with a dim clock, the next alarm and sunrise.

With **Settings › Nightstand › Sunrise light** set to a length, the screen starts almost
black that long before the alarm and reaches the chosen brightness as it rings, holding
for 30 minutes while you get up. The ramp is `SunriseGlow` in RiseCore — pure arithmetic
over `now`, so it is unit-tested rather than watched at 6 am — and brightness rises with
the *square* of progress, because a linear backlight ramp reads as "already bright"
within a minute. "Preview the sunrise" runs the whole thing compressed into a minute.

Nightstand is the only screen that rotates. The Info.plist has to allow landscape for
that, so `OrientationLock` narrows it back to portrait everywhere else through a
one-method `AppDelegate`. Screen brightness is device-wide and the system will not
restore it, so the session saves the user's level on entry and puts it back on exit,
including when the app is backgrounded.

## Testing the core without Xcode

```sh
cd Packages/RiseCore
swift run RiseCoreCheck     # prints ✓/✗ against NOAA reference values
```

With Xcode installed, `swift test` (or ⌘U in Xcode) runs the full Swift Testing suite.

## Release checklist

- [x] Set `DEVELOPMENT_TEAM` and confirm bundle ids in `project.yml`.
- [ ] Replace the 1024×1024 app icon in `Assets.xcassets/AppIcon.appiconset` if desired.
- [ ] Test on device: alarm rings in Silent + Sleep Focus, snooze countdown shows in Dynamic Island, widget updates after an alarm passes.
- [ ] App Store Connect: privacy label "Data Not Collected"; Location (precise) used for app functionality only.
- [ ] Bump `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` in `project.yml`, regenerate, archive.
