import AppKit
import Foundation

/// Service for reading and writing to the system clipboard
final class ClipboardService {
    private let pasteboard: NSPasteboard

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    /// Get the current text content from clipboard
    func getText() -> String? {
        return pasteboard.string(forType: .string)
    }

    /// Set text content to clipboard
    func setText(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    /// Check if clipboard has text content
    func hasText() -> Bool {
        return pasteboard.availableType(from: [.string]) != nil
    }

    /// Get the change count (useful for monitoring clipboard changes)
    var changeCount: Int {
        return pasteboard.changeCount
    }
}
