import XCTest
import AppKit
@testable import PasteFence

/// Integration tests for ClipboardService
/// Tests clipboard read/write operations, edge cases, and concurrent access
/// Note: Tests must run in Xcode (requires system clipboard access)
final class ClipboardIntegrationTests: XCTestCase {
    var clipboardService: ClipboardService!
    var originalClipboardContent: String?

    // MARK: - Setup/Teardown

    override func setUp() {
        super.setUp()
        clipboardService = ClipboardService()
        // Save original clipboard to restore after test
        originalClipboardContent = NSPasteboard.general.string(forType: .string)
    }

    override func tearDown() {
        // Restore original clipboard content
        if let original = originalClipboardContent {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(original, forType: .string)
        }
        super.tearDown()
    }

    // MARK: - Basic Read/Write Tests

    func testWriteAndReadClipboard() {
        let testContent = "Test content \(UUID().uuidString)"

        clipboardService.setText(testContent)
        let retrieved = clipboardService.getText()

        XCTAssertEqual(retrieved, testContent)
    }

    func testEmptyClipboard() {
        NSPasteboard.general.clearContents()

        let content = clipboardService.getText()
        XCTAssertNil(content)
        XCTAssertFalse(clipboardService.hasText())
    }

    func testHasTextAfterSet() {
        clipboardService.setText("test")
        XCTAssertTrue(clipboardService.hasText())
    }

    // MARK: - Unicode Content Tests

    func testUnicodeContent() {
        let unicodeContent = "Hello 世界 🌍 مرحبا 한국어"

        clipboardService.setText(unicodeContent)
        let retrieved = clipboardService.getText()

        XCTAssertEqual(retrieved, unicodeContent)
    }

    func testEmojiOnlyContent() {
        let emojiContent = "🔐🛡️⚠️✅❌"

        clipboardService.setText(emojiContent)
        let retrieved = clipboardService.getText()

        XCTAssertEqual(retrieved, emojiContent)
    }

    // MARK: - Large Content Tests

    func testLargeContent() {
        let largeContent = String(repeating: "A", count: 100_000)

        clipboardService.setText(largeContent)
        let retrieved = clipboardService.getText()

        XCTAssertEqual(retrieved, largeContent)
    }

    func testMultilineContent() {
        let multilineContent = """
        Line 1
        Line 2 with special chars: <>&'"
        Line 3
        """

        clipboardService.setText(multilineContent)
        let retrieved = clipboardService.getText()

        XCTAssertEqual(retrieved, multilineContent)
    }

    // MARK: - Change Count Tests

    func testChangeCountIncrementsOnSet() {
        let initialCount = clipboardService.changeCount
        clipboardService.setText("new content")

        XCTAssertGreaterThan(clipboardService.changeCount, initialCount)
    }

    func testChangeCountStableOnRead() {
        clipboardService.setText("content")
        let countAfterSet = clipboardService.changeCount

        _ = clipboardService.getText()
        _ = clipboardService.getText()

        XCTAssertEqual(clipboardService.changeCount, countAfterSet)
    }

    // MARK: - Sequential Access Tests
    // Note: NSPasteboard is not thread-safe, so clipboard operations
    // should run on main thread (as they do in the actual app)

    @MainActor
    func testSequentialWrites() async {
        // Multiple sequential writes should work correctly
        for i in 0..<10 {
            clipboardService.setText("Content \(i)")
        }

        // Should have the last content
        let retrieved = clipboardService.getText()
        XCTAssertEqual(retrieved, "Content 9")
    }

    @MainActor
    func testSequentialReadWrite() async {
        // Interleaved read/write operations
        for i in 0..<5 {
            clipboardService.setText("Value \(i)")
            let retrieved = clipboardService.getText()
            XCTAssertEqual(retrieved, "Value \(i)")
        }
    }

    // MARK: - Special Characters Tests

    func testSpecialCharacters() {
        let specialChars = "Tab:\t Newline:\n Carriage:\r Quote:\" Backslash:\\"

        clipboardService.setText(specialChars)
        let retrieved = clipboardService.getText()

        XCTAssertEqual(retrieved, specialChars)
    }

    func testNullCharacterHandling() {
        // String with embedded null - may or may not be preserved
        let withNull = "before\0after"

        clipboardService.setText(withNull)
        let retrieved = clipboardService.getText()

        XCTAssertNotNil(retrieved)
    }
}
