import XCTest
@testable import PasteFence

final class MaskingHistoryTests: XCTestCase {

    // MARK: - HistoryDetectedItem Tests

    func testHistoryDetectedItemEncodingDecoding() throws {
        let item = HistoryDetectedItem(
            text: "test@example.com",
            type: "EMAIL",
            startOffset: 10,
            endOffset: 26,
            confidence: 0.95,
            source: "regex"
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(item)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(HistoryDetectedItem.self, from: data)

        XCTAssertEqual(decoded.text, item.text)
        XCTAssertEqual(decoded.type, item.type)
        XCTAssertEqual(decoded.startOffset, item.startOffset)
        XCTAssertEqual(decoded.endOffset, item.endOffset)
        XCTAssertEqual(decoded.confidence, item.confidence)
        XCTAssertEqual(decoded.source, item.source)
    }

    func testHistoryDetectedItemFromDetectedItem() {
        let text = "Contact me at test@example.com for info"
        let range = text.range(of: "test@example.com")!

        let detectedItem = DetectedItem(
            text: "test@example.com",
            type: .email,
            range: range,
            confidence: 0.99,
            source: .regex,
            ruleName: "Email Address"
        )

        let historyItem = HistoryDetectedItem(from: detectedItem, in: text)

        XCTAssertEqual(historyItem.text, "test@example.com")
        XCTAssertEqual(historyItem.type, "EMAIL")
        XCTAssertEqual(historyItem.startOffset, 14)  // "Contact me at " = 14 chars
        XCTAssertEqual(historyItem.endOffset, 30)    // 14 + 16 = 30
        XCTAssertEqual(historyItem.confidence, 0.99)
        XCTAssertEqual(historyItem.source, "regex")
    }

    // MARK: - MaskingHistoryEntry Tests

    func testMaskingHistoryEntryComputedProperties() {
        let detected = [
            HistoryDetectedItem(text: "email@test.com", type: "EMAIL", startOffset: 0, endOffset: 14, confidence: 1.0, source: "regex"),
            HistoryDetectedItem(text: "123-456-7890", type: "PHONE", startOffset: 20, endOffset: 32, confidence: 0.9, source: "regex"),
            HistoryDetectedItem(text: "secret123", type: "PASSWORD", startOffset: 40, endOffset: 49, confidence: 0.8, source: "llm")
        ]

        let applied = [detected[0], detected[1]]  // Only 2 of 3 applied

        let entry = MaskingHistoryEntry(
            originalText: "email@test.com some text 123-456-7890 and secret123",
            maskedText: "[EMAIL_MASKED] some text [PHONE_MASKED] and secret123",
            detectedItems: detected,
            appliedItems: applied,
            source: .hybrid
        )

        XCTAssertEqual(entry.detectedCount, 3)
        XCTAssertEqual(entry.appliedCount, 2)
        XCTAssertEqual(entry.skippedCount, 1)
    }

    func testMaskingHistoryEntryPreview() {
        let shortText = "Short text"
        let longText = String(repeating: "a", count: 150)

        let shortEntry = MaskingHistoryEntry(
            originalText: shortText,
            maskedText: shortText,
            detectedItems: [],
            appliedItems: [],
            source: .regexOnly
        )

        let longEntry = MaskingHistoryEntry(
            originalText: longText,
            maskedText: longText,
            detectedItems: [],
            appliedItems: [],
            source: .regexOnly
        )

        XCTAssertEqual(shortEntry.originalPreview, shortText)
        XCTAssertEqual(longEntry.originalPreview.count, 103)  // 100 + "..."
        XCTAssertTrue(longEntry.originalPreview.hasSuffix("..."))
    }

    func testMaskingHistoryEntryEncodingDecoding() throws {
        let entry = MaskingHistoryEntry(
            originalText: "test@example.com",
            maskedText: "[EMAIL_MASKED]",
            detectedItems: [
                HistoryDetectedItem(text: "test@example.com", type: "EMAIL", startOffset: 0, endOffset: 16, confidence: 1.0, source: "regex")
            ],
            appliedItems: [
                HistoryDetectedItem(text: "test@example.com", type: "EMAIL", startOffset: 0, endOffset: 16, confidence: 1.0, source: "regex")
            ],
            source: .regexOnly
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(entry)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(MaskingHistoryEntry.self, from: data)

        XCTAssertEqual(decoded.id, entry.id)
        XCTAssertEqual(decoded.originalText, entry.originalText)
        XCTAssertEqual(decoded.maskedText, entry.maskedText)
        XCTAssertEqual(decoded.source, entry.source)
        XCTAssertEqual(decoded.detectedItems.count, 1)
        XCTAssertEqual(decoded.appliedItems.count, 1)
    }

    // MARK: - MaskingHistory Collection Tests

    func testMaskingHistoryAddEntry() {
        var history = MaskingHistory(maxEntries: 50)

        let entry = MaskingHistoryEntry(
            originalText: "test",
            maskedText: "test",
            detectedItems: [],
            appliedItems: [],
            source: .regexOnly
        )

        history.add(entry)

        XCTAssertEqual(history.entries.count, 1)
        XCTAssertEqual(history.entries.first?.id, entry.id)
    }

    func testMaskingHistoryNewestFirst() {
        var history = MaskingHistory(maxEntries: 50)

        let entry1 = MaskingHistoryEntry(
            originalText: "first",
            maskedText: "first",
            detectedItems: [],
            appliedItems: [],
            source: .regexOnly
        )

        let entry2 = MaskingHistoryEntry(
            originalText: "second",
            maskedText: "second",
            detectedItems: [],
            appliedItems: [],
            source: .regexOnly
        )

        history.add(entry1)
        history.add(entry2)

        XCTAssertEqual(history.entries.first?.originalText, "second")  // Newest first
        XCTAssertEqual(history.entries.last?.originalText, "first")
    }

    func testMaskingHistoryMaxEntriesEnforced() {
        var history = MaskingHistory(maxEntries: 3)

        for i in 0..<5 {
            let entry = MaskingHistoryEntry(
                originalText: "entry \(i)",
                maskedText: "entry \(i)",
                detectedItems: [],
                appliedItems: [],
                source: .regexOnly
            )
            history.add(entry)
        }

        XCTAssertEqual(history.entries.count, 3)
        XCTAssertEqual(history.entries.first?.originalText, "entry 4")  // Newest
        XCTAssertEqual(history.entries.last?.originalText, "entry 2")   // Oldest kept
    }

    func testMaskingHistoryRemoveEntry() {
        var history = MaskingHistory()

        let entry1 = MaskingHistoryEntry(
            originalText: "keep",
            maskedText: "keep",
            detectedItems: [],
            appliedItems: [],
            source: .regexOnly
        )

        let entry2 = MaskingHistoryEntry(
            originalText: "remove",
            maskedText: "remove",
            detectedItems: [],
            appliedItems: [],
            source: .regexOnly
        )

        history.add(entry1)
        history.add(entry2)
        history.remove(entry2)

        XCTAssertEqual(history.entries.count, 1)
        XCTAssertEqual(history.entries.first?.originalText, "keep")
    }

    func testMaskingHistoryClear() {
        var history = MaskingHistory()

        for i in 0..<3 {
            history.add(MaskingHistoryEntry(
                originalText: "entry \(i)",
                maskedText: "entry \(i)",
                detectedItems: [],
                appliedItems: [],
                source: .regexOnly
            ))
        }

        XCTAssertEqual(history.entries.count, 3)

        history.clear()

        XCTAssertEqual(history.entries.count, 0)
    }

    // MARK: - Filter Tests

    func testMaskingHistoryFilterByType() {
        var history = MaskingHistory()

        let emailEntry = MaskingHistoryEntry(
            originalText: "test@example.com",
            maskedText: "[EMAIL_MASKED]",
            detectedItems: [
                HistoryDetectedItem(text: "test@example.com", type: "EMAIL", startOffset: 0, endOffset: 16, confidence: 1.0, source: "regex")
            ],
            appliedItems: [],
            source: .regexOnly
        )

        let phoneEntry = MaskingHistoryEntry(
            originalText: "123-456-7890",
            maskedText: "[PHONE_MASKED]",
            detectedItems: [
                HistoryDetectedItem(text: "123-456-7890", type: "PHONE", startOffset: 0, endOffset: 12, confidence: 1.0, source: "regex")
            ],
            appliedItems: [],
            source: .regexOnly
        )

        history.add(emailEntry)
        history.add(phoneEntry)

        let emailResults = history.entries(for: .email)
        XCTAssertEqual(emailResults.count, 1)
        XCTAssertEqual(emailResults.first?.originalText, "test@example.com")

        let phoneResults = history.entries(for: .phone)
        XCTAssertEqual(phoneResults.count, 1)
        XCTAssertEqual(phoneResults.first?.originalText, "123-456-7890")

        let creditCardResults = history.entries(for: .creditCard)
        XCTAssertEqual(creditCardResults.count, 0)
    }

    func testMaskingHistoryFilterByDateRange() {
        var history = MaskingHistory()

        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now)!
        let lastWeek = Calendar.current.date(byAdding: .day, value: -7, to: now)!

        let recentEntry = MaskingHistoryEntry(
            timestamp: now,
            originalText: "recent",
            maskedText: "recent",
            detectedItems: [],
            appliedItems: [],
            source: .regexOnly
        )

        let oldEntry = MaskingHistoryEntry(
            timestamp: lastWeek,
            originalText: "old",
            maskedText: "old",
            detectedItems: [],
            appliedItems: [],
            source: .regexOnly
        )

        history.add(recentEntry)
        history.add(oldEntry)

        let recentResults = history.entries(in: yesterday...tomorrow)
        XCTAssertEqual(recentResults.count, 1)
        XCTAssertEqual(recentResults.first?.originalText, "recent")

        let allResults = history.entries(in: lastWeek...tomorrow)
        XCTAssertEqual(allResults.count, 2)
    }

    func testMaskingHistorySearch() {
        var history = MaskingHistory()

        history.add(MaskingHistoryEntry(
            originalText: "Contact: john@example.com",
            maskedText: "Contact: [EMAIL_MASKED]",
            detectedItems: [],
            appliedItems: [],
            source: .regexOnly
        ))

        history.add(MaskingHistoryEntry(
            originalText: "Phone: 555-1234",
            maskedText: "Phone: [PHONE_MASKED]",
            detectedItems: [],
            appliedItems: [],
            source: .regexOnly
        ))

        let emailSearch = history.search(query: "john")
        XCTAssertEqual(emailSearch.count, 1)

        let phoneSearch = history.search(query: "555")
        XCTAssertEqual(phoneSearch.count, 1)

        let noResults = history.search(query: "xyz")
        XCTAssertEqual(noResults.count, 0)

        let emptyQuery = history.search(query: "")
        XCTAssertEqual(emptyQuery.count, 2)  // Returns all
    }

    // MARK: - Statistics Tests

    func testMaskingHistoryStatistics() {
        var history = MaskingHistory()

        // Entry 1: 2 detected, 2 masked
        history.add(MaskingHistoryEntry(
            originalText: "test",
            maskedText: "masked",
            detectedItems: [
                HistoryDetectedItem(text: "email@test.com", type: "EMAIL", startOffset: 0, endOffset: 14, confidence: 1.0, source: "regex"),
                HistoryDetectedItem(text: "123-456-7890", type: "PHONE", startOffset: 20, endOffset: 32, confidence: 1.0, source: "regex")
            ],
            appliedItems: [
                HistoryDetectedItem(text: "email@test.com", type: "EMAIL", startOffset: 0, endOffset: 14, confidence: 1.0, source: "regex"),
                HistoryDetectedItem(text: "123-456-7890", type: "PHONE", startOffset: 20, endOffset: 32, confidence: 1.0, source: "regex")
            ],
            source: .regexOnly
        ))

        // Entry 2: 1 detected, 0 masked (user skipped all)
        history.add(MaskingHistoryEntry(
            originalText: "test2",
            maskedText: "test2",
            detectedItems: [
                HistoryDetectedItem(text: "secret", type: "PASSWORD", startOffset: 0, endOffset: 6, confidence: 0.8, source: "llm")
            ],
            appliedItems: [],
            source: .hybrid
        ))

        let stats = history.calculateStatistics()

        XCTAssertEqual(stats.totalOperations, 2)
        XCTAssertEqual(stats.totalItemsDetected, 3)
        XCTAssertEqual(stats.totalItemsMasked, 2)
        XCTAssertEqual(stats.averageItemsPerOperation, 1.5)
        XCTAssertEqual(stats.typeBreakdown["EMAIL"], 1)
        XCTAssertEqual(stats.typeBreakdown["PHONE"], 1)
        XCTAssertEqual(stats.typeBreakdown["PASSWORD"], 1)
        XCTAssertEqual(stats.maskingRate, 2.0/3.0, accuracy: 0.001)
    }

    func testMaskingHistoryEmptyStatistics() {
        let history = MaskingHistory()
        let stats = history.calculateStatistics()

        XCTAssertEqual(stats.totalOperations, 0)
        XCTAssertEqual(stats.totalItemsDetected, 0)
        XCTAssertEqual(stats.totalItemsMasked, 0)
        XCTAssertEqual(stats.averageItemsPerOperation, 0)
        XCTAssertTrue(stats.typeBreakdown.isEmpty)
        XCTAssertEqual(stats.maskingRate, 0)
    }

    // MARK: - Full History Encoding/Decoding

    func testMaskingHistoryEncodingDecoding() throws {
        var history = MaskingHistory(maxEntries: 10)

        history.add(MaskingHistoryEntry(
            originalText: "test@example.com",
            maskedText: "[EMAIL_MASKED]",
            detectedItems: [
                HistoryDetectedItem(text: "test@example.com", type: "EMAIL", startOffset: 0, endOffset: 16, confidence: 1.0, source: "regex")
            ],
            appliedItems: [
                HistoryDetectedItem(text: "test@example.com", type: "EMAIL", startOffset: 0, endOffset: 16, confidence: 1.0, source: "regex")
            ],
            source: .regexOnly
        ))

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(history)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(MaskingHistory.self, from: data)

        XCTAssertEqual(decoded.entries.count, 1)
        XCTAssertEqual(decoded.maxEntries, 10)
        XCTAssertEqual(decoded.entries.first?.originalText, "test@example.com")
    }
}
