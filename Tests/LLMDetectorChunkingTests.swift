import XCTest
@testable import PasteFence

// MARK: - Chunking Logic Tests

final class LLMDetectorChunkingTests: XCTestCase {

    // MARK: - Split Into Chunks Tests

    func testSmallTextNotChunked() {
        // Text smaller than chunk size should return single chunk
        let text = "Hello world with test@example.com"

        let chunks = LLMDetectorTestHelper.splitIntoChunks(text)

        XCTAssertEqual(chunks.count, 1)
        XCTAssertEqual(chunks[0].text, text)
        XCTAssertEqual(chunks[0].offset, 0)
    }

    func testExactChunkSizeNotChunked() {
        // Text exactly at chunk size should return single chunk
        let text = String(repeating: "x", count: LLMDetectorTestHelper.chunkSize)

        let chunks = LLMDetectorTestHelper.splitIntoChunks(text)

        XCTAssertEqual(chunks.count, 1)
        XCTAssertEqual(chunks[0].text.count, LLMDetectorTestHelper.chunkSize)
    }

    func testLargeTextChunkedWithOverlap() {
        // Text larger than chunk size should be split with overlap
        let chunkSize = LLMDetectorTestHelper.chunkSize
        let overlap = LLMDetectorTestHelper.chunkOverlap

        // Create text that's 1.5x chunk size
        let text = String(repeating: "a", count: chunkSize + chunkSize / 2)

        let chunks = LLMDetectorTestHelper.splitIntoChunks(text)

        // Should have 2 chunks
        XCTAssertEqual(chunks.count, 2)

        // First chunk starts at 0
        XCTAssertEqual(chunks[0].offset, 0)
        XCTAssertEqual(chunks[0].text.count, chunkSize)

        // Second chunk starts at (chunkSize - overlap)
        let expectedSecondOffset = chunkSize - overlap
        XCTAssertEqual(chunks[1].offset, expectedSecondOffset)

        // Second chunk should capture remainder
        XCTAssertEqual(chunks[1].text.count, text.count - expectedSecondOffset)
    }

    func testChunksOverlapCorrectly() {
        // Verify the overlap region contains the same content
        let chunkSize = LLMDetectorTestHelper.chunkSize
        let overlap = LLMDetectorTestHelper.chunkOverlap

        // Create text with marker at the overlap boundary
        let preOverlap = String(repeating: "a", count: chunkSize - overlap)
        let overlapMarker = "OVERLAP_MARKER"
        let postMarker = String(repeating: "b", count: overlap + 10_000)
        let text = preOverlap + overlapMarker + postMarker

        let chunks = LLMDetectorTestHelper.splitIntoChunks(text)

        // Marker should appear in both chunks due to overlap
        XCTAssertTrue(chunks[0].text.contains(overlapMarker), "Marker should be in first chunk")
        XCTAssertTrue(chunks[1].text.contains(overlapMarker), "Marker should be in second chunk due to overlap")
    }

    func testMultipleChunks() {
        // Test with very large text requiring multiple chunks
        let chunkSize = LLMDetectorTestHelper.chunkSize
        let overlap = LLMDetectorTestHelper.chunkOverlap
        let stride = chunkSize - overlap

        // Create text ~2.5 chunks
        let text = String(repeating: "x", count: Int(Double(chunkSize) * 2.5))

        let chunks = LLMDetectorTestHelper.splitIntoChunks(text)

        // Should have 3 chunks
        XCTAssertEqual(chunks.count, 3)

        // Verify offsets
        XCTAssertEqual(chunks[0].offset, 0)
        XCTAssertEqual(chunks[1].offset, stride)
        XCTAssertEqual(chunks[2].offset, stride * 2)
    }

    // MARK: - Deduplication Tests

    func testDeduplicationSingleItem() {
        // Single item should pass through unchanged
        let text = "test@example.com"
        let item = DetectedItem(
            text: text,
            type: .email,
            range: text.startIndex..<text.endIndex,
            confidence: 0.9,
            source: .llm,
            ruleName: nil
        )

        let result = LLMDetectorTestHelper.deduplicateResults([item])

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].text, text)
    }

    func testDeduplicationNoOverlap() {
        // Non-overlapping items should all be kept
        let text = "Email: test@example.com Phone: 555-1234"
        let emailRange = text.range(of: "test@example.com")!
        let phoneRange = text.range(of: "555-1234")!

        let items = [
            DetectedItem(text: "test@example.com", type: .email, range: emailRange, confidence: 0.9, source: .llm, ruleName: nil),
            DetectedItem(text: "555-1234", type: .phone, range: phoneRange, confidence: 0.85, source: .llm, ruleName: nil)
        ]

        let result = LLMDetectorTestHelper.deduplicateResults(items)

        XCTAssertEqual(result.count, 2)
    }

    func testDeduplicationOverlapKeepsHigherConfidence() {
        // Overlapping items should keep higher confidence
        let text = "test@example.com"
        let range = text.startIndex..<text.endIndex

        let items = [
            DetectedItem(text: text, type: .email, range: range, confidence: 0.85, source: .llm, ruleName: nil),
            DetectedItem(text: text, type: .email, range: range, confidence: 0.95, source: .llm, ruleName: nil)
        ]

        let result = LLMDetectorTestHelper.deduplicateResults(items)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].confidence, 0.95)
    }

    func testDeduplicationOverlapKeepsLongerOnEqualConfidence() {
        // When confidence is equal, keep longer match
        let text = "Contact sk-abc123xyz for help"
        let shortRange = text.range(of: "sk-abc123")!
        let longRange = text.range(of: "sk-abc123xyz")!

        let items = [
            DetectedItem(text: "sk-abc123xyz", type: .apiKey, range: longRange, confidence: 0.9, source: .llm, ruleName: nil),
            DetectedItem(text: "sk-abc123", type: .apiKey, range: shortRange, confidence: 0.9, source: .llm, ruleName: nil)
        ]

        let result = LLMDetectorTestHelper.deduplicateResults(items)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].text, "sk-abc123xyz")
    }

    func testDeduplicationMixedOverlap() {
        // Mix of overlapping and non-overlapping
        let text = "Email: test@example.com and test@example.com again with phone 555-1234"
        let email1Range = text.range(of: "test@example.com")!
        // Find second occurrence
        let afterFirst = text.index(email1Range.upperBound, offsetBy: 5)
        let email2Range = text[afterFirst...].range(of: "test@example.com")!
        let phoneRange = text.range(of: "555-1234")!

        let items = [
            DetectedItem(text: "test@example.com", type: .email, range: email1Range, confidence: 0.9, source: .llm, ruleName: nil),
            DetectedItem(text: "test@example.com", type: .email, range: email1Range, confidence: 0.85, source: .llm, ruleName: nil), // duplicate
            DetectedItem(text: "test@example.com", type: .email, range: email2Range, confidence: 0.88, source: .llm, ruleName: nil),
            DetectedItem(text: "555-1234", type: .phone, range: phoneRange, confidence: 0.85, source: .llm, ruleName: nil)
        ]

        let result = LLMDetectorTestHelper.deduplicateResults(items)

        // Should have 3: email1 (highest conf), email2, phone
        XCTAssertEqual(result.count, 3)

        // First email should have highest confidence
        let firstEmailResults = result.filter { $0.range == email1Range }
        XCTAssertEqual(firstEmailResults.count, 1)
        XCTAssertEqual(firstEmailResults[0].confidence, 0.9)
    }

    func testDeduplicationSortsByPosition() {
        // Items should be sorted by position regardless of input order
        let text = "First: aaa@test.com Second: bbb@test.com"
        let firstRange = text.range(of: "aaa@test.com")!
        let secondRange = text.range(of: "bbb@test.com")!

        // Input in reverse order
        let items = [
            DetectedItem(text: "bbb@test.com", type: .email, range: secondRange, confidence: 0.9, source: .llm, ruleName: nil),
            DetectedItem(text: "aaa@test.com", type: .email, range: firstRange, confidence: 0.85, source: .llm, ruleName: nil)
        ]

        let result = LLMDetectorTestHelper.deduplicateResults(items)

        XCTAssertEqual(result.count, 2)
        // First result should be the one that appears first in text
        XCTAssertEqual(result[0].text, "aaa@test.com")
        XCTAssertEqual(result[1].text, "bbb@test.com")
    }

    // MARK: - Chunk Boundary Tests

    func testPIIAtChunkBoundaryDetectableInOverlap() {
        // Simulate PII placed exactly at the overlap boundary
        let chunkSize = LLMDetectorTestHelper.chunkSize
        let overlap = LLMDetectorTestHelper.chunkOverlap

        // Place email at position where it falls in overlap region
        let preEmail = String(repeating: "x", count: chunkSize - overlap / 2)
        let email = "boundary@test.com"
        let postEmail = String(repeating: "y", count: overlap)

        let fullText = preEmail + email + postEmail

        // Get chunks
        let chunks = LLMDetectorTestHelper.splitIntoChunks(fullText)

        // Email should be findable in chunk 1
        XCTAssertTrue(chunks[0].text.contains(email), "Email should be in first chunk")

        // If there's a second chunk, email should also be there (due to overlap)
        if chunks.count > 1 {
            XCTAssertTrue(chunks[1].text.contains(email), "Email should be in second chunk due to overlap")
        }
    }

    // MARK: - Deduplication Edge Cases (Phase 2)

    /// Test: Triple overlap - highest confidence wins
    func testTripleOverlapHighestConfidenceWins() {
        let text = "sk-abc123xyz"
        let range = text.startIndex..<text.endIndex

        let items = [
            DetectedItem(text: text, type: .apiKey, range: range, confidence: 0.7, source: .llm, ruleName: nil),
            DetectedItem(text: text, type: .apiKey, range: range, confidence: 0.95, source: .llm, ruleName: nil),
            DetectedItem(text: text, type: .apiKey, range: range, confidence: 0.85, source: .llm, ruleName: nil)
        ]

        let result = LLMDetectorTestHelper.deduplicateResults(items)

        XCTAssertEqual(result.count, 1, "Should deduplicate to single item")
        XCTAssertEqual(result[0].confidence, 0.95, "Should keep highest confidence (0.95)")
    }

    /// Test: Same confidence, same length - first one wins (order preservation)
    func testSameConfidenceSameLengthFirstWins() {
        let text = "test@example.com"
        let range = text.startIndex..<text.endIndex

        let items = [
            DetectedItem(text: text, type: .email, range: range, confidence: 0.9, source: .regex, ruleName: "email_rule"),
            DetectedItem(text: text, type: .email, range: range, confidence: 0.9, source: .llm, ruleName: nil)
        ]

        let result = LLMDetectorTestHelper.deduplicateResults(items)

        XCTAssertEqual(result.count, 1, "Should deduplicate to single item")
        // First item wins when confidence and length are equal
        XCTAssertEqual(result[0].source, .regex, "First item (regex) should win on tie")
    }

    /// Test: Adjacent non-overlapping items both kept
    func testAdjacentNonOverlappingBothKept() {
        let text = "email@test.com password123"
        let emailRange = text.range(of: "email@test.com")!
        let passRange = text.range(of: "password123")!

        let items = [
            DetectedItem(text: "email@test.com", type: .email, range: emailRange, confidence: 0.9, source: .regex, ruleName: nil),
            DetectedItem(text: "password123", type: .password, range: passRange, confidence: 0.85, source: .llm, ruleName: nil)
        ]

        let result = LLMDetectorTestHelper.deduplicateResults(items)

        XCTAssertEqual(result.count, 2, "Adjacent non-overlapping items should both be kept")
        XCTAssertEqual(result[0].type, .email)
        XCTAssertEqual(result[1].type, .password)
    }

    /// Test: Partial overlap (50%+) should deduplicate
    func testPartialOverlapDeduplicates() {
        // Create overlapping ranges
        let text = "sk-abcdefghij1234567890"

        // Partial overlap: "sk-abcdefghij" overlaps with "abcdefghij1234567890"
        let shortRange = text.range(of: "sk-abcdefghij")!
        let overlapRange = text.range(of: "abcdefghij1234567890")!

        let items = [
            DetectedItem(text: "sk-abcdefghij", type: .apiKey, range: shortRange, confidence: 0.85, source: .regex, ruleName: nil),
            DetectedItem(text: "abcdefghij1234567890", type: .genericSecret, range: overlapRange, confidence: 0.9, source: .llm, ruleName: nil)
        ]

        let result = LLMDetectorTestHelper.deduplicateResults(items)

        // Overlapping items should deduplicate - higher confidence wins
        XCTAssertEqual(result.count, 1, "Partial overlap should deduplicate")
        XCTAssertEqual(result[0].confidence, 0.9, "Higher confidence should win")
    }

    // MARK: - Chunking Integration Tests (Phase 3)

    /// Test: End-to-end chunking with deduplication
    func testEndToEndChunkingWithDeduplication() {
        let chunkSize = LLMDetectorTestHelper.chunkSize
        let overlap = LLMDetectorTestHelper.chunkOverlap

        // Create text with email in overlap region
        let preEmail = String(repeating: "a", count: chunkSize - overlap / 2)
        let email = "overlap@example.com"
        let postEmail = String(repeating: "b", count: overlap * 2)

        let fullText = preEmail + email + postEmail

        // Split into chunks
        let chunks = LLMDetectorTestHelper.splitIntoChunks(fullText)
        XCTAssertGreaterThanOrEqual(chunks.count, 2, "Should have at least 2 chunks")

        // Verify email is in both chunks (overlap region)
        XCTAssertTrue(chunks[0].text.contains(email), "Email should be in first chunk")
        XCTAssertTrue(chunks[1].text.contains(email), "Email should be in second chunk due to overlap")

        // Simulate detecting the email in both chunks
        let emailRange1 = chunks[0].text.range(of: email)!
        let offset1 = chunks[0].offset + chunks[0].text.distance(from: chunks[0].text.startIndex, to: emailRange1.lowerBound)

        let emailRange2 = chunks[1].text.range(of: email)!
        let offset2 = chunks[1].offset + chunks[1].text.distance(from: chunks[1].text.startIndex, to: emailRange2.lowerBound)

        // Both should point to same position in original text
        XCTAssertEqual(offset1, offset2, "Same email in overlap should have same offset in original text")
    }

    /// Test: Offset mapping correctness - chunk ranges map to original text
    func testChunkOffsetsMapToOriginalText() {
        let chunkSize = LLMDetectorTestHelper.chunkSize

        // Create text with marker at specific position
        let marker = "UNIQUE_MARKER_12345"
        let markerPosition = chunkSize + 5000  // In the middle of overlap region of chunk 2

        let preMarker = String(repeating: "x", count: markerPosition)
        let postMarker = String(repeating: "y", count: chunkSize)
        let fullText = preMarker + marker + postMarker

        let chunks = LLMDetectorTestHelper.splitIntoChunks(fullText)

        // Find marker in chunks
        var foundInChunk = -1
        var localOffset = 0

        for (idx, chunk) in chunks.enumerated() {
            if let range = chunk.text.range(of: marker) {
                foundInChunk = idx
                localOffset = chunk.text.distance(from: chunk.text.startIndex, to: range.lowerBound)
                break
            }
        }

        XCTAssertNotEqual(foundInChunk, -1, "Marker should be found in some chunk")

        // Calculate global offset
        let globalOffset = chunks[foundInChunk].offset + localOffset
        XCTAssertEqual(globalOffset, markerPosition, "Calculated offset should match actual position")
    }

    /// Test: Three chunks with same PII - deduplicated correctly
    func testThreeChunksDeduplication() {
        let chunkSize = LLMDetectorTestHelper.chunkSize
        let overlap = LLMDetectorTestHelper.chunkOverlap
        let stride = chunkSize - overlap

        // Create 3-chunk text with email in overlap between chunk 1 and 2
        let email = "multipass@test.com"
        let emailPosition = stride - overlap / 2  // In overlap region

        let totalSize = Int(Double(chunkSize) * 2.5)  // ~3 chunks
        var text = String(repeating: "x", count: totalSize)

        // Insert email at calculated position
        let insertIndex = text.index(text.startIndex, offsetBy: emailPosition)
        text.insert(contentsOf: email, at: insertIndex)

        let chunks = LLMDetectorTestHelper.splitIntoChunks(text)
        XCTAssertGreaterThanOrEqual(chunks.count, 3, "Should have at least 3 chunks")

        // Simulate detections from multiple chunks
        var detections: [DetectedItem] = []

        for (idx, chunk) in chunks.enumerated() {
            if let range = chunk.text.range(of: email) {
                let globalOffset = chunk.offset + chunk.text.distance(from: chunk.text.startIndex, to: range.lowerBound)
                let globalStart = text.index(text.startIndex, offsetBy: globalOffset)
                let globalEnd = text.index(globalStart, offsetBy: email.count)

                let item = DetectedItem(
                    text: email,
                    type: .email,
                    range: globalStart..<globalEnd,
                    confidence: 0.9 - Double(idx) * 0.05,  // Slightly different confidence per chunk
                    source: .llm,
                    ruleName: nil
                )
                detections.append(item)
            }
        }

        let deduplicated = LLMDetectorTestHelper.deduplicateResults(detections)

        // Should have exactly 1 result after deduplication
        XCTAssertEqual(deduplicated.count, 1, "Same PII from multiple chunks should deduplicate to 1")
        XCTAssertEqual(deduplicated[0].confidence, 0.9, "Highest confidence should win")
    }

    /// Test: PII spanning exact chunk boundary is still detectable
    func testPIISpanningChunkBoundary() {
        let chunkSize = LLMDetectorTestHelper.chunkSize
        let overlap = LLMDetectorTestHelper.chunkOverlap

        // Place PII exactly at chunk boundary
        let apiKey = "sk-" + String(repeating: "a", count: 48)
        let boundaryPosition = chunkSize - 10  // Split the key across boundary

        let preKey = String(repeating: "x", count: boundaryPosition)
        let postKey = String(repeating: "y", count: overlap + 10000)
        let fullText = preKey + apiKey + postKey

        let chunks = LLMDetectorTestHelper.splitIntoChunks(fullText)

        // Key should be fully contained in at least one chunk (due to overlap)
        var foundComplete = false
        for chunk in chunks {
            if chunk.text.contains(apiKey) {
                foundComplete = true
                break
            }
        }

        XCTAssertTrue(foundComplete, "PII at boundary should be fully contained in overlap region of at least one chunk")
    }
}
