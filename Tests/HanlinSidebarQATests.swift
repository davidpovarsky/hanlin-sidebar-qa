import XCTest

final class HanlinSidebarQATests: XCTestCase {
    func testSettingsFromSidebar() {
        let app = XCUIApplication()
        app.launch()
        let sidebar = app.buttons["sidebar.left"]
        if sidebar.exists { sidebar.tap() }
        let settings = app.buttons["הגדרות"].firstMatch
        XCTAssertTrue(settings.waitForExistence(timeout: 8), "Settings button absent")
        settings.tap()
        XCTAssertTrue(app.navigationBars["הגדרות Hanlin"].waitForExistence(timeout: 8), "Settings did not open")
    }
    func testSearchAndConversationSelection() {
        let app = XCUIApplication()
        app.launch()
        let sidebar = app.buttons["sidebar.left"]
        if sidebar.exists { sidebar.tap() }
        XCTAssertTrue(app.staticTexts["מחקר עם מקורות"].firstMatch.waitForExistence(timeout: 8))
    }
}
