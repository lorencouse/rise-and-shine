import XCTest

/// The highest-risk open check. `AlarmScheduler.scheduleDate(for:)` schedules the alarm
/// *earlier* by `preAlarmMinutes`, assuming AlarmKit then runs a `preAlert` countdown and
/// alerts at the planned time. If AlarmKit instead alerts when the schedule fires, every
/// alarm rings `preAlarmMinutes` early.
///
/// The test alarm makes this cheap to falsify: it schedules at now + 10s and expects the
/// alert at now + 10s + countdown. An alert inside ~10s means the assumption is wrong.
/// The happy path is not waited out in full — staying silent past the schedule time is
/// what distinguishes the two behaviours.
final class PreAlarmCountdownTests: UITestCase {

    @MainActor
    func testCountdownDoesNotAlertAtScheduleTime() {
        let app = launch()
        defer { restoreCountdownToOff(app) }

        waitForHome(app)
        openWakeTimeSheet(app)
        setCountdown("10 min", in: app)
        dismissSheet(app)

        waitForHome(app)
        openSettings(app)
        let testRow = app.buttons["settings.testAlarm"]
        XCTAssertTrue(scrollTo(testRow, in: app), "Test alarm row not found in Settings.")

        // The label states the semantics under test, so assert on it too.
        XCTAssertTrue(testRow.label.contains("ring in 10 min"),
                      "Expected the row to promise a 10 min countdown, got: \(testRow.label)")
        testRow.tap()

        // The schedule fires at +10s. Watch well past it: an alert here means AlarmKit
        // alerted at the schedule time and real alarms will ring early.
        let alertedEarly = springboard.alerts.firstMatch.waitForExistence(timeout: 40)

        if alertedEarly { stopRingingAlarm() }

        XCTAssertFalse(alertedEarly,
                       """
                       AlarmKit alerted at the schedule time rather than after the preAlert \
                       countdown, so alarms ring 10 minutes early. Fix: drop \
                       scheduleDate(for:) in AlarmScheduler and pass fireDate unchanged.
                       """)
    }

    // MARK: Helpers

    /// Never leave the phone ringing because a test failed.
    @MainActor
    private func stopRingingAlarm() {
        for label in ["Stop", "OK", "Dismiss", "Close"] where springboard.buttons[label].exists {
            springboard.buttons[label].tap()
            return
        }
    }

    /// Puts the setting back to its default so tomorrow's real alarm is unaffected.
    @MainActor
    private func restoreCountdownToOff(_ app: XCUIApplication) {
        guard app.state == .runningForeground else { return }
        // Could be anywhere; close whatever sheet is open first.
        let done = app.buttons["Done"]
        if done.exists && done.isHittable { done.tap() }
        guard app.staticTexts["home.locationName"].firstMatch.waitForExistence(timeout: 10) else { return }
        openWakeTimeSheet(app)
        setCountdown("Off", in: app)
        dismissSheet(app)
    }
}
