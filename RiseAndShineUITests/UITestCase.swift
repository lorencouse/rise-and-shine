import XCTest

/// Shared setup for the device checks. These tests drive the real app against real
/// AlarmKit, so they are not hermetic: they assume the app is already onboarded with a
/// location, and they restore any setting they change.
///
/// `setUp`/`tearDown` are deliberately not overridden. Under Swift 6 those inherit
/// nonisolated isolation, which cannot be reconciled with `XCUIApplication` being
/// main-actor bound; each test calls `launch()` instead.
class UITestCase: XCTestCase {

    /// Springboard, for the system UI the app cannot see: AlarmKit alerts and
    /// permission prompts.
    @MainActor
    var springboard: XCUIApplication {
        XCUIApplication(bundleIdentifier: "com.apple.springboard")
    }

    @MainActor
    func launch() -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        return app
    }

    /// The app opens on Home; wait for the location label rather than a fixed sleep.
    /// Onboarding has no such element, so this also distinguishes the two.
    @MainActor
    func waitForHome(_ app: XCUIApplication) {
        XCTAssertTrue(app.staticTexts["home.locationName"].firstMatch.waitForExistence(timeout: 25),
                      "Home never appeared — the app may be showing onboarding.")
    }

    /// The hero is the swipe surface for day paging. It carries no identifier of its own
    /// (an ancestor identifier would override every control inside it), so the big time
    /// label stands in for it.
    @MainActor
    func hero(_ app: XCUIApplication) -> XCUIElement {
        app.staticTexts["home.heroTime"].firstMatch
    }

    @MainActor
    func openSettings(_ app: XCUIApplication) {
        let button = app.buttons["home.settings"]
        XCTAssertTrue(button.waitForExistence(timeout: 10), "Settings button not found.")
        button.tap()
    }

    /// Opens the Wake time sheet from Home's offset chip.
    @MainActor
    func openWakeTimeSheet(_ app: XCUIApplication) {
        let chip = app.buttons["home.wakeTimeChip"]
        XCTAssertTrue(chip.waitForExistence(timeout: 10), "Wake time chip not found.")
        chip.tap()
    }

    /// Taps a segment of the countdown picker by its visible label ("Off", "10 min", …).
    @MainActor
    func setCountdown(_ label: String, in app: XCUIApplication) {
        let picker = app.segmentedControls["sheet.countdown"]
        XCTAssertTrue(picker.waitForExistence(timeout: 10), "Countdown picker not found.")
        picker.buttons[label].tap()
    }

    /// A swipe down inside a sheet whose content scrolls just scrolls the content, so
    /// prefer the Done button and fall back to a drag from the sheet's top edge.
    @MainActor
    func dismissSheet(_ app: XCUIApplication) {
        let done = app.buttons["Done"]
        if done.exists && done.isHittable {
            done.tap()
        } else {
            let top = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.06))
            let bottom = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95))
            top.press(forDuration: 0.05, thenDragTo: bottom)
        }
        XCTAssertTrue(app.staticTexts["home.locationName"].firstMatch.waitForExistence(timeout: 10),
                      "Sheet did not dismiss back to Home.")
    }

    /// SwiftUI `Form`/`List` rows are rendered lazily, so an off-screen row does not
    /// exist yet. Scroll until it does.
    @MainActor
    @discardableResult
    func scrollTo(_ element: XCUIElement, in app: XCUIApplication, maxSwipes: Int = 8) -> Bool {
        for _ in 0..<maxSwipes {
            if element.exists && element.isHittable { return true }
            app.swipeUp()
        }
        return element.exists && element.isHittable
    }

    /// Polls an element's label, since these change by animation rather than by event.
    @MainActor
    func waitForLabelChange(_ element: XCUIElement, from old: String, to expected: String? = nil,
                            timeout: TimeInterval = 6) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let now = element.label
            if let expected {
                if now == expected { return true }
            } else if now != old {
                return true
            }
            usleep(200_000)
        }
        return false
    }
}
