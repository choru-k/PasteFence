import XCTest
@testable import PasteFence

// MARK: - Truncation Detection Tests

final class LLMDetectorTruncationTests: XCTestCase {

    // MARK: - Valid (Non-Truncated) Responses

    func testValidResponseNotTruncated() {
        let valid = """
        {"detected":[{"text":"email@test.com","type":"EMAIL"}]}
        """
        XCTAssertFalse(LLMDetectorTestHelper.isTruncated(valid))
    }

    func testEmptyArrayValid() {
        let empty = """
        {"detected":[]}
        """
        XCTAssertFalse(LLMDetectorTestHelper.isTruncated(empty))
    }

    func testMultipleItemsValid() {
        let multiple = """
        {"detected":[{"text":"email@test.com","type":"EMAIL"},{"text":"555-1234","type":"PHONE"}]}
        """
        XCTAssertFalse(LLMDetectorTestHelper.isTruncated(multiple))
    }

    func testEmptyResponseValid() {
        // Empty response means nothing found, not truncated
        let empty = ""
        XCTAssertFalse(LLMDetectorTestHelper.isTruncated(empty))
    }

    func testWhitespaceOnlyValid() {
        let whitespace = "   \n\t  "
        XCTAssertFalse(LLMDetectorTestHelper.isTruncated(whitespace))
    }

    func testNestedObjectsValid() {
        let nested = """
        {"detected":[{"text":"{nested}","type":"SECRET"}]}
        """
        XCTAssertFalse(LLMDetectorTestHelper.isTruncated(nested))
    }

    // MARK: - Truncated Responses (Missing Closing Brackets)

    func testTruncatedMidItem() {
        // Cut off in middle of an item
        let truncated = """
        {"detected":[{"text":"email@test.com","type":"EMAIL"},{"text":"555-
        """
        XCTAssertTrue(LLMDetectorTestHelper.isTruncated(truncated))
    }

    func testTruncatedMidArray() {
        // Array not closed
        let truncated = """
        {"detected":[{"text":"test"}
        """
        XCTAssertTrue(LLMDetectorTestHelper.isTruncated(truncated))
    }

    func testTruncatedMidObject() {
        // Object not closed
        let truncated = """
        {"detected":[{"text":"test","type"
        """
        XCTAssertTrue(LLMDetectorTestHelper.isTruncated(truncated))
    }

    func testUnbalancedBrackets() {
        // More [ than ]
        let unbalanced = """
        {"detected":[{"text":"[test"
        """
        XCTAssertTrue(LLMDetectorTestHelper.isTruncated(unbalanced))
    }

    func testUnbalancedBraces() {
        // More { than }
        let unbalanced = """
        {"detected":[{"text":"test"
        """
        XCTAssertTrue(LLMDetectorTestHelper.isTruncated(unbalanced))
    }

    func testEndsWithComma() {
        // Ends with comma (expecting more items)
        let endsComma = """
        {"detected":[{"text":"test","type":"EMAIL"},
        """
        XCTAssertTrue(LLMDetectorTestHelper.isTruncated(endsComma))
    }

    func testEndsWithColon() {
        // Ends with colon (expecting value)
        let endsColon = """
        {"detected":[{"text":"test","type":
        """
        XCTAssertTrue(LLMDetectorTestHelper.isTruncated(endsColon))
    }

    // MARK: - Edge Cases

    func testBraceOnlyClosedValid() {
        // Just closing brace (empty object at top level)
        let justBrace = "{}"
        XCTAssertFalse(LLMDetectorTestHelper.isTruncated(justBrace))
    }

    func testWithTrailingWhitespace() {
        let withWhitespace = """
        {"detected":[]}

        """
        XCTAssertFalse(LLMDetectorTestHelper.isTruncated(withWhitespace))
    }

    func testWithLeadingWhitespace() {
        let withWhitespace = """

        {"detected":[]}
        """
        XCTAssertFalse(LLMDetectorTestHelper.isTruncated(withWhitespace))
    }
}
