import XCTest

/// Checks that need no state changes: what Home renders, and whether wake history picked
/// up a real morning.
final class HomeStateTests: UITestCase {

    /// Also settles the open question about App Group persistence: a location and an alarm
    /// time on a cold launch can only have come from `settings.json` on disk.
    @MainActor
    func testHomeShowsLocationAndAlarmTimeAfterColdLaunch() {
        let app = launch()
        waitForHome(app)

        let location = app.staticTexts["home.locationName"].firstMatch
        XCTAssertTrue(location.waitForExistence(timeout: 10), "Location label missing.")
        XCTAssertNotEqual(location.label, "No location",
                          "Home has no location on a cold launch — settings did not load from disk.")

        let hero = app.staticTexts["home.heroTime"].firstMatch
        XCTAssertTrue(hero.waitForExistence(timeout: 10),
                      "No alarm time on the hero. Either the alarm is off or the plan is empty.")
        XCTAssertFalse(hero.label.isEmpty)
    }

    /// The morning of 2026-09-10 rang and was stopped, so history should have a row.
    @MainActor
    func testWakeHistoryHasACompletedMorning() {
        let app = launch()
        waitForHome(app)
        openSettings(app)

        let link = app.buttons["settings.wakeHistoryLink"]
        XCTAssertTrue(link.waitForExistence(timeout: 10), "Wake history row not found in Settings.")
        XCTAssertFalse(link.label.contains("0 mornings"),
                       "Wake history is empty. The alarmUpdates observer did not record the morning.")
        link.tap()

        XCTAssertFalse(app.staticTexts["history.empty"].waitForExistence(timeout: 5),
                       "Wake history detail shows the empty state.")
        XCTAssertTrue(app.staticTexts["Mornings"].waitForExistence(timeout: 5),
                      "No Mornings section in wake history.")
    }

    /// The Recent mornings card is gated on a completed morning, so it pairs with the above.
    @MainActor
    func testRecentMorningsCardAppearsOnHome() {
        let app = launch()
        waitForHome(app)
        let card = app.staticTexts["home.recentMornings.last"]
        app.swipeUp()
        XCTAssertTrue(card.waitForExistence(timeout: 10),
                      "Recent mornings card is absent even though a morning completed.")
        XCTAssertTrue(card.label.contains("rang"), "Unexpected card text: \(card.label)")
    }
}
