# TODO

Feature audit started 2026-09-09. Open work is at the top; everything shipped is in the log
at the bottom. Nothing here is committed yet — the working tree carries all of it.

## Remaining open items

### Before submitting

- [x] `PrivacyInfo.xcprivacy` declared no required-reason APIs, which is an automatic
      ITMS-91053 rejection. Now declares `UserDefaults` (CA92.1) and file timestamps (C617.1).
- [x] `MARKETING_VERSION` was 2.0.0, below the last shipped App Store version (3.74), which
      App Store Connect rejects. Now 4.0.0.
- [x] Release configuration builds for a generic iOS device.
- [ ] No translations; `Localizable.xcstrings` has keys but no localisations. English-only
      release is fine, this is only a gap if you want more.

### Release-time entitlements (personal team cannot sign these; restore on the paid team)

- [x] `com.apple.developer.usernotifications.time-sensitive` — without it wind-down/bedtime reminders are silently downgraded from time-sensitive. Uncomment in `project.yml`.
- [x] `com.apple.developer.ubiquity-kvstore-identifier` — without it `CloudSettings` never syncs. Uncomment in `project.yml`, enable iCloud KVS on the App ID.

### Device checks (no simulator AlarmKit; phone is paired)

- [x] **Pre-alarm countdown timing.** Verified 2026-09-10 by `PreAlarmCountdownTests` plus
      one real wait. With 10 min set, the test alarm scheduled at +10 s stayed silent through
      the schedule time (the test asserts this) and alerted ~10 min later, at 09:15 for a
      09:05 tap. So AlarmKit runs the `preAlert` countdown and alerts at the end of it, which
      is what `scheduleDate(for:)` assumes: alarms neither ring early nor lose the alert.
      Still unconfirmed: that the countdown Live Activity is visible on the Lock Screen and
      in the Dynamic Island while it runs.
- [x] Control Center toggle actually cancels/reschedules the AlarmKit alarm. *Verified
      2026-09-10: turns all alarms on and off.*
- [x] Widget Skip cancels the alarm. *Verified 2026-09-10 after the deep-link change. The
      `LiveActivityIntent` assumption
      was wrong for widget buttons — `Button(intent:)` ran the **extension's** copy of the
      intent, where `#if !WIDGET_EXTENSION` compiles the AlarmKit call out, so the button did
      nothing at all. Replaced with a `Link` to `riseandshine://skipNext`, which the app
      handles on open. Costs a visible app launch. `SkipNextAlarmWidgetIntent` is now unused
      but left in place. Note the Skip button only exists in `.systemMedium` (the wide
      widget); `.systemLarge` is not a supported family.*
- [ ] Polar-night scheduling: an alarm exists on a day with no sunrise when the clamp is on.
- [ ] `alarmUpdates` observer: registry self-prunes after an alarm is stopped; Home shows the ringing/snoozing pill.
- [x] Wake history: after a real alarm rings and is stopped, a row appears in Settings ›
      Wake history and the Recent mornings card shows on Home. *Verified 2026-09-10 by
      `HomeStateTests`. But the recorded times are wrong — see the `rang` bug below.*
- [x] Widget deep links open the Wake time sheet; the bedtime stat opens Sleep. *The Skip
      link is verified; the other two share the same `onOpenURL` path.*
- [x] Siri phrases resolve; the sync flush finishes before Siri confirms. *Verified 2026-09-10.*
- [ ] Travel notice fires once when crossing a zone with location following on.
- [x] Calendar toggle: permission prompt, a "Rise and Shine" calendar appears, events move when the offset changes, toggling off removes them. *Verified 2026-09-10.*
- [x] Day paging: sideways swipe pages a day, the chevrons still tap, and the vertical
      scroll still works. *Verified 2026-09-10 by `DayPagingTests`; no threshold tuning
      needed.*
- [x] Dark/tinted icon variants render acceptably on the Home Screen. *Verified 2026-09-10.*
- [x] Health: toggle prompts for Sleep read access; after allowing, "Last night" appears in Settings › Health and on the Tonight card. *Verified 2026-09-10.*

### Device checks for history sync

- [ ] With the iCloud entitlement restored: a morning recorded on the phone appears on a
      second device, and a clear on either empties both.
- [ ] A fresh install with an existing iCloud copy adopts the history at first launch
      rather than starting empty.

### Device checks for nightstand and the sunrise light

- [x] `NightstandTests` pass on the phone. *Verified 2026-09-10: nightstand presents from
      Home, shows the clock and the alarm line, a tap brings the faded controls back and
      Done returns to Home; the Settings row is reachable. Deliberately read-only about
      the glow length — this runs on the real phone and must not leave the screen set to
      light up on a morning the user did not ask for.*
- [ ] Brightness actually ramps on hardware and the user's own level comes back on Done,
      on backgrounding, and after a force-quit from inside nightstand.
- [ ] Landscape: nightstand rotates, every other screen stays portrait, and returning to
      Home from a landscape nightstand does not leave Home sideways.
- [ ] Auto-entry: plugging in during the night window presents it once, and plugging in
      during the day does nothing.
- [ ] A real morning with the glow on: the ramp is visible from the pillow at 10 min out,
      and the alarm still rings on time with the screen at full.

### Device checks for the Watch (paired watch needed)

- [x] Watch app appears on the paired watch and shows the same alarm time as the phone.
      *Verified 2026-09-10 on the Ultra (watchOS 26.6). Installed directly with the
      `RiseAndShineWatch` scheme, not via the embedded phone build. Confirms the
      WatchConnectivity mirror and the watch-side `AlarmPlanner` recompute agree with
      the phone.*
- [x] Skip on the watch reaches the phone and actually cancels the AlarmKit alarm; the watch's
      optimistic row is confirmed by the context that comes back. *Verified 2026-09-10.*
- [x] Alarm toggle on the watch round-trips. *Verified 2026-09-10.*
- [x] Watch app icon renders. *Verified 2026-09-10 after adding the missing asset catalog.*
- [x] Complication families (circular, rectangular, inline, corner) render. *Verified
      2026-09-10. Roll-over after an alarm passes not separately watched.*
- [ ] Watch app works with the phone out of range: it should still show a correct plan from the last mirrored settings, and queue actions until the phone is back.

### Bugs found by the device checks

- [x] **Wake history stamped the wrong times.** `AlarmScheduler` set `r.rang = now`, but
      `AlarmManager.alarmUpdates` only delivers while the app runs — and you are asleep when
      the alarm fires. The transition was first seen at the next launch, so `rang` became the
      launch time. Seen 2026-09-10: rang at 06:49, recorded 08:26. *Fixed: `rangDate()`
      derives the ring from the alarm's own `.fixed` schedule plus `countdownDuration.preAlert`,
      since AlarmKit alerts exactly on schedule and `scheduleDate(for:)` deliberately shifts
      the schedule earlier by the countdown. `stopped` still uses `now`, which is correct —
      the removal is a diff between two in-process snapshots. Needs one real morning to
      confirm end to end; the record already on the phone keeps its bad 08:26 stamp unless
      history is cleared.*

- [x] **A morning is missed entirely if the app is not opened while the alarm still exists.**
      Records are only created from a state *transition*, so if you stop the alarm and do not
      open the app until AlarmKit has dropped the alarm, it appears in neither snapshot and no
      record is written. Found while fixing the `rang` bug; not reproduced yet. *Fixed:
      `AlarmScheduler` now keeps each day's schedule beside the registry
      (`scheduled-mornings.json`), and before the registry forgets a gone alarm it records
      every past morning with no record as rung on schedule, stop unknown
      (`WakeHistory.recordUnobserved`, tested in `UnobservedMorningTests`). With no stop
      those mornings stay out of the streak and averages. Alarms scheduled before this
      change are covered once a snapshot has seen them. Needs one real morning to confirm:
      stop the alarm, open the app an hour later.*

- [x] **The wake-record logic has no test.** *Extracted into `WakeHistory.record(from:to:…)`
      in RiseCore behind an `AlarmPhase` enum that mirrors `Alarm.State`; `AlarmScheduler`
      now just maps AlarmKit's state onto it. Six tests in `WakeRecordTransitionTests`,
      including a regression for the 06:49-recorded-as-08:26 bug.*

### Larger features

- [x] HealthKit: read sleep analysis and show actual sleep against the goal; attach slept time to each wake record. *`HealthService` (read-only), Health section in Settings, last-night line on the Tonight card, average sleep in history. Signs on the personal team.*
- [x] Apple Watch app: next alarm, skip, alarm toggle, next-7-days list, and four accessory complication families. Watch computes its own plan with RiseCore from settings mirrored over WatchConnectivity. *Verified running on 49 mm and 40 mm simulators. Needs `xcodebuild -downloadPlatform watchOS`, already installed here.*

### Completeness audit 2026-09-10

What a feature-complete, professional release still lacks. Ordered by impact.

- [x] **Sunrise light simulation (screen).** `SunriseGlow` in RiseCore: a ramp from
      near-black to a chosen ceiling over the last N minutes before the alarm, held for
      30 min after it. Brightness is squared against progress because the backlight is
      far from linear. Nine tests in `SunriseGlowTests`. Rendered by `NightstandView`,
      which owns the backlight for the session. Length, ceiling and a one-minute preview
      are in Settings › Nightstand.
- [ ] **Sunrise light simulation (real bulbs).** HomeKit/Matter ramp so lamps brighten
      with the plan. The screen version is the same arithmetic, so this is mostly the
      HomeKit accessory plumbing plus a background trigger that does not depend on the
      app being open.
- [x] **Nightstand mode.** Full-screen dim clock, next alarm and sunrise, screen kept
      awake, controls fading after 6 s. Offers itself once per connection when the phone
      starts charging inside the night window (next alarm minus sleep goal minus an hour,
      through the end of the glow); always available from the moon button on Home.
      Landscape is now allowed in the Info.plist and narrowed back to portrait for every
      other screen by `OrientationLock` + a one-method `AppDelegate`.
- [ ] **Wake-up insights.** `WakeHistory` plus HealthKit sleep is already stored but only
      listed. A weekly card ("your wake drifted 22 min later this month", "6h48 of a 7h30
      goal") and a sunrise-vs-actual-wake trend would make the recorded data worth opening.
- [x] **Backup of history.** `CloudHistory` mirrors `WakeHistory` on its own iCloud KVS
      key. Merged per morning rather than last-write-wins — two devices usually hold
      different halves of the same one — by `WakeHistory.merged(with:)` in RiseCore, with
      six tests. A clear propagates as a clear (`history.v1.cleared`), or the other
      device would hand the records straight back. Needs the same
      `ubiquity-kvstore-identifier` entitlement as settings, so it does nothing on the
      personal team. *Fixed alongside: history reached the watch only when a **setting**
      changed, so a morning could sit unmirrored for days. `AlarmScheduler` now has
      `onHistoryChanged`/`onHistoryCleared` and the mirror runs on every history write.*
- [ ] **Export of history.** CSV/JSON share sheet, for taking the record somewhere the
      app is not.
- [ ] **Accessibility pass.** Only ~12 `accessibilityLabel`s exist, all on Home and
      Components; onboarding, Settings and the sheets are unaudited, and no view honours
      `reduceMotion` (sun arc, day paging). An alarm app is used with eyes shut.
- [ ] **What's New sheet** on a version bump. Onboarding exists; nothing greets an update.
- [ ] **Review prompt.** No StoreKit at all. `requestReview` after ~5 successfully stopped
      alarms, never during onboarding.
- [ ] **Diagnostics for support.** A "Copy diagnostics" row (scheduled count, permission
      states, background-refresh state, last sync) so a bug report is actionable without
      adding analytics.
- [ ] **Monetization decision.** No StoreKit. If this is paid or freemium, decide before
      submission: tip jar vs. Pro, where the Watch app, light control and insights are the
      natural paywall line.
- [ ] **App Store surface.** Support URL, privacy policy page, screenshots, App Preview.
- [ ] **CI.** No `.github/`. A workflow running `swift test` on RiseCore and
      `xcodebuild test` on the app would catch by machine what has been caught by hand.

## Notes

- A `CODE_SIGNING_ALLOWED=NO` build for `generic/platform=iOS` writes an **unsigned**
  `RiseAndShine.app` into `Build/Products/Debug-iphoneos`, and a later device test run
  reuses it rather than rebuilding: every test then fails with "No code signature found"
  or "Lost pending connection to the test runner". Delete that directory before running
  on the phone, or do the syntax-only build somewhere else.

- **Verified on device 2026-09-10:** a real scheduled alarm sounded at the planned time
  while Sleep Focus was active. AlarmKit's Focus bypass works with no critical-alert
  entitlement, and the planned fire time matched.
- `RiseAndShineUITests` drives the real app on the real phone; run it with
  `xcodebuild ... -only-testing:RiseAndShineUITests/<Suite> test`. Three gotchas cost time:
  (1) an ancestor's `accessibilityIdentifier` **overrides every descendant's**, so putting
  one on the hero card hid the eyebrow, chips, toggle and paging buttons — keep identifiers
  on leaves; (2) `SWIFT_DEFAULT_ACTOR_ISOLATION: MainActor` cannot apply to `XCTestCase`
  subclasses (its initialisers are nonisolated), so that target sets `nonisolated` and marks
  test methods `@MainActor` individually; (3) new files need `xcodegen generate` before they
  are in the target, and a missing file shows up as "Executed 0 tests", not as an error.
  `DiagnosticTests` dumps the live element tree — start there when a query stops matching.
- Installing to the watch needs **Developer Mode enabled on the watch itself**
  (Settings › Privacy & Security › Developer Mode, then a restart). Without it `xcodebuild`
  fails with the misleading "Loren's Apple Watch doesn't have a known architecture", and
  `devicectl` reports `CoreDeviceError 10005`. Embedding the watch app in the phone build
  does not work around it. Install directly with the `RiseAndShineWatch` scheme.
- The watch app had **no asset catalog at all**, so it shipped with a blank icon and no
  accent colour, while `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME` pointed at an
  `AccentColor` that did not exist. Added `Watch/App/Assets.xcassets`. watchOS takes a
  single 1024×1024 icon with `"platform": "watchos"`, and it must have no alpha.
- The phone app now embeds the watch app, so a missing `WKApplication` key in the watch
  Info.plist makes the *iPhone* app fail to install. Caught once; keep it in `project.yml`.
- `AlarmSettings` decoding is fault-tolerant per field: a missing *or malformed* key falls
  back to its default instead of failing the whole file, which would have looked like "no
  settings" and dropped the user into onboarding with their alarms cancelled.
- Local install to the phone went flaky at the end of the session ("CoreDeviceService was
  unable to locate a device"). Reconnecting the cable or running once from Xcode clears it.

## Shipped (log)

- [x] Default alarm sound is `Phone Chime 1.mp3`; bundle only has `.caf` files and the picker only lists `.caf`. Fresh installs pass a missing sound to AlarmKit. (`AlarmSettings.soundFile`)
- [x] Polar-night alarms are planned but never scheduled: `AlarmScheduler.sync` skips days with no sunrise/civil dawn even when the clamp produced a fire date. Make metadata sunrise optional or fall back to the fire date.
- [x] `ClockTime.date(on:)` adds minutes to midnight, so the wake-window clamp is one hour off on DST transition days. Use `calendar.date(bySettingHour:minute:second:of:)`.
- [x] "First light" means astronomical dawn as an anchor but civil dawn on the Today's light card. Rename the card metric to "Dawn".
- [x] Nothing observes `AlarmManager.alarmUpdates`; the app can't tell whether an alarm rang/stopped/snoozed and the registry keeps stale entries. Blocks wake history. *Observer added in `AlarmScheduler`; registry now self-prunes and `alertingAlarm` is exposed. Home does not surface it yet.*
- [x] Reminder triggers use `Calendar.current` components with no time zone, so they drift if the phone changes zone after scheduling. Set `components.timeZone` or use an interval trigger.
- [x] Following-device location is replaced on every foreground when coordinates differ by metres. Add a ~1 km distance threshold before adopting a new fix.
- [x] City search results are keyed by `\.name`; duplicate names break `ForEach`. Key on coordinates.
- [x] Test alarm ID is never recorded, so Reset can't cancel a pending test alarm; the Settings row also never returns to idle.
- [x] `skippedDays` is never pruned.
- [x] Sleep-goal wheel shows no selection when the stored value is outside 4–12 h.
- [x] Home refreshes twice at launch (`.task` + scenePhase).
- [x] No `PrivacyInfo.xcprivacy`.
- [x] No dark/tinted app icon variants. *Generated from the transparent logo with Core Image; tinted is grayscale.*
- [x] `AppGroup.deepLinkScheme` is declared but no URL handling exists. *URL scheme registered; widget taps open the wake-time or sleep sheet.*
- [x] Weekend/weekday profiles: a second offset and wake window for weekends. *`WakeProfile` + `weekendProfile`; Weekends card in the Wake time sheet.*
- [x] Fixed-time override for a single morning (early flight), extending the skip model. *`dayOverrides`; long-press a row → Custom time sheet; listed in Days.*
- [x] Pause until a date (vacation mode). *`pausedUntil`; Pause card in Days; auto-clears once the date passes.*
- [x] Year view: sunrise across 12 months with the alarm curve and clamp lines. *Became the Trends sheet: Week (actual plan, dots with times), Month (rule incl. weekends) and Year (rule, weekdays), each with alarm, sunrise, sunset and the wake window.*
- [x] Swipe left/right on the hero or light card to page through days; chevrons and a Today button too. Past days show what happened from wake history. *Range: 60 days back, 365 forward.*
- [x] Interactive widget button (skip tomorrow) and Control Center toggle. *Deep links are done. Open question before building: widget/control intents run in the extension process, and AlarmKit scheduling may not be available there. Options: `LiveActivityIntent` (runs in-app), or write a pending change to the App Group and let the app apply it on next foreground with a visible "pending" state.* *Both intents are `LiveActivityIntent`, so they run in the app process where AlarmKit is available; `WIDGET_EXTENSION` flag strips the app-only code from the extension build.*
- [x] Siri / Shortcuts intents: next alarm, skip tomorrow, toggle alarm. *Next alarm, skip next, on/off. Run in-app and flush the alarm sync.*
- [x] Travel notice: one notification when the followed location changes zone, saying how the alarm moved. *Posted when a followed location changes zone and notifications are allowed.*
- [x] Wake history from alarm updates: ring time, stop time, snooze count, streak. *`WakeHistory` in RiseCore with tests; recorded in `AlarmScheduler.record`; Recent mornings card on Home, full list in Settings.*
- [x] Pre-alarm Live Activity using AlarmKit `preAlert` countdown ("sunrise in 18 min"). *Off by default; picker in the Wake time sheet. Schedule is shifted earlier by the countdown so the alert lands on the planned time. **Verify on device before release:** if AlarmKit instead alerts at the schedule time, alarms ring early.*
- [x] Saved places (favourites) with one-tap switch from the location button. *Auto-remembered on pick, capped at 8; menu on the Home location button; list with swipe-to-delete in Location settings.*
- [x] Restore v3.74 calendar events (EventKit) as an opt-in. *`CalendarSync`: one Sleep event per night in a "Rise and Shine" calendar; full-access permission; toggle in Settings.*
- [x] Move snooze duration into the quick Wake time sheet.
- [x] Explain the wake window on the onboarding wake-time page before it clamps.
- [x] Enable the iPad device family.
- [x] String Catalog; everything is hardcoded English. *Empty `Localizable.xcstrings` + `SWIFT_EMIT_LOC_STRINGS`; Xcode fills keys on build. No translations yet.*
- [x] Display fonts are fixed point sizes; make them relative to text styles for Dynamic Type. *Hero and preview strip use `@ScaledMetric`.*
- [x] iCloud key-value sync of settings. *`CloudSettings` mirror is in place. Entitlement is commented out in `project.yml`: personal teams cannot sign iCloud. Restore with time-sensitive for release.*
- [x] Planner tests for DST days. (Location-zone ≠ device-zone is still only covered by `FormattersTests`.)
