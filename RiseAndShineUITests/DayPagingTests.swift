import XCTest

/// `DayPagingGesture` shares the hero with the vertical scroll view. The risk is that one
/// eats the other, so both directions are asserted, plus that the controls still tap.
final class DayPagingTests: UITestCase {

    @MainActor
    func testHorizontalSwipePagesTheDay() {
        let app = launch()
        waitForHome(app)
        let eyebrow = app.staticTexts["home.eyebrow"].firstMatch
        XCTAssertTrue(eyebrow.waitForExistence(timeout: 10))
        let resting = eyebrow.label

        hero(app).swipeLeft()
        XCTAssertTrue(waitForLabelChange(eyebrow, from: resting),
                      "A left swipe on the hero did not page the day (still '\(resting)').")

        // Today returns to the resting state.
        app.buttons["home.today"].tap()
        XCTAssertTrue(waitForLabelChange(eyebrow, from: eyebrow.label, to: resting),
                      "The Today button did not return to the resting state.")
    }

    @MainActor
    func testChevronButtonsStillTapWhileTheGestureIsAttached() {
        let app = launch()
        waitForHome(app)
        let eyebrow = app.staticTexts["home.eyebrow"].firstMatch
        XCTAssertTrue(eyebrow.waitForExistence(timeout: 10))
        let resting = eyebrow.label

        app.buttons["home.pageNext"].tap()
        XCTAssertTrue(waitForLabelChange(eyebrow, from: resting),
                      "The next-day chevron did not page — the gesture may be swallowing taps.")

        app.buttons["home.pagePrev"].tap()
        XCTAssertTrue(waitForLabelChange(eyebrow, from: eyebrow.label, to: resting),
                      "The previous-day chevron did not page back.")
    }

    /// The vertical scroll must survive the horizontal gesture being attached.
    @MainActor
    func testVerticalScrollStillWorks() {
        let app = launch()
        waitForHome(app)
        let hero = app.staticTexts["home.heroTime"].firstMatch
        XCTAssertTrue(hero.waitForExistence(timeout: 10))
        let before = hero.frame.origin.y

        app.swipeUp()
        XCTAssertNotEqual(before, hero.frame.origin.y, accuracy: 1,
                          "The page did not scroll vertically — the paging gesture is eating it.")
    }
}
