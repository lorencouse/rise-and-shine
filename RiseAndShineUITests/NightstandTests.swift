import XCTest

/// Nightstand mode and the sunrise light. The glow itself is arithmetic and is covered
/// by `SunriseGlowTests` in RiseCore; what can only be checked here is that the screen
/// presents, shows a clock and the next alarm, and gives the app back on Done.
final class NightstandTests: UITestCase {

    @MainActor
    func testNightstandShowsClockAndAlarmThenDismisses() {
        let app = launch()
        waitForHome(app)

        let enter = app.buttons["home.nightstand"]
        XCTAssertTrue(enter.waitForExistence(timeout: 10), "Nightstand button missing from Home.")
        enter.tap()

        let clock = app.staticTexts["nightstand.clock"]
        XCTAssertTrue(clock.waitForExistence(timeout: 10), "Nightstand did not present.")
        XCTAssertFalse(clock.label.isEmpty)

        let alarm = app.staticTexts["nightstand.alarm"]
        XCTAssertTrue(alarm.waitForExistence(timeout: 5), "Nightstand shows no alarm line.")

        // Controls fade after a few seconds; a tap has to bring them back or there is no
        // way out but the home gesture.
        app.tap()
        let done = app.buttons["nightstand.done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5), "Done button never appeared.")
        done.tap()

        XCTAssertTrue(app.staticTexts["home.locationName"].firstMatch.waitForExistence(timeout: 10),
                      "Nightstand did not return to Home.")
    }

    /// The settings path exists and is reachable. Deliberately read-only: this runs
    /// against the real phone, and a test that changed the sunrise length could leave
    /// the user's alarm lighting up when they did not ask it to.
    @MainActor
    func testNightstandSettingsAreReachable() {
        let app = launch()
        waitForHome(app)
        openSettings(app)

        let row = app.buttons["settings.nightstandLink"]
        XCTAssertTrue(scrollTo(row, in: app), "Nightstand row not found in Settings.")
        row.tap()

        let picker = app.descendants(matching: .any).matching(identifier: "nightstand.glowPicker").firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 10), "Sunrise light picker missing.")
    }
}
