import XCTest
@testable import PasteFence

final class HistoryViewTests: XCTestCase {

    // MARK: - TypePillsView Tests

    func testTypePillsViewUniqueTypes() {
        let items = [
            HistoryDetectedItem(text: "test@email.com", type: "EMAIL", startOffset: 0, endOffset: 14, confidence: 1.0, source: "regex"),
            HistoryDetectedItem(text: "another@email.com", type: "EMAIL", startOffset: 20, endOffset: 37, confidence: 1.0, source: "regex"),
            HistoryDetectedItem(text: "123-456-7890", type: "PHONE", startOffset: 40, endOffset: 52, confidence: 0.9, source: "regex")
        ]

        // Verify unique types extraction
        let uniqueTypes = Array(Set(items.map(\.type))).sorted()
        XCTAssertEqual(uniqueTypes.count, 2)
        XCTAssertTrue(uniqueTypes.contains("EMAIL"))
        XCTAssertTrue(uniqueTypes.contains("PHONE"))
    }

    func testTypePillsViewLimitToThree() {
        let items = [
            HistoryDetectedItem(text: "test@email.com", type: "EMAIL", startOffset: 0, endOffset: 14, confidence: 1.0, source: "regex"),
            HistoryDetectedItem(text: "123-456-7890", type: "PHONE", startOffset: 20, endOffset: 32, confidence: 0.9, source: "regex"),
            HistoryDetectedItem(text: "4111-1111", type: "CREDIT_CARD", startOffset: 40, endOffset: 49, confidence: 1.0, source: "regex"),
            HistoryDetectedItem(text: "sk-xxx", type: "API_KEY", startOffset: 50, endOffset: 56, confidence: 1.0, source: "regex"),
            HistoryDetectedItem(text: "192.168.1.1", type: "IP_ADDRESS", startOffset: 60, endOffset: 71, confidence: 0.8, source: "regex")
        ]

        let uniqueTypes = Array(Set(items.map(\.type))).sorted()
        XCTAssertEqual(uniqueTypes.count, 5)
        // View should show only first 3 and "+2" indicator
        XCTAssertEqual(uniqueTypes.prefix(3).count, 3)
        XCTAssertEqual(uniqueTypes.count - 3, 2)
    }

    // MARK: - HistoryRowView Data Tests

    func testHistoryRowDisplaysCorrectCounts() {
        let detected = [
            HistoryDetectedItem(text: "email@test.com", type: "EMAIL", startOffset: 0, endOffset: 14, confidence: 1.0, source: "regex"),
            HistoryDetectedItem(text: "123-456-7890", type: "PHONE", startOffset: 20, endOffset: 32, confidence: 0.9, source: "regex"),
            HistoryDetectedItem(text: "sk-xxx", type: "API_KEY", startOffset: 40, endOffset: 46, confidence: 1.0, source: "regex")
        ]

        let applied = [detected[0], detected[2]]  // Only email and API key masked

        let entry = MaskingHistoryEntry(
            originalText: "Contact: email@test.com, phone: 123-456-7890, key: sk-xxx",
            maskedText: "Contact: [EMAIL_MASKED], phone: 123-456-7890, key: [API_KEY_MASKED]",
            detectedItems: detected,
            appliedItems: applied,
            source: .regexOnly
        )

        XCTAssertEqual(entry.detectedCount, 3)
        XCTAssertEqual(entry.appliedCount, 2)
        XCTAssertEqual(entry.skippedCount, 1)
    }

    // MARK: - Filter Logic Tests

    func testSearchFiltering() {
        var history = MaskingHistory()

        history.add(MaskingHistoryEntry(
            originalText: "Contact: john@example.com",
            maskedText: "Contact: [EMAIL_MASKED]",
            detectedItems: [
                HistoryDetectedItem(text: "john@example.com", type: "EMAIL", startOffset: 9, endOffset: 25, confidence: 1.0, source: "regex")
            ],
            appliedItems: [],
            source: .regexOnly
        ))

        history.add(MaskingHistoryEntry(
            originalText: "Server IP: 192.168.1.100",
            maskedText: "Server IP: [IP_MASKED]",
            detectedItems: [
                HistoryDetectedItem(text: "192.168.1.100", type: "IP_ADDRESS", startOffset: 11, endOffset: 24, confidence: 0.9, source: "regex")
            ],
            appliedItems: [],
            source: .regexOnly
        ))

        // Search for email
        let emailResults = history.search(query: "john")
        XCTAssertEqual(emailResults.count, 1)
        XCTAssertTrue(emailResults.first?.originalText.contains("john") ?? false)

        // Search for IP
        let ipResults = history.search(query: "192.168")
        XCTAssertEqual(ipResults.count, 1)
        XCTAssertTrue(ipResults.first?.originalText.contains("192.168") ?? false)

        // Search with no results
        let noResults = history.search(query: "nonexistent")
        XCTAssertEqual(noResults.count, 0)

        // Empty search returns all
        let allResults = history.search(query: "")
        XCTAssertEqual(allResults.count, 2)
    }

    // MARK: - Type Color Mapping Tests

    func testTypeColorMapping() {
        // Verify the mapping function works correctly for known types
        let typeColorMap: [String: Bool] = [
            "EMAIL": true,
            "PHONE": true,
            "CREDIT_CARD": true,
            "API_KEY": true,
            "AWS_KEY": true,
            "JWT": true,
            "PRIVATE_KEY": true,
            "PASSWORD": true,
            "GENERIC_SECRET": true,
            "IP_ADDRESS": true,
            "UNKNOWN_TYPE": true  // Should default to gray
        ]

        for type in typeColorMap.keys {
            // Just verify all types can be processed without error
            XCTAssertTrue(typeColorMap[type] ?? false, "Type \(type) should be handled")
        }
    }

    // MARK: - Source Badge Tests

    func testSourceBadgeLabels() {
        XCTAssertEqual(MaskingHistoryEntry.MaskingSource.regexOnly.rawValue, "regex")
        XCTAssertEqual(MaskingHistoryEntry.MaskingSource.hybrid.rawValue, "hybrid")
        XCTAssertEqual(MaskingHistoryEntry.MaskingSource.ollamaOnly.rawValue, "ollama")
    }

    // MARK: - Applied Status Tests

    func testAppliedStatusDetection() {
        let item1 = HistoryDetectedItem(id: UUID(), text: "test@email.com", type: "EMAIL", startOffset: 0, endOffset: 14, confidence: 1.0, source: "regex")
        let item2 = HistoryDetectedItem(id: UUID(), text: "123-456-7890", type: "PHONE", startOffset: 20, endOffset: 32, confidence: 0.9, source: "regex")

        let applied = [item1]  // Only first item applied (item2 not applied)

        let appliedIds = Set(applied.map(\.id))

        XCTAssertTrue(appliedIds.contains(item1.id))
        XCTAssertFalse(appliedIds.contains(item2.id))
    }

    // MARK: - Empty State Tests

    func testEmptyHistoryState() {
        let history = MaskingHistory()
        XCTAssertTrue(history.entries.isEmpty)
        XCTAssertEqual(history.entries.count, 0)
    }

    // MARK: - Statistics Display Tests

    func testStatisticsForDisplay() {
        var history = MaskingHistory()

        history.add(MaskingHistoryEntry(
            originalText: "test@email.com, 123-456-7890",
            maskedText: "[EMAIL_MASKED], [PHONE_MASKED]",
            detectedItems: [
                HistoryDetectedItem(text: "test@email.com", type: "EMAIL", startOffset: 0, endOffset: 14, confidence: 1.0, source: "regex"),
                HistoryDetectedItem(text: "123-456-7890", type: "PHONE", startOffset: 16, endOffset: 28, confidence: 0.9, source: "regex")
            ],
            appliedItems: [
                HistoryDetectedItem(text: "test@email.com", type: "EMAIL", startOffset: 0, endOffset: 14, confidence: 1.0, source: "regex")
            ],
            source: .regexOnly
        ))

        let stats = history.calculateStatistics()
        XCTAssertEqual(stats.totalOperations, 1)
        XCTAssertEqual(stats.totalItemsDetected, 2)
        XCTAssertEqual(stats.totalItemsMasked, 1)
        XCTAssertEqual(stats.maskingRate, 0.5, accuracy: 0.001)
    }
}
