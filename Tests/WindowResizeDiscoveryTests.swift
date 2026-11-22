import XCTest
import UIKit

/// Exercises the iPad window managed by the OS, without changing the app's view
/// hierarchy or supplying a test-only width. Run the diagnostic selector first
/// when adopting a new simulator runtime, and inspect its saved attachments.
///
/// Diagnostic only:
///   -only-testing:HanlinSidebarQATests/WindowResizeDiscoveryTests/testDiscoverSystemWindowControls
/// Required resizing gate:
///   -only-testing:HanlinSidebarQATests/WindowResizeDiscoveryTests/testActualIPadWindowNarrowAndRestore
///
/// The diagnostic test passing means only that evidence was collected. Only the
/// required gate asserts that an actual app window became narrow and wide again.
final class WindowResizeDiscoveryTests: XCTestCase {
    private let preferences = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
    private let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    private let compactBoundary: CGFloat = 640
    private let requestedNarrowWidth: CGFloat = 480
    private var originalOrientation: UIDeviceOrientation = .unknown
    private var applicationUnderTest: XCUIApplication?

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
        originalOrientation = XCUIDevice.shared.orientation
    }

    override func tearDownWithError() throws {
        if testRun?.hasSucceeded == false, let app = applicationUnderTest {
            attachState("failure-final-state", app: app)
        }
        XCUIDevice.shared.orientation = originalOrientation == .unknown ? .portrait : originalOrientation
        try super.tearDownWithError()
    }

    func testDiscoverSystemWindowControls() throws {
        try requireIPad()
        let app = XCUIApplication()
        applicationUnderTest = app
        XCUIDevice.shared.orientation = .landscapeLeft
        let modeObserved = discoverAndSelectWindowedApps()
        app.launch()
        guard app.windows.firstMatch.waitForExistence(timeout: 15) else {
            attachState("discovery-no-app-window", app: app)
            attachText("No app window appeared. Discovery has no resize assertion.", name: "discovery-outcome")
            return
        }

        let before = primaryWindow(in: app).frame
        _ = openSidebarForMeasurement(app)
        attachState("discovery-before", app: app)
        let narrowed = physicallyNarrow(app)
        let narrow = primaryWindow(in: app).frame
        attachState("discovery-narrow-before-opening-sidebar", app: app)
        _ = openSidebarForMeasurement(app)
        attachState("discovery-after-narrow-attempt", app: app)
        let restored = narrowed && physicallyRestore(app, to: before)
        attachState("discovery-after-restore-attempt", app: app)
        attachText("""
            DIAGNOSTIC ONLY — not a resizing acceptance test.
            Windowed Apps setting observed/selected: \(modeObserved)
            Initial real window: \(before)
            Window after narrowing attempt: \(narrow)
            Window after restoration attempt: \(primaryWindow(in: app).frame)
            Observed real narrowing: \(narrowed)
            Observed real restoration: \(restored)
            """, name: "discovery-outcome")
    }

    func testActualIPadWindowNarrowAndRestore() throws {
        try requireIPad()
        let app = XCUIApplication()
        applicationUnderTest = app
        XCUIDevice.shared.orientation = .landscapeLeft
        let modeObserved = discoverAndSelectWindowedApps()
        app.launch()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 15), "The app has no accessible window.")

        // A previous discovery run may have left this app in a smaller window.
        // Use only a currently exposed system control to establish a wide start.
        if primaryWindow(in: app).frame.width < compactBoundary {
            _ = tapObservedFullScreenControl(app)
            _ = waitFor(timeout: 6) { self.primaryWindow(in: app).frame.width >= self.compactBoundary }
        }
        XCTAssertTrue(openSidebarForMeasurement(app), "The sidebar-toggle must report its real open state before layout measurement.")
        let initial = primaryWindow(in: app).frame
        attachState("required-wide-before", app: app)
        XCTAssertGreaterThanOrEqual(initial.width, compactBoundary,
            "A real wide starting window is required. Inspect Settings and system-control attachments; no fake frame is substituted.")
        XCTAssertTrue(app.scrollViews["chat-history"].waitForExistence(timeout: 5), "The actual chat ScrollView must have the chat-history identifier.")
        let initialContentRatio = app.scrollViews["chat-history"].frame.width / initial.width
        XCTAssertLessThan(initialContentRatio, 0.90,
            "With the wide sidebar open, chat-history should occupy the remaining column, not the whole window.")

        let narrowed = physicallyNarrow(app)
        let narrow = primaryWindow(in: app).frame
        attachState("required-narrow-before-opening-sidebar", app: app)
        let sidebarOpened = openSidebarForMeasurement(app)
        attachState("required-narrow", app: app)
        XCTAssertTrue(narrowed, """
            The OS window did not resize below \(compactBoundary) points.
            Initial: \(initial); observed: \(narrow).
            Windowed Apps setting observed/selected: \(modeObserved).
            Check attached Settings/SpringBoard hierarchies and screenshots.
            """)
        XCTAssertLessThan(narrow.width, compactBoundary,
            "The real UIWindow must cross the app's compact layout boundary.")
        XCTAssertLessThan(narrow.width, initial.width - 100,
            "An appreciable real window-width change is required.")
        XCTAssertTrue(sidebarOpened, "The sidebar-toggle did not report open in the narrow real window.")
        XCTAssertTrue(app.scrollViews["chat-history"].waitForExistence(timeout: 5), "The real chat ScrollView must remain in the hierarchy.")
        let narrowContentRatio = app.scrollViews["chat-history"].frame.width / narrow.width
        XCTAssertGreaterThan(narrowContentRatio, 0.90, """
            The open compact drawer must leave chat-history at the logical window width.
            A compatibility-scaled wide layout retains two narrower columns.
            Measured chat/window width ratio: \(narrowContentRatio).
            Inspect the open/closed narrow screenshots and frames if this runtime clips accessibility frames.
            """)

        // These checks run inside the actual resized scene, before widening it.
        // This remains one XCTest selector so CI's expected test count is one.
        verifyNarrowWindowInteractions(app, referenceWidth: narrow.width)

        let restored = physicallyRestore(app, to: initial)
        let restoredSidebarOpened = openSidebarForMeasurement(app)
        let final = primaryWindow(in: app).frame
        attachState("required-wide-restored", app: app)
        XCTAssertTrue(restored, "The real window failed to restore. Initial: \(initial); narrow: \(narrow); restored: \(final).")
        XCTAssertGreaterThanOrEqual(final.width, compactBoundary)
        XCTAssertGreaterThanOrEqual(final.width, restorationThreshold(for: initial))
        XCTAssertTrue(restoredSidebarOpened, "The sidebar-toggle did not report open after restoring the real window.")
        XCTAssertTrue(app.scrollViews["chat-history"].waitForExistence(timeout: 5))
        let restoredContentRatio = app.scrollViews["chat-history"].frame.width / final.width
        XCTAssertLessThan(restoredContentRatio, 0.90, "Restoring a wide window must restore the two-column layout.")
        attachText("""
            REQUIRED REAL-WINDOW RESIZE GATE PASSED
            Wide before: \(initial)
            Narrow: \(narrow)
            Wide restored: \(final)
            Open-sidebar chat/window width ratios: \(initialContentRatio) → \(narrowContentRatio) → \(restoredContentRatio)
            Narrow interactions verified: Settings/category/detail/switch/back/close;
            content drags at three heights; closing from sidebar and visible content;
            search keyboard, filtering, chat selection, and keyboard dismissal.
            Widths are XCUIElement window frames, not app-supplied labels or a test-only SwiftUI frame.
            """, name: "required-verified-window-geometry")
    }

    private func requireIPad() throws {
        guard UIDevice.current.userInterfaceIdiom == .pad else {
            throw XCTSkip("System window resizing is an iPad test; run this selector on an iPad simulator.")
        }
    }

    private func verifyNarrowWindowInteractions(_ app: XCUIApplication, referenceWidth: CGFloat) {
        XCTContext.runActivity(named: "Real narrow window — Settings and nested navigation") { _ in
            assertNarrowWindow(app, referenceWidth: referenceWidth)
            setActualSidebar(app, open: true)
            tapPhysicalControl(app.buttons["sidebar-settings"], in: app)
            let personal = app.buttons["settings-category-personal"]
            XCTAssertTrue(personal.waitForExistence(timeout: 10), "Physical Settings tap did not present its categories in the narrow window.")
            attachState("narrow-settings-home", app: app)
            tapPhysicalControl(personal, in: app)
            tapPhysicalControl(app.buttons["settings-destination-profile"], in: app)

            let option = app.switches["settings-example-toggle"]
            XCTAssertTrue(option.waitForExistence(timeout: 10))
            let previous = option.value as? String
            XCTAssertTrue(previous == "0" || previous == "1", "The nested switch must expose its native state.")
            tapPhysicalControl(option, in: app)
            XCTAssertTrue(waitFor(timeout: 5) { option.value as? String == (previous == "1" ? "0" : "1") },
                "The nested Settings switch did not respond to its physical tap.")
            attachState("narrow-settings-profile-switch-changed", app: app)

            navigateBackInSettings(app)
            XCTAssertTrue(app.buttons["settings-destination-profile"].waitForExistence(timeout: 10))
            navigateBackInSettings(app)
            XCTAssertTrue(personal.waitForExistence(timeout: 10))
            tapPhysicalControl(app.buttons["settings-close"], in: app)
            XCTAssertTrue(waitFor(timeout: 10) { !personal.exists && !app.buttons["settings-close"].exists })
            assertActualSidebar(app, open: true)
            assertNarrowWindow(app, referenceWidth: referenceWidth)
            attachState("narrow-settings-dismissed", app: app)
        }

        XCTContext.runActivity(named: "Real narrow window — drags from content and sidebar") { _ in
            for (startX, y) in [(0.12, 0.20), (0.36, 0.50), (0.50, 0.78)] {
                setActualSidebar(app, open: false)
                dragInsideWindow(app, from: CGVector(dx: startX, dy: y),
                    to: CGVector(dx: 0.97, dy: y), name: "open-content-y-\(y)")
                assertActualSidebar(app, open: true)
                attachState("narrow-open-from-content-y-\(y)", app: app)

                // The right-hand strip is still visible while the sidebar is
                // open; this exercises the shared gesture from that content.
                dragInsideWindow(app, from: CGVector(dx: 0.94, dy: y),
                    to: CGVector(dx: 0.10, dy: y), name: "close-content-y-\(y)")
                assertActualSidebar(app, open: false)
                assertNarrowWindow(app, referenceWidth: referenceWidth)
            }

            setActualSidebar(app, open: true)
            let windowFrame = primaryWindow(in: app).frame
            let sidebarRight = app.buttons["sidebar-settings"].frame.maxX
            let sidebarX = (sidebarRight - windowFrame.minX - 24) / windowFrame.width
            XCTAssertGreaterThan(sidebarX, 0.10)
            XCTAssertLessThan(sidebarX, 0.90)
            dragInsideWindow(app, from: CGVector(dx: sidebarX, dy: 0.55),
                to: CGVector(dx: 0.04, dy: 0.55), name: "close-from-sidebar")
            assertActualSidebar(app, open: false)
            dragInsideWindow(app, from: CGVector(dx: 0.10, dy: 0.50),
                to: CGVector(dx: 0.92, dy: 0.50), name: "reopen-after-sidebar-drag")
            assertActualSidebar(app, open: true)
            assertNarrowWindow(app, referenceWidth: referenceWidth)

            // A successful drag must leave normal controls working afterward.
            tapPhysicalControl(app.buttons["sidebar-settings"], in: app)
            XCTAssertTrue(app.buttons["settings-category-personal"].waitForExistence(timeout: 10))
            tapPhysicalControl(app.buttons["settings-close"], in: app)
            XCTAssertTrue(waitFor(timeout: 10) { !app.buttons["settings-close"].exists })
            assertActualSidebar(app, open: true)
            attachState("narrow-settings-works-after-all-drag-surfaces", app: app)
        }

        XCTContext.runActivity(named: "Real narrow window — search, keyboard and chat selection") { _ in
            setActualSidebar(app, open: true)
            let search = app.descendants(matching: .any).matching(identifier: "sidebar-search").firstMatch
            tapPhysicalControl(search, in: app)
            XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "Search did not focus the software keyboard in the narrow scene.")
            search.typeText("SwiftUI")
            XCTAssertTrue(waitFor(timeout: 5) { search.value as? String == "SwiftUI" })
            XCTAssertTrue(app.buttons["sidebar-chat-3"].waitForExistence(timeout: 10))
            XCTAssertTrue(waitFor(timeout: 5) {
                !app.buttons["sidebar-chat-1"].exists && !app.buttons["sidebar-chat-2"].exists
            }, "The search field accepted text but did not filter the actual chat list.")
            assertNarrowWindow(app, referenceWidth: referenceWidth)
            attachState("narrow-search-filtered-with-keyboard", app: app)
            selectActualChat(app, id: "3", expectedTitle: "תכנון אפליקציית SwiftUI")
            attachState("narrow-filtered-chat-selected", app: app)

            setActualSidebar(app, open: true)
            tapPhysicalControl(search, in: app)
            XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
            search.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "SwiftUI".count))
            XCTAssertTrue(app.buttons["sidebar-chat-1"].waitForExistence(timeout: 10), "Clearing the search did not restore the original chats.")
            selectActualChat(app, id: "2", expectedTitle: "בניית אוטומציה")
            assertNarrowWindow(app, referenceWidth: referenceWidth)
            setActualSidebar(app, open: true)
            attachState("narrow-search-cleared-second-chat-selected", app: app)
        }
    }

    private func assertNarrowWindow(_ app: XCUIApplication, referenceWidth: CGFloat) {
        let frame = primaryWindow(in: app).frame
        XCTAssertGreaterThan(frame.width, 0)
        XCTAssertLessThan(frame.width, compactBoundary, "The interaction escaped the actual narrow OS window: \(frame).")
        XCTAssertEqual(frame.width, referenceWidth, accuracy: 12,
            "A control interaction unexpectedly changed the OS window width.")
    }

    private func setActualSidebar(_ app: XCUIApplication, open: Bool) {
        let toggle = app.buttons["sidebar-toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        let expected = open ? "open" : "closed"
        let state = toggle.value as? String
        XCTAssertTrue(state == "open" || state == "closed", "The real sidebar control must expose its current state.")
        if state != expected { tapPhysicalControl(toggle, in: app) }
        assertActualSidebar(app, open: open)
    }

    private func assertActualSidebar(_ app: XCUIApplication, open: Bool) {
        let toggle = app.buttons["sidebar-toggle"]
        let settings = app.buttons["sidebar-settings"]
        XCTAssertTrue(waitFor(timeout: 10) { toggle.exists && toggle.value as? String == (open ? "open" : "closed") },
            "The actual sidebar did not become \(open ? "open" : "closed").")
        let frame = primaryWindow(in: app).frame
        if open {
            XCTAssertTrue(settings.waitForExistence(timeout: 10))
            XCTAssertTrue(waitFor(timeout: 5) { settings.isHittable }, "The sidebar reports open but its Settings control is not interactive.")
            XCTAssertGreaterThan(settings.frame.width, 100)
            XCTAssertGreaterThanOrEqual(settings.frame.minX, frame.minX - 1)
            XCTAssertLessThanOrEqual(settings.frame.maxX, frame.maxX + 1)
            XCTAssertGreaterThan(toggle.frame.minX, frame.minX + 150,
                "The content did not move aside to reveal the actual compact sidebar.")
        } else {
            XCTAssertTrue(waitFor(timeout: 5) { !settings.exists }, "Covered sidebar controls remained exposed after closing.")
            XCTAssertTrue(waitFor(timeout: 5) { toggle.isHittable }, "Window controls occlude the closed sidebar toggle.")
            XCTAssertTrue(frame.contains(CGPoint(x: toggle.frame.midX, y: toggle.frame.midY)))
            let content = app.scrollViews["chat-history"].frame
            XCTAssertEqual(content.minX, frame.minX, accuracy: 2,
                "The content did not return to the leading edge after closing.")
            XCTAssertEqual(content.width, frame.width, accuracy: 2,
                "The closed content must fill the real window despite toolbar corner insets.")
        }
    }

    private func tapPhysicalControl(_ element: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(element.waitForExistence(timeout: 10), "Missing control: \(element).")
        XCTAssertTrue(waitFor(timeout: 5) { element.isHittable }, "Control is not hittable: \(elementDetails(element)).")
        let frame = element.frame
        XCTAssertGreaterThan(frame.width, 0)
        XCTAssertGreaterThan(frame.height, 0)
        XCTAssertTrue(primaryWindow(in: app).frame.contains(CGPoint(x: frame.midX, y: frame.midY)),
            "The physical tap would fall outside the real app window: \(frame).")
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    private func navigateBackInSettings(_ app: XCUIApplication) {
        let buttons = app.navigationBars.buttons.matching(NSPredicate(format: "identifier != %@", "settings-close"))
        guard let back = buttons.allElementsBoundByIndex.first(where: { $0.exists && $0.isHittable }) else {
            XCTFail("The actual Settings navigation bar has no hittable native back control.")
            return
        }
        tapPhysicalControl(back, in: app)
    }

    private func dragInsideWindow(_ app: XCUIApplication, from start: CGVector, to end: CGVector, name: String) {
        let window = primaryWindow(in: app)
        let origin = window.coordinate(withNormalizedOffset: start)
        let destination = window.coordinate(withNormalizedOffset: end)
        attachText("Window: \(window.frame)\nStart: \(origin.screenPoint)\nEnd: \(destination.screenPoint)", name: "narrow-gesture-" + name)
        origin.press(forDuration: 0.05, thenDragTo: destination)
    }

    private func selectActualChat(_ app: XCUIApplication, id: String, expectedTitle: String) {
        let row = app.buttons["sidebar-chat-" + id]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        let keyboard = app.keyboards.firstMatch
        let center = CGPoint(x: row.frame.midX, y: row.frame.midY)
        if !row.isHittable || !primaryWindow(in: app).frame.contains(center)
            || (keyboard.exists && keyboard.frame.contains(center)) {
            // On a short real window, the keyboard can cover the result. Close
            // the actual drawer to resign search focus, then reopen the same
            // filtered list; never resize the view or skip the selection check.
            attachState("narrow-chat-\(id)-keyboard-covers-result", app: app)
            setActualSidebar(app, open: false)
            XCTAssertTrue(waitFor(timeout: 5) { !keyboard.exists }, "Closing the drawer did not dismiss the search keyboard.")
            setActualSidebar(app, open: true)
        }
        let list = app.scrollViews["sidebar-chat-list"]
        for _ in 0..<3 {
            if row.exists && row.isHittable { break }
            XCTAssertTrue(list.exists && list.isHittable, "The original chat list is not scrollable to its result.")
            list.swipeUp()
            assertActualSidebar(app, open: true)
        }
        tapPhysicalControl(row, in: app)
        assertActualSidebar(app, open: false)
        XCTAssertTrue(waitFor(timeout: 5) { !keyboard.exists }, "Selecting a real chat did not dismiss search focus.")
        let title = app.staticTexts["chat-title"]
        XCTAssertTrue(waitFor(timeout: 10) { title.exists && title.label == expectedTitle },
            "Selecting chat \(id) did not display its actual conversation.")
    }

    /// Settings labels are candidate queries, not assumptions about the UI.
    /// Every tap requires a runtime-existing, hittable element. An unknown
    /// hierarchy is saved for diagnosis; the strict test still requires proof
    /// from actual window geometry, even when Windowed Apps is already default.
    @discardableResult
    private func discoverAndSelectWindowedApps() -> Bool {
        preferences.launch()
        _ = preferences.wait(for: .runningForeground, timeout: 10)
        attachState("settings-initial", app: preferences)

        let sectionNames = ["Multitasking & Gestures", "Multitasking and Gestures", "Multitasking"]
        let modeNames = ["Windowed Apps"]
        if let mode = visibleElement(named: modeNames, in: [preferences]) {
            return selectWindowedApps(mode)
        }
        if let section = visibleElement(named: sectionNames, in: [preferences]) {
            tapAndRecord(section, reason: "open-multitasking-settings")
        } else {
            // Find the real settings row by scrolling an observed table. Never
            // tap a guessed coordinate for a row or declare a guessed selection.
            let table = preferences.tables.firstMatch
            if table.exists && table.isHittable {
                for _ in 0..<5 {
                    table.swipeUp()
                    if let section = visibleElement(named: sectionNames, in: [preferences]) {
                        tapAndRecord(section, reason: "open-multitasking-settings-after-scroll")
                        break
                    }
                }
            }
            if visibleElement(named: modeNames, in: [preferences]) == nil,
               let search = preferences.searchFields.allElementsBoundByIndex.first(where: { $0.exists && $0.isHittable }) {
                tapAndRecord(search, reason: "search-settings")
                search.typeText("Multitasking")
                _ = waitFor(timeout: 5) { self.visibleElement(named: sectionNames, in: [self.preferences]) != nil }
                if let result = visibleElement(named: sectionNames, in: [preferences]) {
                    tapAndRecord(result, reason: "open-observed-settings-search-result")
                }
            }
        }

        _ = waitFor(timeout: 5) { self.visibleElement(named: modeNames, in: [self.preferences]) != nil }
        attachState("settings-multitasking-candidates", app: preferences)
        guard let mode = visibleElement(named: modeNames, in: [preferences]) else {
            attachText("Windowed Apps was not exposed under the known exact labels. No selection is claimed. Inspect settings-multitasking-candidates; the strict test must still prove real resizing.", name: "settings-selection-unresolved")
            return false
        }
        return selectWindowedApps(mode)
    }

    private func selectWindowedApps(_ mode: XCUIElement) -> Bool {
        attachText("Observed Windowed Apps: \(elementDetails(mode)); selected=\(mode.isSelected)", name: "settings-mode-before")
        if !mode.isSelected {
            tapAndRecord(mode, reason: "select-observed-windowed-apps")
        }
        attachState("settings-windowed-apps-selected", app: preferences)
        // The setting's checkmark is not exposed consistently across runtimes;
        // actual resizing is the independent acceptance condition below.
        return true
    }

    private func physicallyNarrow(_ app: XCUIApplication) -> Bool {
        let initial = primaryWindow(in: app).frame
        guard initial.width >= compactBoundary else { return false }

        // Public iPad instructions permit resizing from the bottom-right corner.
        // Coordinates derive from the live OS window, and each drag is checked
        // against a new OS window frame. The small insets accommodate the visible
        // corner grabber across runtimes without assuming an accessibility ID.
        for inset in [CGFloat(4), CGFloat(12), CGFloat(22)] {
            let window = primaryWindow(in: app)
            let frame = window.frame
            let target = CGPoint(
                x: frame.minX + requestedNarrowWidth - inset,
                y: frame.minY + max(400, frame.height * 0.80) - inset
            )
            physicalCornerDrag(app: app, window: window, inset: inset, target: target, name: "narrow")
            if waitFor(timeout: 4, condition: {
                let width = self.primaryWindow(in: app).frame.width
                return width > 0 && width < self.compactBoundary && width <= initial.width - 100
            }) {
                return true
            }
            attachState("narrow-attempt-inset-\(Int(inset))", app: app)
        }
        return false
    }

    private func physicallyRestore(_ app: XCUIApplication, to baseline: CGRect) -> Bool {
        let threshold = restorationThreshold(for: baseline)
        for inset in [CGFloat(4), CGFloat(12), CGFloat(22)] {
            let window = primaryWindow(in: app)
            let target = CGPoint(x: baseline.maxX - inset, y: baseline.maxY - inset)
            physicalCornerDrag(app: app, window: window, inset: inset, target: target, name: "restore")
            if waitFor(timeout: 4, condition: {
                self.primaryWindow(in: app).frame.width >= threshold
            }) {
                return true
            }
            attachState("restore-attempt-inset-\(Int(inset))", app: app)
        }
        // Some versions snap the corner to a smaller preset. A real, currently
        // exposed Zoom/Full Screen action is an acceptable OS restore operation.
        if tapObservedFullScreenControl(app) {
            return waitFor(timeout: 6) { self.primaryWindow(in: app).frame.width >= threshold }
        }
        return false
    }

    private func physicalCornerDrag(app: XCUIApplication, window: XCUIElement, inset: CGFloat, target: CGPoint, name: String) {
        let frame = window.frame
        let handle = inset == 4 ? observedResizeHandle(app, near: frame) : nil
        let start: XCUICoordinate
        if let handle = handle {
            start = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        } else {
            start = window.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 1))
                .withOffset(CGVector(dx: -inset, dy: -inset))
        }
        let finish = window.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: target.x - frame.minX, dy: target.y - frame.minY))
        attachText("""
            Physical OS-corner drag: \(name)
            Measured window: \(frame)
            Origin: \(handle.map(elementDetails) ?? "documented physical bottom-right window corner; no accessible handle used")
            Start: \(start.screenPoint)
            End: \(finish.screenPoint)
            """, name: "physical-\(name)-inset-\(Int(inset))")
        start.press(forDuration: 0.3, thenDragTo: finish)
    }

    private func observedResizeHandle(_ app: XCUIApplication, near frame: CGRect) -> XCUIElement? {
        let names = ["Resize Handle", "Resize handle", "Window Resize Handle", "Resize Window", "Resize window", "Resize"]
        guard let handle = visibleElement(named: names, in: [springboard, app]) else { return nil }
        let bounds = handle.frame
        // A menu action called Resize is not the physical corner affordance.
        guard bounds.width <= 80, bounds.height <= 80,
              abs(bounds.midX - frame.maxX) <= 48,
              abs(bounds.midY - frame.maxY) <= 48 else { return nil }
        return handle
    }

    private func openSidebarForMeasurement(_ app: XCUIApplication) -> Bool {
        let toggle = app.buttons["sidebar-toggle"]
        guard toggle.waitForExistence(timeout: 5) else { return false }
        if toggle.value as? String == "open" { return true }
        guard toggle.value as? String == "closed", toggle.isHittable else { return false }
        tapAndRecord(toggle, reason: "open-real-sidebar-for-layout-measurement")
        return waitFor(timeout: 5) { toggle.value as? String == "open" }
    }

    private func tapObservedFullScreenControl(_ app: XCUIApplication) -> Bool {
        let fullScreenNames = ["Enter Full Screen", "Full Screen", "Zoom", "Zoom Window"]
        if let control = visibleElement(named: fullScreenNames, in: [springboard, app], buttonsOnly: true) {
            tapAndRecord(control, reason: "observed-full-screen-control")
            return true
        }
        let menuNames = ["Window Controls", "Window controls", "Window Menu", "Window menu"]
        if let menu = visibleElement(named: menuNames, in: [springboard, app], buttonsOnly: true) {
            tapAndRecord(menu, reason: "open-observed-window-controls")
            attachState("system-window-controls-menu", app: app)
            if let control = visibleElement(named: fullScreenNames, in: [springboard, app], buttonsOnly: true) {
                tapAndRecord(control, reason: "observed-full-screen-menu-action")
                return true
            }
        }
        attachState("system-full-screen-control-unresolved", app: app)
        return false
    }

    private func restorationThreshold(for baseline: CGRect) -> CGFloat {
        max(compactBoundary, baseline.width - 48)
    }

    private func primaryWindow(in app: XCUIApplication) -> XCUIElement {
        // Identify the actual app scene by its real controls. An iPad's software
        // keyboard can be wider than a narrow scene, so choosing the largest
        // window could otherwise mistake that system overlay for the app.
        for identifier in ["sidebar-toggle", "settings-close"] {
            let window = app.windows.containing(.button, identifier: identifier).firstMatch
            if window.exists && window.frame.width > 0 && window.frame.height > 0 { return window }
        }
        return app.windows.firstMatch
    }

    private func visibleElement(named names: [String], in apps: [XCUIApplication], buttonsOnly: Bool = false) -> XCUIElement? {
        for app in apps {
            for name in names {
                let predicate = NSPredicate(format: "label == %@ OR identifier == %@", name, name)
                let queries: [XCUIElementQuery] = buttonsOnly
                    ? [app.buttons]
                    : [app.buttons, app.cells, app.staticTexts, app.otherElements]
                for query in queries {
                    if let element = query.matching(predicate).allElementsBoundByIndex.first(where: { $0.exists && $0.isHittable }) {
                        return element
                    }
                }
            }
        }
        return nil
    }

    @discardableResult
    private func waitFor(timeout: TimeInterval, condition: @escaping () -> Bool) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private func tapAndRecord(_ element: XCUIElement, reason: String) {
        attachText(elementDetails(element), name: reason)
        element.tap()
    }

    private func elementDetails(_ element: XCUIElement) -> String {
        "type=\(element.elementType.rawValue), label=\(element.label), identifier=\(element.identifier), frame=\(element.frame), hittable=\(element.isHittable)"
    }

    private func attachState(_ name: String, app: XCUIApplication) {
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = name + "-screen"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        attachText(app.debugDescription, name: name + "-app-hierarchy")
        attachText(springboard.debugDescription, name: name + "-springboard-hierarchy")
        let frames = app.windows.allElementsBoundByIndex.enumerated().map { index, window in
            "window[\(index)]: \(window.frame); identifier=\(window.identifier); label=\(window.label)"
        }.joined(separator: "\n")
        let toggle = app.buttons["sidebar-toggle"]
        let history = app.scrollViews["chat-history"]
        let layoutDetails = """
            sidebar-toggle: \(toggle.exists ? elementDetails(toggle) : "absent")
            sidebar-toggle value: \(toggle.exists ? String(describing: toggle.value) : "absent")
            chat-history: \(history.exists ? elementDetails(history) : "absent")
            """
        attachText("app frame: \(app.frame)\norientation: \(XCUIDevice.shared.orientation.rawValue)\n\(frames)\n\(layoutDetails)", name: name + "-geometry")
    }

    private func attachText(_ text: String, name: String) {
        let attachment = XCTAttachment(string: text)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
