import XCTest

/// Not a check. Prints the real element tree so the other tests can be written against
/// what SwiftUI actually exposes. Kept in the suite because the tree changes with the UI.
final class DiagnosticTests: UITestCase {

    @MainActor
    func testDumpHomeTree() {
        let app = launch()
        waitForHome(app)
        dumpButtons(app, tag: "HOME")
        dumpTexts(app, tag: "HOME")
    }

    @MainActor
    func testDumpSettingsTree() {
        let app = launch()
        waitForHome(app)
        openSettings(app)
        _ = app.navigationBars.firstMatch.waitForExistence(timeout: 10)
        for pass in 0..<6 {
            dumpButtons(app, tag: "SETTINGS-\(pass)")
            app.swipeUp()
        }
    }

    // MARK: Helpers

    @MainActor
    private func dumpButtons(_ app: XCUIApplication, tag: String) {
        print("=== \(tag) BUTTONS ===")
        for b in app.buttons.allElementsBoundByIndex {
            print("button id=\(b.identifier) label=\(b.label) hittable=\(b.isHittable)")
        }
    }

    @MainActor
    private func dumpTexts(_ app: XCUIApplication, tag: String) {
        print("=== \(tag) TEXTS ===")
        for t in app.staticTexts.allElementsBoundByIndex {
            print("text id=\(t.identifier) label=\(t.label)")
        }
    }
}
