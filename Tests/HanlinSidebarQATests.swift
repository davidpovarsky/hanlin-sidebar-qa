import XCTest

final class HanlinSidebarQATests: XCTestCase {
    private func openSidebar(_ app: XCUIApplication) {
        let toggle = app.buttons["sidebar-toggle"]
        let settings = app.buttons["sidebar-settings"]
        if !settings.isHittable {
            XCTAssertTrue(toggle.waitForExistence(timeout: 12), "Sidebar toggle missing")
            toggle.tap()
        }
        XCTAssertTrue(settings.waitForExistence(timeout: 8), "Sidebar settings missing after toggle")
        XCTAssertTrue(settings.isHittable, "Sidebar settings not hittable")
    }

    func testSettingsFromSidebar() {
        let app = XCUIApplication()
        app.launch()
        openSidebar(app)
        app.buttons["sidebar-settings"].tap()
        XCTAssertTrue(app.staticTexts["settings-screen-marker"].waitForExistence(timeout: 8),
                      "Settings screen did not open")
    }

    func testSidebarOpensAndCloses() {
        let app = XCUIApplication()
        app.launch()
        openSidebar(app)
        app.buttons["sidebar-toggle"].tap()
        XCTAssertTrue(app.buttons["sidebar-toggle"].waitForExistence(timeout: 5))
    }

    func testSettingsAfterDrag() {
        let app = XCUIApplication()
        app.launch()
        let screen = app.windows.firstMatch
        let left = screen.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.5))
        let right = screen.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.5))
        left.press(forDuration: 0.05, thenDragTo: right)
        let settings = app.buttons["sidebar-settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 8), "Swipe did not reveal sidebar")
        XCTAssertTrue(settings.isHittable, "Sidebar not interactive after swipe")
        settings.tap()
        XCTAssertTrue(app.staticTexts["settings-screen-marker"].waitForExistence(timeout: 8))
    }
}
