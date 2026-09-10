# TODO

Feature audit started 2026-09-09. Open work is at the top; everything shipped is in the log
at the bottom. Nothing here is committed yet — the working tree carries all of it.

## Remaining open items

### Release-time entitlements (personal team cannot sign these; restore on the paid team)

- [ ] `com.apple.developer.usernotifications.time-sensitive` — without it wind-down/bedtime reminders are silently downgraded from time-sensitive. Uncomment in `project.yml`.
- [ ] `com.apple.developer.ubiquity-kvstore-identifier` — without it `CloudSettings` never syncs. Uncomment in `project.yml`, enable iCloud KVS on the App ID.

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
- [ ] Siri phrases resolve; the sync flush finishes before Siri confirms.
- [ ] Travel notice fires once when crossing a zone with location following on.
- [ ] Calendar toggle: permission prompt, a "Rise and Shine" calendar appears, events move when the offset changes, toggling off removes them.
- [x] Day paging: sideways swipe pages a day, the chevrons still tap, and the vertical
      scroll still works. *Verified 2026-09-10 by `DayPagingTests`; no threshold tuning
      needed.*
- [ ] Dark/tinted icon variants render acceptably on the Home Screen.
- [ ] Health: toggle prompts for Sleep read access; after allowing, "Last night" appears in Settings › Health and on the Tonight card (needs Watch sleep data).

### Device checks for the Watch (paired watch needed)

- [x] Watch app appears on the paired watch and shows the same alarm time as the phone.
      *Verified 2026-09-10 on the Ultra (watchOS 26.6). Installed directly with the
      `RiseAndShineWatch` scheme, not via the embedded phone build. Confirms the
      WatchConnectivity mirror and the watch-side `AlarmPlanner` recompute agree with
      the phone.*
- [x] Skip on the watch reaches the phone and actually cancels the AlarmKit alarm; the watch's
      optimistic row is confirmed by the context that comes back. *Verified 2026-09-10.*
- [ ] Alarm toggle on the watch round-trips.
- [ ] Complication families (circular, rectangular, inline, corner) render and roll over after an alarm passes.
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

- [ ] **A morning is missed entirely if the app is not opened while the alarm still exists.**
      Records are only created from a state *transition*, so if you stop the alarm and do not
      open the app until AlarmKit has dropped the alarm, it appears in neither snapshot and no
      record is written. Would need reconciling the registry against past dates at launch
      rather than relying on transitions. Found while fixing the `rang` bug; not reproduced
      yet.

- [ ] **The wake-record logic has no test.** It lives in `AlarmScheduler` and switches on
      AlarmKit's `Alarm.State`, so it cannot be exercised from `RiseCoreTests`. Extracting the
      transition-to-record decision into RiseCore behind its own small state enum would make
      both bugs above testable.

### Larger features

- [x] HealthKit: read sleep analysis and show actual sleep against the goal; attach slept time to each wake record. *`HealthService` (read-only), Health section in Settings, last-night line on the Tonight card, average sleep in history. Signs on the personal team.*
- [x] Apple Watch app: next alarm, skip, alarm toggle, next-7-days list, and four accessory complication families. Watch computes its own plan with RiseCore from settings mirrored over WatchConnectivity. *Verified running on 49 mm and 40 mm simulators. Needs `xcodebuild -downloadPlatform watchOS`, already installed here.*

## Notes

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
