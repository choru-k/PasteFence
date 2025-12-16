import XCTest
@testable import PasteFence

// MARK: - Think Block Stripping Tests

final class LLMDetectorThinkBlockTests: XCTestCase {

    func testStripThinkBlockProperTags() {
        let input = "<think>Some reasoning here...</think>{\"detected\": []}"
        let result = LLMDetectorTestHelper.stripThinkBlock(from: input)
        XCTAssertEqual(result, "{\"detected\": []}")
    }

    func testStripThinkBlockWithNewlines() {
        let input = """
        <think>
        Let me analyze this text...
        I see an email address.
        </think>
        {"detected": [{"text": "test@example.com", "type": "EMAIL", "confidence": 0.9}]}
        """
        let result = LLMDetectorTestHelper.stripThinkBlock(from: input)
        XCTAssertTrue(result.hasPrefix("{\"detected\":"))
    }

    func testStripThinkBlockNoThinkBlock() {
        let input = "{\"detected\": []}"
        let result = LLMDetectorTestHelper.stripThinkBlock(from: input)
        XCTAssertEqual(result, "{\"detected\": []}")
    }

    func testStripThinkBlockWithEndOfText() {
        let input = "<think>Reasoning...<|endoftext|>{\"detected\": []}"
        let result = LLMDetectorTestHelper.stripThinkBlock(from: input)
        XCTAssertEqual(result, "{\"detected\": []}")
    }

    func testStripThinkBlockEmptyInput() {
        let input = ""
        let result = LLMDetectorTestHelper.stripThinkBlock(from: input)
        XCTAssertEqual(result, "")
    }
}

// MARK: - Code Block Extraction Tests

final class LLMDetectorCodeBlockTests: XCTestCase {

    func testExtractFromCodeBlockWithJsonTag() {
        let input = """
        Some text before
        ```json
        {"detected": [{"text": "test", "type": "EMAIL", "confidence": 0.9}]}
        ```
        Some text after
        """
        let result = LLMDetectorTestHelper.extractFromCodeBlock(input)
        XCTAssertNotNil(result)
        XCTAssertTrue(result!.contains("\"detected\""))
    }

    func testExtractFromCodeBlockWithoutTag() {
        let input = """
        ```
        {"detected": []}
        ```
        """
        let result = LLMDetectorTestHelper.extractFromCodeBlock(input)
        XCTAssertNotNil(result)
        XCTAssertTrue(result!.contains("detected"))
    }

    func testExtractFromCodeBlockNoBlock() {
        let input = "{\"detected\": []}"
        let result = LLMDetectorTestHelper.extractFromCodeBlock(input)
        XCTAssertNil(result)
    }

    func testExtractFromCodeBlockMalformed() {
        let input = "```json\nno closing"
        let result = LLMDetectorTestHelper.extractFromCodeBlock(input)
        XCTAssertNil(result)
    }
}

// MARK: - Type Case Normalization Tests

final class LLMDetectorTypeCaseTests: XCTestCase {

    func testNormalizeTypeCaseCamelCase() {
        XCTAssertEqual(LLMDetectorTestHelper.normalizeTypeCase("privateKey"), "PRIVATE_KEY")
        XCTAssertEqual(LLMDetectorTestHelper.normalizeTypeCase("ipAddress"), "IP_ADDRESS")
        XCTAssertEqual(LLMDetectorTestHelper.normalizeTypeCase("apiKey"), "API_KEY")
    }

    func testNormalizeTypeCaseAlreadyUppercase() {
        XCTAssertEqual(LLMDetectorTestHelper.normalizeTypeCase("EMAIL"), "EMAIL")
        XCTAssertEqual(LLMDetectorTestHelper.normalizeTypeCase("PHONE"), "PHONE")
        XCTAssertEqual(LLMDetectorTestHelper.normalizeTypeCase("API_KEY"), "API_KEY")
    }

    func testNormalizeTypeCaseWithNumbers() {
        XCTAssertEqual(LLMDetectorTestHelper.normalizeTypeCase("oauth2Token"), "OAUTH2_TOKEN")
        XCTAssertEqual(LLMDetectorTestHelper.normalizeTypeCase("ip4Address"), "IP4_ADDRESS")
    }

    func testNormalizeTypeCaseMixedCase() {
        XCTAssertEqual(LLMDetectorTestHelper.normalizeTypeCase("AwsKey"), "AWS_KEY")
        XCTAssertEqual(LLMDetectorTestHelper.normalizeTypeCase("SSHPrivateKey"), "SSHPRIVATE_KEY")
    }

    func testNormalizeTypeCaseSingleWord() {
        XCTAssertEqual(LLMDetectorTestHelper.normalizeTypeCase("email"), "EMAIL")
        XCTAssertEqual(LLMDetectorTestHelper.normalizeTypeCase("secret"), "SECRET")
        XCTAssertEqual(LLMDetectorTestHelper.normalizeTypeCase("password"), "PASSWORD")
    }
}

// MARK: - Bracket Matching Tests

final class LLMDetectorBracketMatchingTests: XCTestCase {

    func testFindMatchingBracketSimple() {
        let input = "[1, 2, 3]"
        let result = LLMDetectorTestHelper.findMatchingBracket(in: input)
        XCTAssertNotNil(result)
        XCTAssertEqual(input[result!], "]")
        XCTAssertEqual(String(input[input.startIndex...result!]), "[1, 2, 3]")
    }

    func testFindMatchingBracketNested() {
        let input = "[[1, 2], [3, 4]]"
        let result = LLMDetectorTestHelper.findMatchingBracket(in: input)
        XCTAssertNotNil(result)
        XCTAssertEqual(String(input[input.startIndex...result!]), "[[1, 2], [3, 4]]")
    }

    func testFindMatchingBracketWithStrings() {
        let input = "[\"text[with]brackets\", \"more\"]"
        let result = LLMDetectorTestHelper.findMatchingBracket(in: input)
        XCTAssertNotNil(result)
        XCTAssertEqual(String(input[input.startIndex...result!]), input)
    }

    func testFindMatchingBracketWithEscapedQuotes() {
        let input = "[\"text with \\\"escaped\\\" quotes\"]"
        let result = LLMDetectorTestHelper.findMatchingBracket(in: input)
        XCTAssertNotNil(result)
        XCTAssertEqual(String(input[input.startIndex...result!]), input)
    }

    func testFindMatchingBracketUnbalanced() {
        let input = "[1, 2, 3"
        let result = LLMDetectorTestHelper.findMatchingBracket(in: input)
        XCTAssertNil(result)
    }

    func testFindMatchingBracketEmpty() {
        let input = "[]"
        let result = LLMDetectorTestHelper.findMatchingBracket(in: input)
        XCTAssertNotNil(result)
        XCTAssertEqual(String(input[input.startIndex...result!]), "[]")
    }

    func testFindMatchingBracketNotStartingWithBracket() {
        let input = "not an array"
        let result = LLMDetectorTestHelper.findMatchingBracket(in: input)
        XCTAssertNil(result)
    }
}

// MARK: - JSON Object Extraction Tests

final class LLMDetectorJSONExtractionTests: XCTestCase {

    func testExtractFirstJSONObjectClean() {
        let input = "{\"detected\": []}"
        let result = LLMDetectorTestHelper.extractFirstJSONObject(from: input)
        XCTAssertEqual(result, input)
    }

    func testExtractFirstJSONObjectWithPreamble() {
        let input = "Here is the result: {\"detected\": []} Done."
        let result = LLMDetectorTestHelper.extractFirstJSONObject(from: input)
        XCTAssertEqual(result, "{\"detected\": []}")
    }

    func testExtractFirstJSONObjectNested() {
        let input = "{\"outer\": {\"inner\": {\"deep\": true}}}"
        let result = LLMDetectorTestHelper.extractFirstJSONObject(from: input)
        XCTAssertEqual(result, input)
    }

    func testExtractFirstJSONObjectWithBracesInStrings() {
        let input = "{\"text\": \"value with { braces } inside\"}"
        let result = LLMDetectorTestHelper.extractFirstJSONObject(from: input)
        XCTAssertEqual(result, input)
    }

    func testExtractFirstJSONObjectWithEscapedChars() {
        let input = "{\"text\": \"escaped \\\" quote and \\\\ backslash\"}"
        let result = LLMDetectorTestHelper.extractFirstJSONObject(from: input)
        XCTAssertEqual(result, input)
    }

    func testExtractFirstJSONObjectNoObject() {
        let input = "No JSON here, just text"
        let result = LLMDetectorTestHelper.extractFirstJSONObject(from: input)
        XCTAssertNil(result)
    }

    func testExtractFirstJSONObjectUnclosed() {
        let input = "{\"detected\": ["
        let result = LLMDetectorTestHelper.extractFirstJSONObject(from: input)
        XCTAssertNil(result)
    }
}
