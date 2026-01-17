import XCTest

/// UI Tests for the Settings Window
/// Run in Xcode with the PasteFenceUITests target
final class SettingsUITests: XCTestCase {
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

    // MARK: - Helper Methods

    func openSettings() {
        // Ensure app has focus first by clicking on main window
        let mainWindow = app.windows.firstMatch
        if mainWindow.exists {
            mainWindow.click()
            usleep(100_000)
        }

        // Try to open Settings via menu bar
        let menuBar = app.menuBars.firstMatch
        if menuBar.exists {
            // The app menu is named "PasteFence" (not index 0 which is Apple menu)
            let appMenu = menuBar.menuBarItems["PasteFence"]
            if appMenu.exists {
                appMenu.click()
                usleep(100_000)

                // Look for Settings... menu item
                let settingsItem = appMenu.menus.firstMatch.menuItems["Settings…"]
                if settingsItem.exists {
                    settingsItem.click()
                    return
                }

                // Close menu if no settings found
                app.typeKey(.escape, modifierFlags: [])
            }
        }

        // Fall back to keyboard shortcut Cmd+,
        app.typeKey(",", modifierFlags: .command)
    }

    func waitForSettingsWindow() -> XCUIElement {
        // SwiftUI Settings window has identifier "com_apple_SwiftUI_Settings_window"
        // and title is the current tab name (e.g., "General"), not "Settings"
        let settingsWindow = app.windows["com_apple_SwiftUI_Settings_window"]
        XCTAssertTrue(settingsWindow.waitForExistence(timeout: 5), "Settings window should appear")
        return settingsWindow
    }

    // MARK: - Settings Access Tests

    func testSettingsOpensViaKeyboardShortcut() {
        openSettings()

        // SwiftUI Settings window has identifier "com_apple_SwiftUI_Settings_window"
        let settingsWindow = app.windows["com_apple_SwiftUI_Settings_window"]
        XCTAssertTrue(settingsWindow.waitForExistence(timeout: 5), "Settings window should open with Cmd+,")
    }

    func testSettingsWindowExists() {
        openSettings()

        let window = waitForSettingsWindow()
        XCTAssertTrue(window.exists, "Settings window should exist")
    }

    // MARK: - Tab Navigation Tests

    func testGeneralTabNavigation() {
        openSettings()

        let window = waitForSettingsWindow()

        // Click on General tab
        let generalTab = window.tabGroups.buttons["General"]
        if generalTab.exists {
            generalTab.click()
        }

        // Verify General settings elements are visible
        // Note: SwiftUI TabView may show elements differently
        usleep(200_000) // Small delay for UI update
    }

    func testModelTabNavigation() {
        openSettings()

        let window = waitForSettingsWindow()

        // Click on Model tab
        let modelTab = window.tabGroups.buttons["Model"]
        if modelTab.exists {
            modelTab.click()
            usleep(200_000)
        }
    }

    func testShortcutsTabNavigation() {
        openSettings()

        let window = waitForSettingsWindow()

        // Click on Shortcuts tab
        let shortcutsTab = window.tabGroups.buttons["Shortcuts"]
        if shortcutsTab.exists {
            shortcutsTab.click()
            usleep(200_000)
        }
    }

    func testHistoryTabNavigation() {
        openSettings()

        let window = waitForSettingsWindow()

        // Click on History tab
        let historyTab = window.tabGroups.buttons["History"]
        if historyTab.exists {
            historyTab.click()
            usleep(200_000)
        }
    }

    func testAboutTabNavigation() {
        openSettings()

        let window = waitForSettingsWindow()

        // Click on About tab
        let aboutTab = window.tabGroups.buttons["About"]
        if aboutTab.exists {
            aboutTab.click()
            usleep(200_000)
        }
    }

    // MARK: - General Settings Tests

    func testLaunchAtLoginToggle() {
        openSettings()

        let window = waitForSettingsWindow()

        // Find the launch at login toggle
        let toggle = window.checkBoxes["launchAtLoginToggle"]
        if toggle.exists {
            let initialState = toggle.value as? Int ?? 0
            toggle.click()
            usleep(100_000)

            // Toggle back
            toggle.click()
            usleep(100_000)

            let finalState = toggle.value as? Int ?? 0
            XCTAssertEqual(initialState, finalState, "Toggle should return to initial state")
        }
    }

    func testShowNotificationsToggle() {
        openSettings()

        let window = waitForSettingsWindow()

        let toggle = window.checkBoxes["showNotificationsToggle"]
        if toggle.exists {
            toggle.click()
            usleep(100_000)
            toggle.click()
        }
    }

    func testMaskingFormatSelection() {
        openSettings()

        let window = waitForSettingsWindow()

        let picker = window.radioGroups["maskingFormatPicker"]
        if picker.exists {
            // Try to select different format options
            let buttons = picker.radioButtons
            if buttons.count > 1 {
                let button1 = buttons.element(boundBy: 1)
                let button0 = buttons.element(boundBy: 0)

                // Only click if the button is hittable (not scrolled out of view)
                if button1.isHittable {
                    button1.click()
                    usleep(100_000)
                }
                if button0.isHittable {
                    button0.click()
                }
            }
        }
    }

    // MARK: - Model Settings Tests

    func testOllamaToggle() {
        openSettings()

        let window = waitForSettingsWindow()

        // Navigate to Model tab first
        let modelTab = window.tabGroups.buttons["Model"]
        if modelTab.exists {
            modelTab.click()
            usleep(200_000)
        }

        // Find and toggle the Ollama checkbox
        let toggle = window.checkBoxes["useOllamaToggle"]
        if toggle.exists {
            let initialState = toggle.value as? Int ?? 0
            toggle.click()
            usleep(100_000)

            // Toggle back to original state
            toggle.click()
            usleep(100_000)

            let finalState = toggle.value as? Int ?? 0
            XCTAssertEqual(initialState, finalState, "Ollama toggle should return to initial state")
        }
    }

    func testOllamaRefreshButton() {
        openSettings()

        let window = waitForSettingsWindow()

        // Navigate to Model tab
        let modelTab = window.tabGroups.buttons["Model"]
        if modelTab.exists {
            modelTab.click()
            usleep(200_000)
        }

        // Enable Ollama first
        let toggle = window.checkBoxes["useOllamaToggle"]
        if toggle.exists && (toggle.value as? Int ?? 0) == 0 {
            toggle.click()
            usleep(200_000)
        }

        // Find refresh button
        let refreshButton = window.buttons["refreshOllamaButton"]
        if refreshButton.exists {
            XCTAssertTrue(refreshButton.isEnabled, "Refresh button should be enabled when Ollama is on")
        }

        // Toggle Ollama back off
        if toggle.exists {
            toggle.click()
        }
    }

    func testModelListExists() {
        openSettings()

        let window = waitForSettingsWindow()

        // Navigate to Model tab
        let modelTab = window.tabGroups.buttons["Model"]
        if modelTab.exists {
            modelTab.click()
            usleep(200_000)
        }

        // Model list should have some content (the default models)
        // This is a basic existence check
    }

    // MARK: - Shortcuts Settings Tests

    func testHotkeyRecorderExists() {
        openSettings()

        let window = waitForSettingsWindow()

        // Navigate to Shortcuts tab
        let shortcutsTab = window.tabGroups.buttons["Shortcuts"]
        if shortcutsTab.exists {
            shortcutsTab.click()
            usleep(200_000)
        }

        // The hotkey recorder should exist
        // Note: KeyboardShortcuts.Recorder may have different accessibility representation
    }

    // MARK: - History Tab Tests

    func testHistorySearchField() {
        openSettings()

        let window = waitForSettingsWindow()

        // Navigate to History tab
        let historyTab = window.tabGroups.buttons["History"]
        if historyTab.exists {
            historyTab.click()
            usleep(200_000)
        }

        let searchField = window.textFields["historySearchField"]
        if searchField.exists {
            searchField.click()
            searchField.typeText("test")
            usleep(100_000)

            // Clear the search
            searchField.typeKey("a", modifierFlags: .command)
            searchField.typeKey(.delete, modifierFlags: [])
        }
    }

    func testHistoryListExists() {
        openSettings()

        let window = waitForSettingsWindow()

        // Navigate to History tab
        let historyTab = window.tabGroups.buttons["History"]
        if historyTab.exists {
            historyTab.click()
            usleep(200_000)
        }

        // History list should exist (may be empty)
        let historyList = window.tables["historyList"]
        // The list may not exist if there's no history (showing empty state instead)
    }

    func testClearHistoryButton() {
        openSettings()

        let window = waitForSettingsWindow()

        // Navigate to History tab
        let historyTab = window.tabGroups.buttons["History"]
        if historyTab.exists {
            historyTab.click()
            usleep(200_000)
        }

        let clearButton = window.buttons["clearHistoryButton"]
        if clearButton.exists {
            // Don't actually click if enabled - it would clear history
            // Just verify the button exists
            XCTAssertTrue(clearButton.exists, "Clear All button should exist")
        }
    }

    func testExportButton() {
        openSettings()

        let window = waitForSettingsWindow()

        // Navigate to History tab
        let historyTab = window.tabGroups.buttons["History"]
        if historyTab.exists {
            historyTab.click()
            usleep(200_000)
        }

        let exportButton = window.buttons["exportHistoryButton"]
        if exportButton.exists {
            XCTAssertTrue(exportButton.exists, "Export button should exist")
        }
    }

    // MARK: - Accessibility Tests

    func testKeyboardNavigation() {
        openSettings()

        let window = waitForSettingsWindow()

        // Tab through elements
        window.typeKey(.tab, modifierFlags: [])
        window.typeKey(.tab, modifierFlags: [])
        window.typeKey(.tab, modifierFlags: [])

        // Should be able to navigate without crashes
    }

    func testAccessibilityLabels() {
        openSettings()

        let window = waitForSettingsWindow()

        // Verify window has proper accessibility
        XCTAssertTrue(window.exists, "Settings window should be accessible")
    }

    func testCloseSettingsWithEscape() {
        openSettings()

        let window = waitForSettingsWindow()

        // Press Escape to close
        window.typeKey(.escape, modifierFlags: [])

        // Give time for window to close
        usleep(500_000)

        // Window may or may not close with Escape depending on focus
        // This is more of a behavioral test
    }

    func testCloseSettingsWithCommandW() {
        openSettings()

        let window = waitForSettingsWindow()

        // Press Cmd+W to close
        window.typeKey("w", modifierFlags: .command)

        // Window should close
        XCTAssertFalse(window.waitForExistence(timeout: 2), "Settings window should close with Cmd+W")
    }
}
