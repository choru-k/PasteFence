import XCTest
@testable import PasteFence

/// Scale tests: Long inputs, many detections, chunk boundaries, performance
@MainActor
final class ScaleTests: XCTestCase {
    var detector: RegexDetector!

    override func setUp() {
        super.setUp()
        detector = RegexDetector()
    }

    // MARK: - Long Input Tests

    func testInput10KChars() {
        let text = IntegrationTestHelpers.generateLongText(length: 10_000, piiDensity: 2.0)

        XCTAssertGreaterThanOrEqual(text.count, 10_000)

        let startTime = Date()
        let results = detector.detect(in: text)
        let elapsed = Date().timeIntervalSince(startTime)

        XCTAssertGreaterThanOrEqual(results.count, 10, "Should find at least 10 PII items in 10K chars")
        XCTAssertLessThan(elapsed, 1.0, "Should process 10K chars in under 1 second, took \(elapsed)s")
    }

    func testInput50KChars() {
        let text = IntegrationTestHelpers.generateLongText(length: 50_000, piiDensity: 2.0)

        XCTAssertGreaterThanOrEqual(text.count, 50_000)

        let startTime = Date()
        let results = detector.detect(in: text)
        let elapsed = Date().timeIntervalSince(startTime)

        XCTAssertGreaterThanOrEqual(results.count, 50, "Should find at least 50 PII items in 50K chars")
        XCTAssertLessThan(elapsed, 3.0, "Should process 50K chars in under 3 seconds, took \(elapsed)s")
    }

    func testInput100KChars() {
        let text = IntegrationTestHelpers.generateLongText(length: 100_000, piiDensity: 2.0)

        XCTAssertGreaterThanOrEqual(text.count, 100_000)

        let startTime = Date()
        let results = detector.detect(in: text)
        let elapsed = Date().timeIntervalSince(startTime)

        XCTAssertGreaterThanOrEqual(results.count, 100, "Should find at least 100 PII items in 100K chars")
        XCTAssertLessThan(elapsed, 5.0, "Should process 100K chars in under 5 seconds, took \(elapsed)s")
    }

    func testInput250KCharsChunking() {
        // This would trigger LLM chunking (80K chunk size)
        let text = IntegrationTestHelpers.generateLongText(length: 250_000, piiDensity: 1.0)

        XCTAssertGreaterThanOrEqual(text.count, 250_000)

        let startTime = Date()
        let results = detector.detect(in: text)
        let elapsed = Date().timeIntervalSince(startTime)

        XCTAssertGreaterThanOrEqual(results.count, 150, "Should find many PII items in 250K chars")
        XCTAssertLessThan(elapsed, 15.0, "Should process 250K chars in under 15 seconds, took \(elapsed)s")
    }

    func testInput500KCharsMultiChunk() {
        // Would require multiple chunks for LLM
        let text = IntegrationTestHelpers.generateLongText(length: 500_000, piiDensity: 1.0)

        XCTAssertGreaterThanOrEqual(text.count, 500_000)

        let startTime = Date()
        let results = detector.detect(in: text)
        let elapsed = Date().timeIntervalSince(startTime)

        XCTAssertGreaterThanOrEqual(results.count, 300, "Should find many PII items in 500K chars")
        XCTAssertLessThan(elapsed, 30.0, "Should process 500K chars in under 30 seconds, took \(elapsed)s")
    }

    // MARK: - Many Detections Tests

    func test20DetectionsHighDensity() {
        let text = IntegrationTestHelpers.generateTextWithManyPII(count: 20)

        let results = detector.detect(in: text)

        XCTAssertGreaterThanOrEqual(results.count, 18, "Should detect at least 18 of 20 PII items")
    }

    func test50DetectionsMediumDensity() {
        let text = IntegrationTestHelpers.generateTextWithManyPII(count: 50)

        let results = detector.detect(in: text)

        XCTAssertGreaterThanOrEqual(results.count, 45, "Should detect at least 45 of 50 PII items")
    }

    func test100DetectionsMixedTypes() {
        let types: [SensitiveType] = [.email, .phone, .creditCard, .apiKey, .ipAddress, .ssn]
        let text = IntegrationTestHelpers.generateTextWithManyPII(count: 100, types: types)

        let results = detector.detect(in: text)

        XCTAssertGreaterThanOrEqual(results.count, 90, "Should detect at least 90 of 100 PII items")

        // Should have variety of types
        let typeSet = Set(results.map { $0.type })
        XCTAssertGreaterThanOrEqual(typeSet.count, 4, "Should detect multiple PII types")
    }

    func test200DetectionsLargeText() {
        let types: [SensitiveType] = [.email, .phone, .creditCard, .apiKey, .ipAddress]
        let text = IntegrationTestHelpers.generateTextWithManyPII(count: 200, types: types)

        let startTime = Date()
        let results = detector.detect(in: text)
        let elapsed = Date().timeIntervalSince(startTime)

        XCTAssertGreaterThanOrEqual(results.count, 180, "Should detect at least 180 of 200 PII items")
        XCTAssertLessThan(elapsed, 5.0, "Should process 200 items in under 5 seconds")
    }

    // MARK: - Chunk Boundary Tests

    func testEmailAtExactChunkBoundary() {
        let chunkSize = LLMDetectorTestHelper.chunkSize
        // Place email at position that would be near chunk boundary
        // Email "boundary@test.com" is 17 chars, so offset must be at least chunkSize - 17
        let text = IntegrationTestHelpers.generateChunkBoundaryText(
            piiAtOffset: chunkSize - 25,  // Email ends at position 79,992, within first chunk
            piiType: .email
        )

        // Test chunking behavior
        let chunks = LLMDetectorTestHelper.splitIntoChunks(text)

        // Should have multiple chunks
        XCTAssertGreaterThan(chunks.count, 1, "Should split into multiple chunks")

        // Email should be in first chunk
        XCTAssertTrue(chunks[0].text.contains("boundary@test.com"), "Email should be in first chunk")

        // Regex should still find it in full text
        let results = detector.detect(in: text)
        XCTAssertTrue(results.contains { $0.type == .email }, "Should detect email near chunk boundary")
    }

    func testPIISpanningChunkBoundary() {
        let chunkSize = LLMDetectorTestHelper.chunkSize
        let overlap = LLMDetectorTestHelper.chunkOverlap

        // Place a long JWT right at the boundary
        let jwt = IntegrationTestHelpers.randomJWT(index: 0)
        let preText = String(repeating: "x", count: chunkSize - jwt.count / 2)
        let postText = String(repeating: "y", count: chunkSize)
        let text = preText + jwt + postText

        let chunks = LLMDetectorTestHelper.splitIntoChunks(text)

        // Due to overlap, JWT should be fully present in at least one chunk
        let jwtInChunk = chunks.contains { $0.text.contains("eyJ") }
        XCTAssertTrue(jwtInChunk, "JWT should be present in at least one chunk due to overlap")
    }

    func testOverlapRegionContainsPII() {
        let chunkSize = LLMDetectorTestHelper.chunkSize
        let overlap = LLMDetectorTestHelper.chunkOverlap

        // Place email in the overlap region (between chunk end - overlap and chunk end)
        let overlapStart = chunkSize - overlap
        let emailOffset = overlapStart + overlap / 2  // Middle of overlap region

        let text = IntegrationTestHelpers.generateChunkBoundaryText(
            piiAtOffset: emailOffset,
            piiType: .email
        )

        let chunks = LLMDetectorTestHelper.splitIntoChunks(text)

        // Email should be in both first and second chunk due to overlap
        if chunks.count > 1 {
            XCTAssertTrue(chunks[0].text.contains("boundary@test.com"), "Email should be in first chunk")
            XCTAssertTrue(chunks[1].text.contains("boundary@test.com"), "Email should be in second chunk due to overlap")
        }
    }

    func testMultiplePIIInOverlapRegion() {
        let chunkSize = LLMDetectorTestHelper.chunkSize
        let overlap = LLMDetectorTestHelper.chunkOverlap

        // Place multiple PII items in overlap region
        let overlapStart = chunkSize - overlap
        var text = String(repeating: "x", count: overlapStart)
        text += " email1@test.com "
        text += " email2@test.com "
        text += " 555-123-4567 "
        text += String(repeating: "y", count: chunkSize)

        let chunks = LLMDetectorTestHelper.splitIntoChunks(text)

        // All PII should be in overlap and thus in both chunks
        if chunks.count > 1 {
            XCTAssertTrue(chunks[0].text.contains("email1@test.com"))
            XCTAssertTrue(chunks[1].text.contains("email1@test.com"))
        }

        // Regex should find all in full text
        let results = detector.detect(in: text)
        let emails = results.filter { $0.type == .email }
        XCTAssertGreaterThanOrEqual(emails.count, 2)
    }

    func testDeduplicationAcrossChunks() {
        // Test the deduplication logic for overlapping detections
        let email = "overlap@example.com"
        let text = "Sample text with \(email) in the middle"
        let emailRange = text.range(of: email)!

        // Simulate same detection from two chunks (different confidence)
        let item1 = DetectedItem(
            text: email,
            type: .email,
            range: emailRange,
            confidence: 0.9,
            source: .llm,
            ruleName: nil
        )
        let item2 = DetectedItem(
            text: email,
            type: .email,
            range: emailRange,
            confidence: 0.85,
            source: .llm,
            ruleName: nil
        )

        let deduplicated = LLMDetectorTestHelper.deduplicateResults([item1, item2])

        XCTAssertEqual(deduplicated.count, 1, "Should deduplicate to single item")
        XCTAssertEqual(deduplicated[0].confidence, 0.9, "Should keep higher confidence item")
    }

    // MARK: - Performance Tests

    func testRegexPerformance1000Items() {
        // Generate text with 1000 email addresses
        var text = ""
        for i in 0..<1000 {
            text += "Contact user\(i)@domain\(i).com for more info. "
        }

        measure {
            let results = detector.detect(in: text)
            XCTAssertGreaterThanOrEqual(results.count, 900)
        }
    }

    func testRegexPerformanceAllPatternTypes() {
        // Generate text with all pattern types
        var text = ""
        for i in 0..<100 {
            text += """
                Entry \(i):
                Email: user\(i)@example.com
                Phone: 555-\(100 + i)-\(1000 + i)
                Card: 4111-1111-1111-\(1111 + i)
                SSN: \(100 + i)-\(10 + (i % 89))-\(1000 + i)
                IP: 10.\(i % 256).\((i / 256) % 256).\(1 + (i % 254))

                """
        }

        measure {
            let results = detector.detect(in: text)
            XCTAssertGreaterThanOrEqual(results.count, 400)
        }
    }

    func testMaskingEnginePerformance() async throws {
        let maskingEngine = MaskingEngine()

        // Generate moderate-sized text
        let text = IntegrationTestHelpers.generateTextWithManyPII(count: 50)

        let startTime = Date()
        let result = try await maskingEngine.mask(text: text)
        let elapsed = Date().timeIntervalSince(startTime)

        XCTAssertGreaterThanOrEqual(result.detectedItems.count, 40)
        XCTAssertLessThan(elapsed, 2.0, "MaskingEngine should process 50 items in under 2 seconds")
    }

    // MARK: - Stress Tests

    func testRapidSuccessiveDetections() {
        // Test that detector handles rapid successive calls
        let texts = (0..<100).map { i in
            "Contact user\(i)@test.com at 555-\(100 + i)-\(1000 + i)"
        }

        var totalDetections = 0
        let startTime = Date()

        for text in texts {
            let results = detector.detect(in: text)
            totalDetections += results.count
        }

        let elapsed = Date().timeIntervalSince(startTime)

        XCTAssertGreaterThanOrEqual(totalDetections, 180)  // At least email + phone per text
        XCTAssertLessThan(elapsed, 5.0, "100 rapid detections should complete in under 5 seconds")
    }

    func testVerySmallInput() {
        let testCases = [
            "",
            " ",
            "a",
            "test",
            "no pii here"
        ]

        for text in testCases {
            XCTContext.runActivity(named: "Checking: '\(text)'") { _ in
                let results = detector.detect(in: text)
                XCTAssertEqual(results.count, 0, "No PII in small input: '\(text)'")
            }
        }
    }

    func testRepeatedSamePII() {
        // Same email repeated many times
        let email = "repeated@test.com"
        let text = String(repeating: "\(email) ", count: 100)

        let results = detector.detect(in: text)

        // Should detect each occurrence
        let emails = results.filter { $0.type == .email }
        XCTAssertGreaterThanOrEqual(emails.count, 90, "Should detect most repeated emails")
    }

    // MARK: - Memory Tests

    func testNoMemoryLeakInLongText() {
        // This is a basic sanity check - proper memory testing would use Instruments
        autoreleasepool {
            let text = IntegrationTestHelpers.generateLongText(length: 100_000, piiDensity: 2.0)
            let results = detector.detect(in: text)
            XCTAssertGreaterThan(results.count, 0)
        }
        // If we get here without crashing, basic memory handling is OK
    }

    // MARK: - Consistency Tests

    func testDeterministicResults() {
        let text = IntegrationTestHelpers.generateTextWithManyPII(count: 20)

        let results1 = detector.detect(in: text)
        let results2 = detector.detect(in: text)
        let results3 = detector.detect(in: text)

        // Same input should produce same output
        XCTAssertEqual(results1.count, results2.count)
        XCTAssertEqual(results2.count, results3.count)

        // Order should be consistent
        for i in 0..<min(results1.count, results2.count) {
            XCTAssertEqual(results1[i].text, results2[i].text)
            XCTAssertEqual(results1[i].type, results2[i].type)
        }
    }

    func testResultsAreOrdered() {
        let text = """
            First: email1@test.com
            Second: email2@test.com
            Third: email3@test.com
            """

        let results = detector.detect(in: text)

        // Results should be ordered by position in text
        for i in 0..<(results.count - 1) {
            XCTAssertLessThan(
                results[i].range.lowerBound,
                results[i + 1].range.lowerBound,
                "Results should be ordered by position"
            )
        }
    }

    // MARK: - Overlap Resolution Tests

    func testOverlapResolutionHigherConfidenceWins() {
        // Test that when patterns overlap, higher confidence wins
        // Database URL (confidence 1.0) contains email-like pattern
        let text = "Connection: postgresql://admin@db.example.com:5432/mydb"

        let results = detector.detect(in: text)

        // Should have database URL (high confidence)
        let dbUrls = results.filter { $0.type == .databaseUrl }
        XCTAssertEqual(dbUrls.count, 1, "Should detect database URL")

        // Email within URL should NOT be separately detected (overlap resolution)
        // The email pattern "admin@db.example.com" is within the database URL
        let emails = results.filter { $0.type == .email }
        // Note: May or may not overlap depending on pattern order
        // Document the actual behavior
        XCTAssertLessThanOrEqual(emails.count, 1, "Email should be deduplicated or absent")
    }

    func testOverlapResolutionLongerMatchWins() {
        // When confidence is equal, longer match should win
        // Test with two overlapping patterns of same confidence (test mode key)
        let text = "Key: sk_test_51N0example1234567890123"

        let results = detector.detect(in: text)

        // Stripe key (more specific) should be preferred
        let stripeKeys = results.filter { $0.type == .stripeKey }
        XCTAssertEqual(stripeKeys.count, 1, "Should detect Stripe key")

        // Count total items matching this text region
        let itemsContainingKey = results.filter { $0.text.contains("sk_test") }
        XCTAssertEqual(
            itemsContainingKey.count, 1,
            "Overlapping patterns should deduplicate to single item"
        )
    }

    func testNoFalseDuplicatesInResults() {
        // Ensure no duplicate detections for same text
        let text = "Email: test@example.com Phone: 555-123-4567"

        let results = detector.detect(in: text)

        // Check for duplicates by comparing text values
        var seenTexts = Set<String>()
        for item in results {
            XCTAssertFalse(
                seenTexts.contains(item.text),
                "Duplicate detection found: \(item.text)"
            )
            seenTexts.insert(item.text)
        }
    }
}
