import XCTest
@testable import PasteFence

// MARK: - Response Parsing Edge Case Tests

final class LLMDetectorResponseParsingTests: XCTestCase {

    func testResponseWithBareArray() {
        // When LLM returns just an array without the wrapper object
        let bareArray = "[{\"text\": \"test@email.com\", \"type\": \"EMAIL\", \"confidence\": 0.9}]"

        // findMatchingBracket should handle this
        let result = LLMDetectorTestHelper.findMatchingBracket(in: bareArray)
        XCTAssertNotNil(result)

        // Wrap it properly
        let wrapped = "{\"detected\": \(bareArray)}"
        let data = wrapped.data(using: .utf8)!
        let decoded = try? JSONDecoder().decode(LLMResponseTestable.self, from: data)

        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.detected.count, 1)
        XCTAssertEqual(decoded?.detected.first?.text, "test@email.com")
    }

    func testResponseWithCompleteJSON() {
        // When LLM returns complete JSON object
        let complete = "{\"detected\": [{\"text\": \"test\", \"type\": \"EMAIL\", \"confidence\": 0.95}]}"

        // extractFirstJSONObject should handle this
        let extracted = LLMDetectorTestHelper.extractFirstJSONObject(from: complete)
        XCTAssertEqual(extracted, complete)
    }

    func testResponseContinuationFromPrefix() {
        // When LLM continues from pre-filled prefix {"detected": [
        let continuation = "{\"text\": \"test@email.com\", \"type\": \"EMAIL\", \"confidence\": 0.9}]}"
        let prefix = "{\"detected\": ["
        let full = prefix + continuation

        let data = full.data(using: .utf8)!
        let decoded = try? JSONDecoder().decode(LLMResponseTestable.self, from: data)

        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.detected.count, 1)
    }

    func testResponseWithMultipleItems() {
        let json = """
        {"detected": [
            {"text": "admin@test.org", "type": "EMAIL", "confidence": 0.95},
            {"text": "sk-abc123xyz", "type": "API_KEY", "confidence": 0.9},
            {"text": "192.168.1.1", "type": "IP_ADDRESS", "confidence": 0.85}
        ]}
        """

        let data = json.data(using: .utf8)!
        let decoded = try? JSONDecoder().decode(LLMResponseTestable.self, from: data)

        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.detected.count, 3)
        XCTAssertEqual(decoded?.detected[0].type, "EMAIL")
        XCTAssertEqual(decoded?.detected[1].type, "API_KEY")
        XCTAssertEqual(decoded?.detected[2].type, "IP_ADDRESS")
    }

    func testResponseWithSpecialCharactersInText() {
        let json = """
        {"detected": [{"text": "password=s3cr3t!@#$%", "type": "PASSWORD", "confidence": 0.9}]}
        """

        let data = json.data(using: .utf8)!
        let decoded = try? JSONDecoder().decode(LLMResponseTestable.self, from: data)

        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.detected.first?.text, "password=s3cr3t!@#$%")
    }

    func testResponseWithUnicodeCharacters() {
        let json = """
        {"detected": [{"text": "사용자@example.com", "type": "EMAIL", "confidence": 0.9}]}
        """

        let data = json.data(using: .utf8)!
        let decoded = try? JSONDecoder().decode(LLMResponseTestable.self, from: data)

        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.detected.first?.text, "사용자@example.com")
    }

    func testResponseWithNewlinesInText() {
        let json = """
        {"detected": [{"text": "-----BEGIN RSA PRIVATE KEY-----", "type": "PRIVATE_KEY", "confidence": 0.99}]}
        """

        let data = json.data(using: .utf8)!
        let decoded = try? JSONDecoder().decode(LLMResponseTestable.self, from: data)

        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.detected.first?.type, "PRIVATE_KEY")
    }

    func testResponseWithZeroConfidence() {
        let json = """
        {"detected": [{"text": "maybe@email.com", "type": "EMAIL", "confidence": 0.0}]}
        """

        let data = json.data(using: .utf8)!
        let decoded = try? JSONDecoder().decode(LLMResponseTestable.self, from: data)

        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.detected.first?.confidence, 0.0)
    }

    func testResponseWithHighConfidence() {
        let json = """
        {"detected": [{"text": "definite@email.com", "type": "EMAIL", "confidence": 1.0}]}
        """

        let data = json.data(using: .utf8)!
        let decoded = try? JSONDecoder().decode(LLMResponseTestable.self, from: data)

        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.detected.first?.confidence, 1.0)
    }
}
