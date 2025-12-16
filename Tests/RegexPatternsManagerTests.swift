import XCTest
@testable import PasteFence

// MARK: - RegexPatternsManager Unit Tests

@MainActor
final class RegexPatternsManagerTests: XCTestCase {

    private var manager: RegexPatternsManager!
    private let patternsStorageKey = "com.pastefence.regexPatterns"
    private let hasInitializedKey = "com.pastefence.regexPatternsInitialized"

    override func setUp() async throws {
        try await super.setUp()
        // Clear any existing patterns before each test
        UserDefaults.standard.removeObject(forKey: patternsStorageKey)
        UserDefaults.standard.removeObject(forKey: hasInitializedKey)
        manager = RegexPatternsManager()
    }

    override func tearDown() async throws {
        // Clean up after each test
        UserDefaults.standard.removeObject(forKey: patternsStorageKey)
        UserDefaults.standard.removeObject(forKey: hasInitializedKey)
        manager = nil
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitializesBuiltInPatterns() {
        XCTAssertGreaterThan(manager.patterns.count, 0)
        XCTAssertTrue(manager.patterns.contains { $0.isBuiltIn })
    }

    func testBuiltInPatternsCount() {
        // Manager should have 40 built-in patterns
        let builtInCount = manager.patterns.filter { $0.isBuiltIn }.count
        XCTAssertEqual(builtInCount, 40, "Expected 40 built-in patterns")
    }

    func testAllPatternsEnabledByDefault() {
        let allEnabled = manager.patterns.allSatisfy { $0.isEnabled }
        XCTAssertTrue(allEnabled)
    }

    func testCategoriesHavePatterns() {
        for category in PatternCategory.allCases where category != .custom {
            let count = manager.totalCount(for: category)
            XCTAssertGreaterThan(count, 0, "Category \(category.displayName) should have patterns")
        }
    }

    // MARK: - Toggle Pattern Tests

    func testTogglePattern() {
        guard let pattern = manager.patterns.first else {
            XCTFail("No patterns found")
            return
        }

        XCTAssertTrue(pattern.isEnabled)
        manager.togglePattern(id: pattern.id)

        let updated = manager.patterns.first { $0.id == pattern.id }
        XCTAssertFalse(updated?.isEnabled ?? true)
    }

    func testTogglePatternUpdatesModifiedAt() {
        guard let pattern = manager.patterns.first else {
            XCTFail("No patterns found")
            return
        }

        let originalModifiedAt = pattern.modifiedAt

        // Wait a tiny bit to ensure time difference
        Thread.sleep(forTimeInterval: 0.01)

        manager.togglePattern(id: pattern.id)

        let updated = manager.patterns.first { $0.id == pattern.id }
        XCTAssertGreaterThan(updated!.modifiedAt, originalModifiedAt)
    }

    func testToggleNonexistentPatternDoesNothing() {
        let initialCount = manager.patterns.count
        manager.togglePattern(id: UUID())
        XCTAssertEqual(manager.patterns.count, initialCount)
    }

    // MARK: - Toggle Category Tests

    func testToggleCategory() {
        let category = PatternCategory.pii
        let categoryPatterns = manager.patterns(for: category)

        // All should be enabled initially
        XCTAssertTrue(categoryPatterns.allSatisfy { $0.isEnabled })

        // Toggle off
        manager.toggleCategory(category)

        let updated = manager.patterns(for: category)
        XCTAssertTrue(updated.allSatisfy { !$0.isEnabled })
    }

    func testToggleCategoryTogglesBack() {
        let category = PatternCategory.financial

        // Toggle off
        manager.toggleCategory(category)
        XCTAssertFalse(manager.isCategoryEnabled(category))

        // Toggle on
        manager.toggleCategory(category)
        XCTAssertTrue(manager.isCategoryEnabled(category))
    }

    // MARK: - Custom Pattern CRUD Tests

    func testAddCustomPattern() {
        let custom = RegexPatternConfig.createCustom(
            name: "Test",
            pattern: #"\d+"#,
            maskLabel: "TEST"
        )

        let initialCount = manager.patterns.count
        manager.addCustomPattern(custom)

        XCTAssertEqual(manager.patterns.count, initialCount + 1)
        XCTAssertTrue(manager.customPatterns.contains { $0.name == "Test" })
    }

    func testAddCustomPatternAppearsInCustomCategory() {
        let custom = RegexPatternConfig.createCustom(
            name: "Custom Test",
            pattern: #"\d+"#,
            maskLabel: "TEST"
        )

        manager.addCustomPattern(custom)

        let customPatterns = manager.patterns(for: .custom)
        XCTAssertTrue(customPatterns.contains { $0.name == "Custom Test" })
    }

    func testUpdatePattern() {
        let custom = RegexPatternConfig.createCustom(
            name: "Original",
            pattern: #"\d+"#,
            maskLabel: "ORIGINAL"
        )
        manager.addCustomPattern(custom)

        let updated = RegexPatternConfig(
            id: custom.id,
            name: "Updated",
            pattern: #"\w+"#,
            sensitiveType: "CUSTOM_UPDATED",
            category: .custom,
            isBuiltIn: false,
            isEnabled: true,
            createdAt: custom.createdAt,
            modifiedAt: Date()
        )
        manager.updatePattern(updated)

        let result = manager.patterns.first { $0.id == custom.id }
        XCTAssertEqual(result?.name, "Updated")
        XCTAssertEqual(result?.pattern, #"\w+"#)
    }

    func testDeleteCustomPattern() {
        let custom = RegexPatternConfig.createCustom(
            name: "ToDelete",
            pattern: #"\d+"#,
            maskLabel: "DELETE"
        )
        manager.addCustomPattern(custom)

        let countBefore = manager.patterns.count
        manager.deletePattern(id: custom.id)

        XCTAssertEqual(manager.patterns.count, countBefore - 1)
        XCTAssertFalse(manager.patterns.contains { $0.id == custom.id })
    }

    func testCannotDeleteBuiltInPattern() {
        guard let builtIn = manager.patterns.first(where: { $0.isBuiltIn }) else {
            XCTFail("No built-in patterns found")
            return
        }

        let countBefore = manager.patterns.count
        manager.deletePattern(id: builtIn.id)

        XCTAssertEqual(manager.patterns.count, countBefore)
        XCTAssertTrue(manager.patterns.contains { $0.id == builtIn.id })
    }

    // MARK: - Query Tests

    func testEnabledPatterns() {
        let pattern = manager.patterns[0]
        manager.togglePattern(id: pattern.id)

        let enabled = manager.enabledPatterns
        XCTAssertFalse(enabled.contains { $0.id == pattern.id })
    }

    func testCustomPatternsEmpty() {
        XCTAssertTrue(manager.customPatterns.isEmpty)
    }

    func testCustomPatternsWithAdded() {
        let custom = RegexPatternConfig.createCustom(
            name: "Custom",
            pattern: #"\d+"#,
            maskLabel: "CUSTOM"
        )
        manager.addCustomPattern(custom)

        XCTAssertEqual(manager.customPatterns.count, 1)
        XCTAssertFalse(manager.customPatterns.first!.isBuiltIn)
    }

    func testPatternsForCategory() {
        let piiPatterns = manager.patterns(for: .pii)
        XCTAssertTrue(piiPatterns.allSatisfy { $0.category == .pii })
    }

    func testIsCategoryEnabled() {
        XCTAssertTrue(manager.isCategoryEnabled(.pii))

        // Disable one pattern in category
        if let pattern = manager.patterns(for: .pii).first {
            manager.togglePattern(id: pattern.id)
        }

        XCTAssertFalse(manager.isCategoryEnabled(.pii))
    }

    func testIsCategoryPartiallyEnabled() {
        // Disable one pattern in category
        if let pattern = manager.patterns(for: .pii).first {
            manager.togglePattern(id: pattern.id)
        }

        XCTAssertTrue(manager.isCategoryPartiallyEnabled(.pii))
    }

    func testIsCategoryPartiallyEnabledFalseWhenAllOn() {
        XCTAssertFalse(manager.isCategoryPartiallyEnabled(.pii))
    }

    func testIsCategoryPartiallyEnabledFalseWhenAllOff() {
        // Disable all PII patterns
        manager.toggleCategory(.pii)

        XCTAssertFalse(manager.isCategoryPartiallyEnabled(.pii))
    }

    func testEnabledCountForCategory() {
        let total = manager.totalCount(for: .financial)
        XCTAssertEqual(manager.enabledCount(for: .financial), total)

        // Disable one
        if let pattern = manager.patterns(for: .financial).first {
            manager.togglePattern(id: pattern.id)
        }

        XCTAssertEqual(manager.enabledCount(for: .financial), total - 1)
    }

    func testTotalCountForCategory() {
        // Financial should have 4 patterns
        XCTAssertEqual(manager.totalCount(for: .financial), 4)
    }

    // MARK: - Persistence Tests

    func testPersistenceAcrossInstances() {
        let custom = RegexPatternConfig.createCustom(
            name: "Persist Me",
            pattern: #"\d+"#,
            maskLabel: "PERSIST"
        )
        manager.addCustomPattern(custom)

        // Create a new manager - should load from UserDefaults
        let newManager = RegexPatternsManager()

        XCTAssertTrue(newManager.customPatterns.contains { $0.name == "Persist Me" })
    }

    func testToggleStatePersists() {
        guard let pattern = manager.patterns.first else {
            XCTFail("No patterns")
            return
        }

        manager.togglePattern(id: pattern.id)

        let newManager = RegexPatternsManager()
        let loaded = newManager.patterns.first { $0.id == pattern.id }

        XCTAssertFalse(loaded?.isEnabled ?? true)
    }

    // MARK: - Reset Tests

    func testResetToDefaults() {
        // Make some changes
        let custom = RegexPatternConfig.createCustom(
            name: "Custom",
            pattern: #"\d+"#,
            maskLabel: "CUSTOM"
        )
        manager.addCustomPattern(custom)
        manager.toggleCategory(.pii)

        // Reset
        manager.resetToDefaults()

        // Verify reset
        XCTAssertTrue(manager.customPatterns.isEmpty)
        XCTAssertTrue(manager.isCategoryEnabled(.pii))
        XCTAssertEqual(manager.patterns.filter { $0.isBuiltIn }.count, 40)
    }

    #if DEBUG
    // MARK: - Debug Methods Tests

    func testClearAllPatterns() {
        manager.clearAllPatterns()
        XCTAssertTrue(manager.patterns.isEmpty)
    }

    func testReinitializeBuiltInPatterns() {
        manager.clearAllPatterns()
        manager.reinitializeBuiltInPatterns()

        XCTAssertEqual(manager.patterns.filter { $0.isBuiltIn }.count, 40)
    }
    #endif
}
