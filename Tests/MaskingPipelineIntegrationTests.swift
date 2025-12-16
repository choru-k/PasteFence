import XCTest
@testable import PasteFence

/// Integration tests for the complete masking pipeline
/// Tests end-to-end flow: text input → detection → masking → output
@MainActor
final class MaskingPipelineIntegrationTests: XCTestCase {
    var maskingEngine: MaskingEngine!

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()
        maskingEngine = MaskingEngine()
    }

    // MARK: - Single Type Detection Tests

    func testEmailMasking() async throws {
        let result = try await maskingEngine.mask(text: "Email: test@domain.com")

        XCTAssertFalse(result.maskedText.contains("test@domain.com"))
        XCTAssertTrue(result.maskedText.contains("[EMAIL_MASKED]"))
        XCTAssertEqual(result.detectedItems.count, 1)
        XCTAssertEqual(result.detectedItems.first?.type, .email)
    }

    func testPhoneMasking() async throws {
        let result = try await maskingEngine.mask(text: "Phone: (555) 123-4567")

        XCTAssertFalse(result.maskedText.contains("555"))
        XCTAssertTrue(result.maskedText.contains("[PHONE_MASKED]"))
        XCTAssertEqual(result.detectedItems.first?.type, .phone)
    }

    func testCreditCardMasking() async throws {
        let result = try await maskingEngine.mask(text: "Card: 4111111111111111")

        XCTAssertFalse(result.maskedText.contains("4111"))
        XCTAssertTrue(result.maskedText.contains("[CREDIT_CARD_MASKED]"))
        XCTAssertEqual(result.detectedItems.first?.type, .creditCard)
    }

    func testSSNMasking() async throws {
        let result = try await maskingEngine.mask(text: "SSN: 123-45-6789")

        XCTAssertFalse(result.maskedText.contains("123-45-6789"))
        XCTAssertTrue(result.maskedText.contains("[SSN_MASKED]"))
        XCTAssertEqual(result.detectedItems.first?.type, .ssn)
    }

    func testIPAddressMasking() async throws {
        // Use non-localhost IP that won't be skipped
        let result = try await maskingEngine.mask(text: "Server: 192.168.1.100")

        XCTAssertFalse(result.maskedText.contains("192.168.1.100"))
        XCTAssertTrue(result.maskedText.contains("[IP_ADDRESS_MASKED]"))
        XCTAssertEqual(result.detectedItems.first?.type, .ipAddress)
    }

    func testAPIKeyMasking() async throws {
        // OpenAI API key format (sk- prefix + 48 chars)
        let apiKey = "sk-" + String(repeating: "a", count: 48)
        let result = try await maskingEngine.mask(text: "OPENAI_KEY=\(apiKey)")

        XCTAssertFalse(result.maskedText.contains(apiKey))
        XCTAssertTrue(result.maskedText.contains("[API_KEY_MASKED]"))
        XCTAssertEqual(result.detectedItems.first?.type, .apiKey)
    }

    func testPasswordMasking() async throws {
        let result = try await maskingEngine.mask(text: "password: secret123")

        XCTAssertFalse(result.maskedText.contains("secret123"))
        XCTAssertTrue(result.maskedText.contains("[PASSWORD_MASKED]"))
        XCTAssertEqual(result.detectedItems.first?.type, .password)
    }

    func testPrivateKeyMasking() async throws {
        let result = try await maskingEngine.mask(text: "-----BEGIN RSA PRIVATE KEY-----\nMIIE...")

        XCTAssertTrue(result.maskedText.contains("[PRIVATE_KEY_MASKED]"))
        XCTAssertEqual(result.detectedItems.first?.type, .privateKey)
    }

    // MARK: - Multiple PII Detection Tests

    func testMultiplePIIInSameText() async throws {
        let input = """
        Contact: John Doe
        Email: john.doe@example.com
        Phone: 555-123-4567
        SSN: 123-45-6789
        """

        let result = try await maskingEngine.mask(text: input)

        XCTAssertGreaterThanOrEqual(result.detectedItems.count, 3)
        XCTAssertFalse(result.maskedText.contains("john.doe@example.com"))
        XCTAssertFalse(result.maskedText.contains("555-123-4567"))
        XCTAssertFalse(result.maskedText.contains("123-45-6789"))
    }

    func testOverlappingPatterns() async throws {
        // IP address that could match other patterns
        let result = try await maskingEngine.mask(text: "Server: 192.168.1.100")

        // Should not have duplicate detections
        XCTAssertEqual(result.detectedItems.count, 1)
    }

    // MARK: - Edge Cases

    func testNoFalsePositives() async throws {
        let safeCases = [
            "Hello world",
            "The price is $19.99",
            "Meeting at 3:00 PM",
            "Version 2.0.1",
            "127.0.0.1",  // Localhost is skipped
        ]

        for safeText in safeCases {
            let result = try await maskingEngine.mask(text: safeText)
            XCTAssertEqual(result.detectedItems.count, 0, "False positive in: \(safeText)")
        }
    }

    func testEmptyInput() async throws {
        let result = try await maskingEngine.mask(text: "")

        XCTAssertEqual(result.maskedText, "")
        XCTAssertEqual(result.detectedItems.count, 0)
    }

    func testPreservesFormatting() async throws {
        let input = "Line 1\nEmail: test@example.com\n\nLine 4"
        let result = try await maskingEngine.mask(text: input)

        XCTAssertTrue(result.maskedText.contains("\n"))
        XCTAssertTrue(result.maskedText.contains("Line 1"))
        XCTAssertTrue(result.maskedText.contains("Line 4"))
    }

    // MARK: - Performance Tests

    func testPerformanceLargeText() async throws {
        let largeText = String(repeating: "Email: test@example.com\n", count: 1000)

        let startTime = Date()
        let result = try await maskingEngine.mask(text: largeText)
        let elapsed = Date().timeIntervalSince(startTime)

        XCTAssertEqual(result.detectedItems.count, 1000)
        XCTAssertLessThan(elapsed, 5.0, "Should process 1000 items in under 5 seconds")
    }

    // MARK: - Regex/LLM Merge Integration Tests

    /// Test 1: Regex-only detection when LLM is not initialized
    func testRegexOnlyDetectionSourceAttribution() async throws {
        // MaskingEngine starts without LLM initialized
        let result = try await maskingEngine.mask(text: "Email: test@example.com")

        XCTAssertEqual(result.detectedItems.count, 1)
        XCTAssertEqual(result.detectedItems.first?.source, .regex, "Source should be regex when LLM not initialized")
        XCTAssertEqual(result.detectedItems.first?.type, .email)
    }

    /// Test 2: Multiple regex detections maintain source attribution
    func testMultipleRegexDetectionsSourceAttribution() async throws {
        let input = """
        Email: test@example.com
        Phone: 555-123-4567
        SSN: 123-45-6789
        """

        let result = try await maskingEngine.mask(text: input)

        XCTAssertGreaterThanOrEqual(result.detectedItems.count, 3)
        // All items should have regex source when LLM not initialized
        for item in result.detectedItems {
            XCTAssertEqual(item.source, .regex, "All detections should have regex source")
        }
    }

    /// Test 3: Verify LLM initialization status affects detection path
    func testLLMNotReadyUsesRegexOnly() async throws {
        // Verify LLM is not ready by default
        let isReady = await maskingEngine.isLLMReady
        XCTAssertFalse(isReady, "LLM should not be ready by default")

        // Detection should still work via regex
        let result = try await maskingEngine.mask(text: "API Key: sk-" + String(repeating: "a", count: 48))

        XCTAssertEqual(result.detectedItems.count, 1)
        XCTAssertEqual(result.detectedItems.first?.source, .regex)
    }

    /// Test 4: Graceful fallback - LLM not initialized doesn't crash masking
    func testGracefulFallbackWhenLLMNotInitialized() async throws {
        // Don't initialize LLM at all - verify regex still works
        let isReady = await maskingEngine.isLLMReady
        XCTAssertFalse(isReady, "LLM should not be ready")

        // Engine should still detect via regex
        let result = try await maskingEngine.mask(text: "Email: test@example.com")

        XCTAssertEqual(result.detectedItems.count, 1)
        XCTAssertEqual(result.detectedItems.first?.type, .email)
        XCTAssertEqual(result.detectedItems.first?.source, .regex)
    }

    /// Test 5: Empty text returns empty result (no crash)
    func testEmptyTextNoMergeIssues() async throws {
        let result = try await maskingEngine.mask(text: "")

        XCTAssertEqual(result.detectedItems.count, 0)
        XCTAssertEqual(result.maskedText, "")
        XCTAssertEqual(result.originalText, "")
    }

    /// Test 6: Single character text doesn't cause merge issues
    func testSingleCharacterTextNoMergeIssues() async throws {
        let result = try await maskingEngine.mask(text: "x")

        XCTAssertEqual(result.detectedItems.count, 0)
        XCTAssertEqual(result.maskedText, "x")
    }

    /// Test 7: Very long text with many PII items - verify no duplicates
    func testLargeTextNoDuplicateDetections() async throws {
        // Create text with same email repeated
        let email = "test@example.com"
        let text = Array(repeating: "Contact: \(email)", count: 100).joined(separator: "\n")

        let result = try await maskingEngine.mask(text: text)

        // Should have exactly 100 detections (one per line)
        XCTAssertEqual(result.detectedItems.count, 100, "Should have exactly 100 email detections")

        // All should be unique (different ranges)
        let uniqueRanges = Set(result.detectedItems.map { "\($0.range.lowerBound)" })
        XCTAssertEqual(uniqueRanges.count, 100, "All detections should have unique ranges")
    }
}
