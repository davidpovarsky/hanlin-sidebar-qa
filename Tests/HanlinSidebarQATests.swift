import XCTest
import UIKit

/// Exercises visible controls with physical coordinate events. All assertions run
/// against the same production SwiftUI hierarchy, with normal animations enabled.
final class HanlinSidebarQATests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["sidebar-toggle"].waitForExistence(timeout: 20))
    }

    override func tearDownWithError() throws {
        if let app {
            let shot = XCTAttachment(screenshot: app.screenshot())
            shot.name = name + " — final screen"
            shot.lifetime = .keepAlways
            add(shot)
            if testRun?.hasSucceeded == false {
                let tree = XCTAttachment(string: app.debugDescription)
                tree.name = name + " — accessibility hierarchy"
                tree.lifetime = .keepAlways
                add(tree)
            }
            app.terminate()
        }
        XCUIDevice.shared.orientation = .portrait
    }

    private var toggle: XCUIElement { app.buttons["sidebar-toggle"] }
    private var window: XCUIElement { app.windows.firstMatch }
    private var settings: XCUIElement { app.buttons["sidebar-settings"] }
    private func input(_ identifier: String) -> XCUIElement {
        // A multiline SwiftUI TextField may be exposed as a UITextView.
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }
    private var isWide: Bool {
        UIDevice.current.userInterfaceIdiom == .pad && window.frame.width >= 640
    }

    @discardableResult
    private func wait(_ predicate: NSPredicate, on element: XCUIElement,
                      timeout: TimeInterval = 10,
                      file: StaticString = #filePath, line: UInt = #line) -> Bool {
        let result = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: element)],
                                   timeout: timeout)
        XCTAssertEqual(result, .completed,
                       "Expected \(predicate.predicateFormat) on \(element)", file: file, line: line)
        return result == .completed
    }

    private func waitForValue(_ value: String, on element: XCUIElement,
                              file: StaticString = #filePath, line: UInt = #line) {
        wait(NSPredicate(format: "value == %@", value), on: element, file: file, line: line)
    }

    private func waitForLabel(_ label: String, on element: XCUIElement,
                             file: StaticString = #filePath, line: UInt = #line) {
        wait(NSPredicate(format: "label == %@", label), on: element, file: file, line: line)
    }

    private func waitGone(_ element: XCUIElement,
                          file: StaticString = #filePath, line: UInt = #line) {
        wait(NSPredicate(format: "exists == false"), on: element, file: file, line: line)
    }

    private func dismissObservedKeyboardOnboardingIfPresent(
        file: StaticString = #filePath, line: UInt = #line
    ) {
        // This is the exact iOS 26.2 first-use keyboard overlay observed in CI.
        // Do not tap generic Continue buttons or dismiss an ordinary keyboard.
        let introduction = app.otherElements["UIContinuousPathIntroductionView"]
        guard introduction.waitForExistence(timeout: 2) else { return }
        let message = introduction.staticTexts[
            "Speed up your typing by sliding your finger across the letters to compose a word."
        ]
        guard message.exists else { return }
        let continueButton = introduction.buttons["Continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5),
                      "The observed keyboard introduction has no Continue action", file: file, line: line)
        tapCenter(continueButton, evidenceName: "keyboard-first-use-introduction", file: file, line: line)
        waitGone(introduction, file: file, line: line)
    }

    private func tapCenter(_ element: XCUIElement,
                           evidenceName: String? = nil,
                           file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: 10), "Control missing", file: file, line: line)
        wait(NSPredicate { _, _ in element.isHittable }, on: element, file: file, line: line)
        let frame = element.frame
        let windowFrame = window.frame
        XCTAssertGreaterThan(frame.width, 0, file: file, line: line)
        XCTAssertGreaterThan(frame.height, 0, file: file, line: line)
        XCTAssertTrue(windowFrame.contains(CGPoint(x: frame.midX, y: frame.midY)),
                      "Control center is outside the application window: \(frame)", file: file, line: line)
        let coordinate = element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let identifier = element.identifier
        let targetDetails = """
            Physical tap: identifier=\(identifier), accessibility frame=\(frame), center=\(CGPoint(x: frame.midX, y: frame.midY)), app window=\(windowFrame)
            """
        print(targetDetails)
        if let evidenceName {
            let resolvedTarget = "\nResolved XCUICoordinate.screenPoint=\(coordinate.screenPoint)"
            let tree = XCTAttachment(string: targetDetails + resolvedTarget + "\n\n" + app.debugDescription)
            tree.name = evidenceName + " — immediately before physical tap"
            tree.lifetime = .keepAlways
            add(tree)
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = evidenceName + " — screen before physical tap"
            screenshot.lifetime = .keepAlways
            add(screenshot)
        }
        if identifier == "sidebar-new-chat" || identifier == "sidebar-toggle" {
            XCTAssertLessThanOrEqual(frame.width, 64,
                                     "Icon button exported an oversized accessibility target", file: file, line: line)
            XCTAssertLessThanOrEqual(frame.height, 64,
                                     "Icon button exported an oversized accessibility target", file: file, line: line)
        }
        coordinate.tap()
    }

    private func requireSidebar(_ open: Bool,
                                file: StaticString = #filePath, line: UInt = #line) {
        waitForValue(open ? "open" : "closed", on: toggle, file: file, line: line)
        if open {
            XCTAssertTrue(settings.waitForExistence(timeout: 10), file: file, line: line)
            wait(NSPredicate { _, _ in self.settings.isHittable }, on: settings, file: file, line: line)
            XCTAssertGreaterThan(settings.frame.width, 100, file: file, line: line)
            XCTAssertGreaterThanOrEqual(settings.frame.minX, window.frame.minX - 1,
                                        file: file, line: line)
            XCTAssertLessThanOrEqual(settings.frame.maxX, window.frame.maxX + 1,
                                     file: file, line: line)
            // The original content must remain visible beside the open drawer.
            XCTAssertGreaterThan(toggle.frame.minX, window.frame.minX + 150,
                                 "Workspace did not move away from the sidebar", file: file, line: line)
        } else {
            // SwiftUI can retain a hidden offscreen element in XCUI's snapshot.
            // Validate that the control is genuinely not touchable, including
            // after the drawer animation, rather than relying on exists=false.
            wait(NSPredicate { _, _ in !self.settings.isHittable },
                 on: settings, file: file, line: line)
            wait(NSPredicate { _, _ in self.toggle.isHittable }, on: toggle, file: file, line: line)
            let content = app.scrollViews["chat-history"].frame
            let viewport = window.frame
            // iPad window controls can legitimately inset the custom toolbar.
            // Measure the actual content, whose closed position is unchanged.
            XCTAssertEqual(content.minX, viewport.minX, accuracy: 2,
                           "Workspace did not return to the leading edge", file: file, line: line)
            XCTAssertEqual(content.width, viewport.width, accuracy: 2,
                           "Closed workspace must fill the actual window", file: file, line: line)
            XCTAssertTrue(viewport.contains(CGPoint(x: toggle.frame.midX, y: toggle.frame.midY)),
                          "Closed toolbar toggle is outside the window", file: file, line: line)
        }
    }

    private func setSidebar(_ open: Bool,
                            file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(toggle.waitForExistence(timeout: 10), file: file, line: line)
        let current = toggle.value as? String
        XCTAssertTrue(current == "open" || current == "closed",
                      "Toggle must expose the actual sidebar state", file: file, line: line)
        if current != (open ? "open" : "closed") {
            tapCenter(toggle, file: file, line: line)
        }
        requireSidebar(open, file: file, line: line)
    }

    private func openSettings() {
        setSidebar(true)
        tapCenter(settings)
        XCTAssertTrue(app.buttons["settings-category-personal"].waitForExistence(timeout: 10),
                      "The settings categories did not appear after a physical tap")
        XCTAssertTrue(app.buttons["settings-close"].isHittable)
    }

    private func navigateBackInSettings() {
        let candidates = app.navigationBars.buttons.matching(
            NSPredicate(format: "identifier != %@", "settings-close"))
        XCTAssertGreaterThan(candidates.count, 0, "No native navigation back button")
        tapCenter(candidates.firstMatch)
    }

    func testSettingsFromButtonAndNestedNavigation() {
        // Always exercise the actual closed -> open button transition, even on iPad.
        setSidebar(false)
        openSettings()
        tapCenter(app.buttons["settings-category-general"])
        tapCenter(app.buttons["settings-destination-generalSettings"])
        let option = app.switches["settings-example-toggle"]
        XCTAssertTrue(option.waitForExistence(timeout: 10))
        let oldValue = option.value as? String
        XCTAssertTrue(oldValue == "0" || oldValue == "1", "Switch must expose its native on/off value")
        // A Form Toggle exposes the entire row as a parent Switch. Its
        // actual tappable UISwitch is the nested child, not the row midpoint.
        let nativeSwitch = option.switches.firstMatch
        XCTAssertTrue(nativeSwitch.waitForExistence(timeout: 5),
                      "Expected the physical UISwitch inside the accessibility row")
        XCTAssertLessThan(nativeSwitch.frame.width, option.frame.width,
                          "Native UISwitch must have a distinct physical target")
        tapCenter(nativeSwitch)
        waitForValue(oldValue == "1" ? "0" : "1", on: option)
        navigateBackInSettings()
        XCTAssertTrue(app.buttons["settings-destination-generalSettings"].waitForExistence(timeout: 10))
        navigateBackInSettings()
        XCTAssertTrue(app.buttons["settings-category-personal"].waitForExistence(timeout: 10))
        tapCenter(app.buttons["settings-close"])
        waitGone(app.buttons["settings-category-personal"])
        requireSidebar(true)
        // Reopen and dismiss once more, catching stale presentation state.
        tapCenter(settings)
        XCTAssertTrue(app.buttons["settings-category-personal"].waitForExistence(timeout: 10))
        tapCenter(app.buttons["settings-close"])
        requireSidebar(true)
    }

    func testChatSelectionSearchAndKeyboard() {
        setSidebar(true)
        let search = input("sidebar-search")
        tapCenter(search)
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5),
                      "Search did not bring up the software keyboard")
        dismissObservedKeyboardOnboardingIfPresent()
        search.typeText("SwiftUI")
        waitForValue("SwiftUI", on: search)
        XCTAssertTrue(app.buttons["sidebar-chat-3"].waitForExistence(timeout: 10))
        waitGone(app.buttons["sidebar-chat-1"])
        waitGone(app.buttons["sidebar-chat-2"])
        tapCenter(app.buttons["sidebar-chat-3"])
        dismissObservedKeyboardOnboardingIfPresent()
        waitGone(app.keyboards.firstMatch)
        waitForLabel("תכנון אפליקציית SwiftUI", on: app.staticTexts["chat-title"])
        if !isWide { requireSidebar(false) }
        setSidebar(true)
        tapCenter(search)
        dismissObservedKeyboardOnboardingIfPresent()
        search.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 7))
        XCTAssertTrue(app.buttons["sidebar-chat-1"].waitForExistence(timeout: 10))
        tapCenter(app.buttons["sidebar-chat-2"])
        waitForLabel("בניית אוטומציה", on: app.staticTexts["chat-title"])
        if !isWide { requireSidebar(false) }
    }

    func testNewChatAndSend() {
        setSidebar(true)
        tapCenter(app.buttons["sidebar-new-chat"], evidenceName: "new-chat")
        XCTAssertTrue(app.staticTexts["chat-empty"].waitForExistence(timeout: 10))
        waitForLabel("שיחה חדשה", on: app.staticTexts["chat-title"])
        let composer = input("chat-input")
        tapCenter(composer)
        dismissObservedKeyboardOnboardingIfPresent()
        let text = "Sidebar QA message."
        composer.typeText(text)
        tapCenter(app.buttons["chat-send"])
        waitForLabel(text, on: app.staticTexts["chat-title"])
        XCTAssertTrue(app.scrollViews["chat-history"].staticTexts[text].firstMatch
            .waitForExistence(timeout: 10), "Sent text did not appear in the conversation")
        waitGone(app.staticTexts["chat-empty"])
    }

    func testQuickActionsAndLibrary() {
        setSidebar(true)
        for action in ["translate", "polish", "summarize"] {
            XCTContext.runActivity(named: "Open and execute \(action)") { _ in
                tapCenter(app.buttons["sidebar-action-" + action])
                let actionInput = input("quick-action-input")
                tapCenter(actionInput)
                dismissObservedKeyboardOnboardingIfPresent()
                actionInput.typeText("Test text")
                tapCenter(app.buttons["quick-action-run"])
                XCTAssertTrue(app.staticTexts["quick-action-result"].waitForExistence(timeout: 10))
                tapCenter(app.buttons["quick-action-close"])
                waitGone(app.buttons["quick-action-close"])
                requireSidebar(true)
            }
        }
        tapCenter(app.buttons["sidebar-library"])
        XCTAssertTrue(app.staticTexts["library-title"].waitForExistence(timeout: 10))
        tapCenter(app.buttons["library-back"])
        waitGone(app.staticTexts["library-title"])
        XCTAssertTrue(input("chat-input").waitForExistence(timeout: 10),
                      "Returning from the library did not restore the chat composer")
    }

    func testRepeatedOpenCloseAndFullSurfaceDrags() {
        for _ in 0..<3 {
            setSidebar(false)
            setSidebar(true)
        }
        if isWide {
            // Desktop-style iPad columns use their toggle; compact windows run the pan cases.
            tapCenter(settings)
            XCTAssertTrue(app.buttons["settings-category-personal"].waitForExistence(timeout: 10))
            return
        }
        for (x, y) in [(0.12, 0.20), (0.36, 0.50), (0.50, 0.78)] {
            XCTContext.runActivity(named: "Open drawer from content y=\(y)") { _ in
                setSidebar(false)
                let start = window.coordinate(withNormalizedOffset: CGVector(dx: x, dy: y))
                let end = window.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: y))
                start.press(forDuration: 0.05, thenDragTo: end)
                requireSidebar(true)
                // Start in the visible chat strip, not only on the sidebar.
                let closeStart = window.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: y))
                let closeEnd = window.coordinate(withNormalizedOffset: CGVector(dx: 0.12, dy: y))
                closeStart.press(forDuration: 0.05, thenDragTo: closeEnd)
                requireSidebar(false)
            }
        }
        setSidebar(true)
        // Close using the sidebar itself, then verify the settings action after another drag.
        let sidebarStartX = (settings.frame.maxX - window.frame.minX - 24) / window.frame.width
        let sidebarStart = window.coordinate(withNormalizedOffset: CGVector(dx: sidebarStartX, dy: 0.55))
        let sidebarEnd = window.coordinate(withNormalizedOffset: CGVector(dx: 0.04, dy: 0.55))
        sidebarStart.press(forDuration: 0.05, thenDragTo: sidebarEnd)
        requireSidebar(false)
        window.coordinate(withNormalizedOffset: CGVector(dx: 0.10, dy: 0.5))
            .press(forDuration: 0.05,
                   thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)))
        requireSidebar(true)

        // Exercise real toolbar and composer controls, beyond the approximate
        // content heights above. Focus the composer through an ordinary tap so
        // its drag runs with the real keyboard and actual adjusted geometry.
        for controlID in ["sidebar-toggle", "chat-input"] {
            XCTContext.runActivity(named: "Drag from measured \(controlID) row") { _ in
                setSidebar(false)
                let control = controlID == "sidebar-toggle" ? toggle : input("chat-input")
                XCTAssertTrue(control.waitForExistence(timeout: 10))
                if controlID == "chat-input" {
                    tapCenter(control)
                    XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 10),
                                  "The composer tap did not show the software keyboard")
                    dismissObservedKeyboardOnboardingIfPresent()
                }
                let openY = (control.frame.midY - window.frame.minY) / window.frame.height
                let openStart = control.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                let openEnd = window.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: openY))
                openStart.press(forDuration: 0.05, thenDragTo: openEnd)
                requireSidebar(true)

                // The translated input center may be offscreen. Start the close
                // in the visible content strip at the control's current midY,
                // remeasuring in case the keyboard geometry changed.
                XCTAssertTrue(control.waitForExistence(timeout: 10))
                let closeY = (control.frame.midY - window.frame.minY) / window.frame.height
                let closeStart = window.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: closeY))
                let closeEnd = window.coordinate(withNormalizedOffset: CGVector(dx: 0.12, dy: closeY))
                closeStart.press(forDuration: 0.05, thenDragTo: closeEnd)
                requireSidebar(false)
            }
        }
        setSidebar(true)
        tapCenter(settings)
        XCTAssertTrue(app.buttons["settings-category-personal"].waitForExistence(timeout: 10))
    }

    func testVerticalGesturesDoNotToggleSidebar() {
        setSidebar(false)
        let history = app.scrollViews["chat-history"]
        XCTAssertTrue(history.waitForExistence(timeout: 10))
        history.swipeUp()
        requireSidebar(false)
        history.swipeDown()
        requireSidebar(false)
        setSidebar(true)
        let list = app.scrollViews["sidebar-chat-list"]
        XCTAssertTrue(list.waitForExistence(timeout: 10))
        // Populate through the real new-chat control until this device's viewport
        // has enough rows to scroll. Four sample chats alone cannot prove that
        // the vertical recognizer still scrolls content.
        let originalRow = app.buttons["sidebar-chat-4"]
        XCTAssertTrue(originalRow.waitForExistence(timeout: 10))
        let rowHeight = max(originalRow.frame.height, 44)
        let extraChats = min(32, max(6, Int(ceil(list.frame.height / rowHeight)) + 3))
        for _ in 0..<extraChats {
            tapCenter(app.buttons["sidebar-new-chat"])
            setSidebar(true)
        }
        let topRow = app.buttons["sidebar-chat-1"]
        XCTAssertTrue(topRow.waitForExistence(timeout: 10))
        let initialY = topRow.frame.minY
        list.swipeUp()
        requireSidebar(true)
        wait(NSPredicate { _, _ in
            !topRow.exists || topRow.frame.minY < initialY - 20
        }, on: topRow)
        list.swipeDown()
        requireSidebar(true)
        wait(NSPredicate { _, _ in
            topRow.exists && abs(topRow.frame.minY - initialY) < 10
        }, on: topRow)
        tapCenter(settings)
        XCTAssertTrue(app.buttons["settings-category-personal"].waitForExistence(timeout: 10))
    }

    func testRotationPreservesLayoutAndSettings() {
        setSidebar(true)
        let portrait = window.frame
        let portraitImage = XCTAttachment(screenshot: app.screenshot())
        portraitImage.name = "portrait-sidebar"
        portraitImage.lifetime = .keepAlways
        add(portraitImage)
        XCUIDevice.shared.orientation = .landscapeLeft
        wait(NSPredicate { _, _ in self.window.frame.width > self.window.frame.height }, on: window)
        XCTAssertGreaterThan(window.frame.width, portrait.width,
                             "Application did not adapt its window after rotation")
        setSidebar(true)
        tapCenter(settings)
        XCTAssertTrue(app.buttons["settings-category-personal"].waitForExistence(timeout: 10))
        let landscapeImage = XCTAttachment(screenshot: app.screenshot())
        landscapeImage.name = "landscape-settings"
        landscapeImage.lifetime = .keepAlways
        add(landscapeImage)
        tapCenter(app.buttons["settings-close"])
        XCUIDevice.shared.orientation = .portrait
        wait(NSPredicate { _, _ in self.window.frame.height > self.window.frame.width }, on: window)
        setSidebar(false)
        openSettings()
    }

    func testContextMenuUnpinsAndRepinsChat() {
        setSidebar(true)
        let chat = app.buttons["sidebar-chat-1"]
        let otherPinnedChat = app.buttons["sidebar-chat-2"]
        waitForValue("pinned", on: chat)
        XCTAssertTrue(otherPinnedChat.waitForExistence(timeout: 10))
        XCTAssertLessThan(chat.frame.midY, otherPinnedChat.frame.midY,
                          "The seed chat should begin before chat 2 in the pinned section")
        wait(NSPredicate { _, _ in chat.isHittable }, on: chat)
        chat.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 1.1)
        // These are the actual Hebrew labels in HistoryChatRow.contextMenu.
        let unpin = app.buttons["בטל הצמדה"].firstMatch
        tapCenter(unpin)
        waitGone(unpin)
        waitForValue("unpinned", on: chat)
        requireSidebar(true)
        XCTAssertGreaterThan(chat.frame.midY, otherPinnedChat.frame.midY,
                             "Unpinning did not move the chat below the pinned section")

        wait(NSPredicate { _, _ in chat.isHittable }, on: chat)
        chat.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 1.1)
        let pin = app.buttons["הצמד שיחה"].firstMatch
        tapCenter(pin)
        waitGone(pin)
        waitForValue("pinned", on: chat)
        requireSidebar(true)
        XCTAssertLessThan(chat.frame.midY, otherPinnedChat.frame.midY,
                          "Re-pinning did not return the chat to its pinned position")
        // A completed context menu must leave ordinary sidebar taps usable.
        tapCenter(settings)
        XCTAssertTrue(app.buttons["settings-category-personal"].waitForExistence(timeout: 10))
        tapCenter(app.buttons["settings-close"])
        requireSidebar(true)
    }

    func testHebrewRTLRetainsPhysicalLeftRevealAndSettings() {
        app.terminate()
        app.launchArguments = [
            "-ui-testing",
            "-AppleLanguages", "(he)",
            "-AppleLocale", "he_IL",
            // Apple's documented iOS RTL test override also works before a
            // prototype has a complete Hebrew localization in its bundle.
            "-AppleTextDirection", "YES"
        ]
        app.launch()
        XCTAssertTrue(toggle.waitForExistence(timeout: 20))
        setSidebar(false)
        setSidebar(true)

        let newChat = app.buttons["sidebar-new-chat"]
        XCTAssertTrue(newChat.waitForExistence(timeout: 10))
        XCTAssertLessThan(newChat.frame.midX, settings.frame.midX,
                          "RTL was not active inside the sidebar: its trailing new-chat button must mirror to the left")
        XCTAssertLessThanOrEqual(settings.frame.maxX, toggle.frame.minX + 1,
                                 "The physical-left sidebar overlaps the visible chat toggle in RTL")
        let rtlSidebar = XCTAttachment(screenshot: app.screenshot())
        rtlSidebar.name = "hebrew-rtl-open-sidebar"
        rtlSidebar.lifetime = .keepAlways
        add(rtlSidebar)
        tapCenter(settings)
        XCTAssertTrue(app.buttons["settings-category-personal"].waitForExistence(timeout: 10))
        tapCenter(app.buttons["settings-close"])
        requireSidebar(true)

        if !isWide {
            // Physical direction stays the accepted left-drawer direction even
            // though the controls and Hebrew text use a right-to-left locale.
            window.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5))
                .press(forDuration: 0.05,
                       thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: 0.12, dy: 0.5)))
            requireSidebar(false)
            window.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.5))
                .press(forDuration: 0.05,
                       thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: 0.96, dy: 0.5)))
            requireSidebar(true)
        }
        // Prove the same real toggle can close and fully reveal again in RTL.
        setSidebar(false)
        openSettings()
        tapCenter(app.buttons["settings-close"])
        requireSidebar(true)
    }
}
