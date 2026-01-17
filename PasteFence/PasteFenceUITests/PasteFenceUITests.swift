import XCTest

/// UI Tests for the Preview Window
/// The app auto-shows a test preview window when --ui-testing flag is present
final class PreviewWindowUITests: XCTestCase {
    var app: XCUIApplication!

    // MARK: - Setup/Teardown

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
    }

    override func tearDown() {
        app.terminate()
        super.tearDown()
    }

    // MARK: - Window Tests

    func testPreviewWindowAppears() {
        // Window should appear automatically with --ui-testing flag
        let previewWindow = app.windows["previewWindow"]
        XCTAssertTrue(previewWindow.waitForExistence(timeout: 5), "Preview window should appear")
    }

    func testPreviewWindowElements() {
        let window = app.windows["previewWindow"]
        XCTAssertTrue(window.waitForExistence(timeout: 5))

        // Check for key UI elements
        // SwiftUI Picker(.segmented) may be exposed as radioGroup or buttons
        let hasTabs = window.radioGroups.firstMatch.exists ||
                      window.buttons["Masked"].exists ||
                      window.segmentedControls.firstMatch.exists
        XCTAssertTrue(hasTabs, "Tab picker should exist (as radioGroup, buttons, or segmentedControl)")

        XCTAssertTrue(window.buttons["pasteMaskedButton"].exists, "Paste Masked button should exist")
        XCTAssertTrue(window.buttons["cancelButton"].exists, "Cancel button should exist")
        XCTAssertTrue(window.buttons["selectAllButton"].exists, "Select All button should exist")
        XCTAssertTrue(window.buttons["deselectAllButton"].exists, "Deselect All button should exist")
    }

    // MARK: - Tab Tests

    func testTabSwitching() {
        let window = app.windows["previewWindow"]
        XCTAssertTrue(window.waitForExistence(timeout: 5))

        // SwiftUI Picker(.segmented) may be exposed differently
        // Try finding tab buttons directly by their titles
        let maskedTab = window.buttons["Masked"]
        let originalTab = window.buttons["Original"]
        let diffTab = window.buttons["Diff"]

        // Also check in radioGroups
        let radioGroup = window.radioGroups.firstMatch

        // Click Original tab
        if originalTab.exists {
            originalTab.click()
            usleep(100_000)
        } else if radioGroup.exists {
            radioGroup.radioButtons["Original"].click()
            usleep(100_000)
        }

        // Click Diff tab
        if diffTab.exists {
            diffTab.click()
            usleep(100_000)
        } else if radioGroup.exists {
            radioGroup.radioButtons["Diff"].click()
            usleep(100_000)
        }

        // Click back to Masked tab
        if maskedTab.exists {
            maskedTab.click()
        } else if radioGroup.exists {
            radioGroup.radioButtons["Masked"].click()
        }
    }

    // MARK: - Detected Items Tests

    func testDetectedItemsDisplayed() {
        let window = app.windows["previewWindow"]
        XCTAssertTrue(window.waitForExistence(timeout: 5))

        // SwiftUI List may be exposed as outline, table, or scrollView
        // Check for checkboxes directly which indicate detected items
        let checkboxes = window.checkBoxes
        XCTAssertGreaterThanOrEqual(checkboxes.count, 1, "Should have detected items with checkboxes")
    }

    func testItemToggle() {
        let window = app.windows["previewWindow"]
        XCTAssertTrue(window.waitForExistence(timeout: 5))

        // Find first checkbox directly in the window (SwiftUI List doesn't map to tables)
        let firstCheckbox = window.checkBoxes.firstMatch
        guard firstCheckbox.waitForExistence(timeout: 2) else {
            XCTFail("No checkbox found in window")
            return
        }

        // Toggle off
        firstCheckbox.click()

        // Small delay for UI update
        usleep(100_000)

        // Toggle back
        firstCheckbox.click()
    }

    func testBulkSelectDeselect() {
        let window = app.windows["previewWindow"]
        XCTAssertTrue(window.waitForExistence(timeout: 5))

        let deselectAllButton = window.buttons["deselectAllButton"]
        let selectAllButton = window.buttons["selectAllButton"]

        XCTAssertTrue(deselectAllButton.exists)
        XCTAssertTrue(selectAllButton.exists)

        // Click Deselect All
        if deselectAllButton.isEnabled {
            deselectAllButton.click()
        }

        // Small delay
        usleep(100_000)

        // Click Select All
        if selectAllButton.isEnabled {
            selectAllButton.click()
        }
    }

    // MARK: - Action Tests

    func testPasteMaskedButton() {
        let window = app.windows["previewWindow"]
        XCTAssertTrue(window.waitForExistence(timeout: 5))

        let pasteButton = window.buttons["pasteMaskedButton"]
        XCTAssertTrue(pasteButton.exists)
        XCTAssertTrue(pasteButton.isEnabled)

        pasteButton.click()

        // Window should close after clicking Paste
        XCTAssertFalse(window.waitForExistence(timeout: 2), "Window should close after Paste")
    }

    func testCancelButton() {
        let window = app.windows["previewWindow"]
        XCTAssertTrue(window.waitForExistence(timeout: 5))

        let cancelButton = window.buttons["cancelButton"]
        XCTAssertTrue(cancelButton.exists)

        cancelButton.click()

        // Window should close after clicking Cancel
        XCTAssertFalse(window.waitForExistence(timeout: 2), "Window should close after Cancel")
    }

    func testEscapeKeyCloses() {
        let window = app.windows["previewWindow"]
        XCTAssertTrue(window.waitForExistence(timeout: 5))

        // Press Escape key
        window.typeKey(.escape, modifierFlags: [])

        // Window should close
        XCTAssertFalse(window.waitForExistence(timeout: 2), "Window should close after Escape")
    }

    // MARK: - Accessibility Tests

    func testAccessibilityLabels() {
        let window = app.windows["previewWindow"]
        XCTAssertTrue(window.waitForExistence(timeout: 5))

        // All buttons should have non-empty labels
        let pasteButton = window.buttons["pasteMaskedButton"]
        let cancelButton = window.buttons["cancelButton"]

        XCTAssertTrue(pasteButton.exists)
        XCTAssertTrue(cancelButton.exists)

        // Buttons should have labels (the title text)
        XCTAssertFalse(pasteButton.label.isEmpty, "Paste button should have a label")
        XCTAssertFalse(cancelButton.label.isEmpty, "Cancel button should have a label")
    }

    func testKeyboardNavigation() {
        let window = app.windows["previewWindow"]
        XCTAssertTrue(window.waitForExistence(timeout: 5))

        // Tab through elements using keyboard
        window.typeKey(.tab, modifierFlags: [])
        window.typeKey(.tab, modifierFlags: [])
        window.typeKey(.tab, modifierFlags: [])

        // Should be able to navigate without crashes
        // Note: Full keyboard navigation testing requires checking focus states
    }
}
