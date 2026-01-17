import Foundation
import AppKit
import ApplicationServices

/// Helper for managing macOS Accessibility permissions
/// Required for simulating keyboard events (CGEvent.post)
struct AccessibilityHelper {
    /// Checks if the app has Accessibility permission
    /// Required for CGEvent.post(tap: .cghidEventTap) to work
    static var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    /// Prompts the user to grant Accessibility permission
    /// Opens System Settings → Privacy & Security → Accessibility with the app highlighted
    @discardableResult
    static func requestPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Opens System Settings to the Accessibility pane directly
    static func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
