import Foundation
import AppKit
import KeyboardShortcuts
import Carbon.HIToolbox

extension KeyboardShortcuts.Name {
    static let maskPaste = Self("maskPaste", default: .init(.v, modifiers: [.command, .shift]))
}

/// Service for registering and handling global keyboard shortcuts
final class HotkeyService {
    /// Callback when mask-paste hotkey is triggered
    var onMaskPasteTriggered: (() -> Void)?

    func register() {
        KeyboardShortcuts.onKeyUp(for: .maskPaste) { [weak self] in
            self?.onMaskPasteTriggered?()
        }

        print("[HotkeyService] Registered Cmd+Shift+V for mask-paste")
    }

    func unregister() {
        KeyboardShortcuts.disable(.maskPaste)
    }

    /// Update the shortcut key combination
    func updateShortcut(_ shortcut: KeyboardShortcuts.Shortcut?) {
        KeyboardShortcuts.setShortcut(shortcut, for: .maskPaste)
    }

    /// Get current shortcut
    var currentShortcut: KeyboardShortcuts.Shortcut? {
        KeyboardShortcuts.getShortcut(for: .maskPaste)
    }
}
