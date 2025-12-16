import XCTest
@testable import PasteFence

final class HistoryStorageTests: XCTestCase {

    // MARK: - Setup/Teardown

    override func setUp() async throws {
        // Clean up any existing test data
        try? HistoryStorage.deleteStorage()
    }

    override func tearDown() async throws {
        // Clean up after tests
        try? HistoryStorage.deleteStorage()
    }

    // MARK: - HistoryStorage Tests

    func testStorageURLPointsToApplicationSupport() {
        let url = HistoryStorage.storageURL
        XCTAssertTrue(url.path.contains("PasteFence"))
        XCTAssertTrue(url.lastPathComponent == "history.json")
    }

    func testSaveAndLoadRoundtrip() throws {
        var history = MaskingHistory(maxEntries: 10)

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

        history.add(entry)

        // Save
        try HistoryStorage.save(history)
        XCTAssertTrue(HistoryStorage.exists)

        // Load
        let loaded = HistoryStorage.load()
        XCTAssertEqual(loaded.entries.count, 1)
        XCTAssertEqual(loaded.maxEntries, 10)
        XCTAssertEqual(loaded.entries.first?.originalText, "test@example.com")
        XCTAssertEqual(loaded.entries.first?.maskedText, "[EMAIL_MASKED]")
    }

    func testLoadReturnsEmptyHistoryWhenFileDoesNotExist() {
        // Ensure file doesn't exist
        try? HistoryStorage.deleteStorage()
        XCTAssertFalse(HistoryStorage.exists)

        let history = HistoryStorage.load()
        XCTAssertTrue(history.entries.isEmpty)
        XCTAssertEqual(history.maxEntries, 50)  // Default
    }

    func testLoadReturnsEmptyHistoryForCorruptedFile() throws {
        // Write corrupted data
        let corruptedData = "{ invalid json }".data(using: .utf8)!
        try corruptedData.write(to: HistoryStorage.storageURL, options: [.atomic])

        let history = HistoryStorage.load()
        XCTAssertTrue(history.entries.isEmpty)
    }

    func testAtomicWriteCreatesValidFile() throws {
        var history = MaskingHistory()

        for i in 0..<10 {
            history.add(MaskingHistoryEntry(
                originalText: "entry \(i)",
                maskedText: "masked \(i)",
                detectedItems: [],
                appliedItems: [],
                source: .regexOnly
            ))
        }

        try HistoryStorage.save(history)

        // Read raw data and verify it's valid JSON
        let data = try Data(contentsOf: HistoryStorage.storageURL)
        let json = try JSONSerialization.jsonObject(with: data)
        XCTAssertNotNil(json)
    }

    func testLargeHistoryPerformance() throws {
        var history = MaskingHistory(maxEntries: 100)

        // Create 50 entries with realistic data
        for i in 0..<50 {
            let detected = [
                HistoryDetectedItem(text: "email\(i)@test.com", type: "EMAIL", startOffset: 0, endOffset: 20, confidence: 1.0, source: "regex"),
                HistoryDetectedItem(text: "123-456-\(String(format: "%04d", i))", type: "PHONE", startOffset: 25, endOffset: 37, confidence: 0.9, source: "regex")
            ]

            history.add(MaskingHistoryEntry(
                originalText: String(repeating: "a", count: 500),  // Realistic text size
                maskedText: String(repeating: "b", count: 500),
                detectedItems: detected,
                appliedItems: detected,
                source: .hybrid
            ))
        }

        // Measure save time
        let saveStart = CFAbsoluteTimeGetCurrent()
        try HistoryStorage.save(history)
        let saveTime = CFAbsoluteTimeGetCurrent() - saveStart

        // Measure load time
        let loadStart = CFAbsoluteTimeGetCurrent()
        let loaded = HistoryStorage.load()
        let loadTime = CFAbsoluteTimeGetCurrent() - loadStart

        XCTAssertEqual(loaded.entries.count, 50)

        // Performance assertions (generous limits for CI)
        XCTAssertLessThan(saveTime, 1.0, "Save took \(saveTime)s, expected < 1s")
        XCTAssertLessThan(loadTime, 1.0, "Load took \(loadTime)s, expected < 1s")
    }

    func testDeleteStorage() throws {
        var history = MaskingHistory()
        history.add(MaskingHistoryEntry(
            originalText: "test",
            maskedText: "test",
            detectedItems: [],
            appliedItems: [],
            source: .regexOnly
        ))

        try HistoryStorage.save(history)
        XCTAssertTrue(HistoryStorage.exists)

        try HistoryStorage.deleteStorage()
        XCTAssertFalse(HistoryStorage.exists)
    }

    func testDateEncodingIsISO8601() throws {
        var history = MaskingHistory()
        let specificDate = Date(timeIntervalSince1970: 1700000000)  // 2023-11-14

        history.add(MaskingHistoryEntry(
            timestamp: specificDate,
            originalText: "test",
            maskedText: "test",
            detectedItems: [],
            appliedItems: [],
            source: .regexOnly
        ))

        try HistoryStorage.save(history)

        // Read raw JSON and check date format
        let data = try Data(contentsOf: HistoryStorage.storageURL)
        let jsonString = String(data: data, encoding: .utf8)!

        // ISO8601 format should contain the date
        XCTAssertTrue(jsonString.contains("2023-11-14"), "Expected ISO8601 date format")
    }

    // MARK: - HistoryManager Tests

    @MainActor
    func testHistoryManagerAddEntry() async {
        let manager = HistoryManager(history: MaskingHistory())

        let text = "Contact: test@example.com"
        let range = text.range(of: "test@example.com")!

        let detected = DetectedItem(
            text: "test@example.com",
            type: .email,
            range: range,
            confidence: 1.0,
            source: .regex,
            ruleName: "Email Address"
        )

        manager.addEntry(
            original: text,
            masked: "Contact: [EMAIL_MASKED]",
            detected: [detected],
            applied: [detected],
            source: .regexOnly
        )

        XCTAssertEqual(manager.history.entries.count, 1)
        XCTAssertEqual(manager.history.entries.first?.originalText, text)
    }

    @MainActor
    func testHistoryManagerRemoveEntry() async {
        var initialHistory = MaskingHistory()
        let entry = MaskingHistoryEntry(
            originalText: "test",
            maskedText: "test",
            detectedItems: [],
            appliedItems: [],
            source: .regexOnly
        )
        initialHistory.add(entry)

        let manager = HistoryManager(history: initialHistory)
        XCTAssertEqual(manager.history.entries.count, 1)

        manager.removeEntry(entry)
        XCTAssertEqual(manager.history.entries.count, 0)
    }

    @MainActor
    func testHistoryManagerClearHistory() async {
        var initialHistory = MaskingHistory()
        for i in 0..<5 {
            initialHistory.add(MaskingHistoryEntry(
                originalText: "entry \(i)",
                maskedText: "masked \(i)",
                detectedItems: [],
                appliedItems: [],
                source: .regexOnly
            ))
        }

        let manager = HistoryManager(history: initialHistory)
        XCTAssertEqual(manager.history.entries.count, 5)

        manager.clearHistory()
        XCTAssertEqual(manager.history.entries.count, 0)
    }

    @MainActor
    func testHistoryManagerExport() async throws {
        var initialHistory = MaskingHistory()
        initialHistory.add(MaskingHistoryEntry(
            originalText: "test@example.com",
            maskedText: "[EMAIL_MASKED]",
            detectedItems: [
                HistoryDetectedItem(text: "test@example.com", type: "EMAIL", startOffset: 0, endOffset: 16, confidence: 1.0, source: "regex")
            ],
            appliedItems: [],
            source: .regexOnly
        ))

        let manager = HistoryManager(history: initialHistory)
        let exportURL = try manager.exportHistory()

        // Verify export file exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: exportURL.path))

        // Verify it's valid JSON and can be decoded
        let data = try Data(contentsOf: exportURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let history = try decoder.decode(MaskingHistory.self, from: data)
        XCTAssertEqual(history.entries.count, 1)

        // Clean up
        try? FileManager.default.removeItem(at: exportURL)
    }

    @MainActor
    func testHistoryManagerStatistics() async {
        var initialHistory = MaskingHistory()
        initialHistory.add(MaskingHistoryEntry(
            originalText: "test",
            maskedText: "masked",
            detectedItems: [
                HistoryDetectedItem(text: "email@test.com", type: "EMAIL", startOffset: 0, endOffset: 14, confidence: 1.0, source: "regex"),
                HistoryDetectedItem(text: "123-456-7890", type: "PHONE", startOffset: 20, endOffset: 32, confidence: 1.0, source: "regex")
            ],
            appliedItems: [
                HistoryDetectedItem(text: "email@test.com", type: "EMAIL", startOffset: 0, endOffset: 14, confidence: 1.0, source: "regex")
            ],
            source: .regexOnly
        ))

        let manager = HistoryManager(history: initialHistory)
        let stats = manager.statistics

        XCTAssertEqual(stats.totalOperations, 1)
        XCTAssertEqual(stats.totalItemsDetected, 2)
        XCTAssertEqual(stats.totalItemsMasked, 1)
        XCTAssertEqual(stats.maskingRate, 0.5, accuracy: 0.001)
    }

    @MainActor
    func testHistoryManagerQueryMethods() async {
        var initialHistory = MaskingHistory()

        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!

        initialHistory.add(MaskingHistoryEntry(
            timestamp: now,
            originalText: "email@today.com",
            maskedText: "[EMAIL_MASKED]",
            detectedItems: [
                HistoryDetectedItem(text: "email@today.com", type: "EMAIL", startOffset: 0, endOffset: 15, confidence: 1.0, source: "regex")
            ],
            appliedItems: [],
            source: .regexOnly
        ))

        initialHistory.add(MaskingHistoryEntry(
            timestamp: yesterday,
            originalText: "123-456-7890",
            maskedText: "[PHONE_MASKED]",
            detectedItems: [
                HistoryDetectedItem(text: "123-456-7890", type: "PHONE", startOffset: 0, endOffset: 12, confidence: 1.0, source: "regex")
            ],
            appliedItems: [],
            source: .regexOnly
        ))

        let manager = HistoryManager(history: initialHistory)

        // Test entries(for:)
        let emailEntries = manager.entries(for: .email)
        XCTAssertEqual(emailEntries.count, 1)

        // Test search
        let searchResults = manager.search(query: "today")
        XCTAssertEqual(searchResults.count, 1)

        // Test entries(in:) - last hour
        let lastHour = Calendar.current.date(byAdding: .hour, value: -1, to: now)!
        let recentEntries = manager.entries(in: lastHour...now)
        XCTAssertEqual(recentEntries.count, 1)
    }

    @MainActor
    func testAutoSaveSetupAndTeardown() async {
        let manager = HistoryManager(history: MaskingHistory())

        // Setup should not crash
        manager.setupAutoSave()

        // Teardown should not crash
        manager.teardownAutoSave()
    }
}
