import SwiftUI
import AppKit
import os
import SettingsAccess

private let logger = Logger(subsystem: "com.pastefence", category: "AppDelegate")

// MARK: - Menu Bar Content View
/// Separate view to access @Environment(\.openSettings)
/// SettingsLink doesn't work in MenuBarExtra due to .accessory activation policy
struct MenuBarContentView: View {
    var body: some View {
        Text("PasteFence")
            .font(.headline)

        Divider()

        Text("Ready")
            .foregroundColor(.secondary)

        Divider()

        Button("Mask & Paste") {
            AppCoordinator.shared?.triggerMaskPaste()
        }
        .keyboardShortcut("V", modifiers: [.command, .shift])

        Divider()

        SettingsLink {
            Text("Settings...")
        } preAction: {
            // Activate app before opening settings (required for menu bar apps)
            NSApp.activate(ignoringOtherApps: true)
        } postAction: {
            // Bring Settings window to front
            DispatchQueue.main.async {
                if let settingsWindow = NSApp.windows.first(where: {
                    $0.identifier?.rawValue == "com_apple_SwiftUI_Settings_window"
                }) {
                    settingsWindow.level = .floating
                    settingsWindow.makeKeyAndOrderFront(nil)
                    // Reset to normal level after bringing to front
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        settingsWindow.level = .normal
                    }
                }
            }
        }
        .keyboardShortcut(",", modifiers: .command)

        Divider()

        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}

// MARK: - App Entry Point

@main
struct PasteFenceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Menu bar item using SwiftUI MenuBarExtra
        MenuBarExtra("PasteFence", systemImage: "shield.lefthalf.filled") {
            MenuBarContentView()
        }

        Settings {
            SettingsView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var appCoordinator: AppCoordinator?

    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("App launched")
        checkAccessibilityOnFirstLaunch()
        setupAppCoordinator()
    }

    /// Prompts for Accessibility permission on first launch
    /// Only prompts once (stored in UserDefaults)
    private func checkAccessibilityOnFirstLaunch() {
        let hasPromptedKey = "hasPromptedForAccessibility"
        guard !UserDefaults.standard.bool(forKey: hasPromptedKey) else {
            logger.info("Already prompted for Accessibility permission")
            return
        }

        UserDefaults.standard.set(true, forKey: hasPromptedKey)

        if !AccessibilityHelper.hasAccessibilityPermission {
            logger.info("Requesting Accessibility permission on first launch")
            AccessibilityHelper.requestPermission()
        } else {
            logger.info("Accessibility permission already granted")
        }
    }

    private func setupAppCoordinator() {
        Task { @MainActor in
            let coordinator = AppCoordinator()
            AppCoordinator.shared = coordinator
            appCoordinator = coordinator
            coordinator.start()

            // UI Testing: Auto-show preview window with sample data
            if AppCoordinator.isUITesting {
                logger.info("UI Testing mode enabled - showing test preview window")
                // Small delay to ensure app is fully launched
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    coordinator.showTestPreviewWindow()
                }
            }
        }
    }
}
