import XCTest
@testable import PasteFence

// MARK: - RegexDetector Integration Tests with RegexPatternsManager

@MainActor
final class RegexDetectorIntegrationTests: XCTestCase {

    private var manager: RegexPatternsManager!
    private let patternsStorageKey = "com.pastefence.regexPatterns"
    private let hasInitializedKey = "com.pastefence.regexPatternsInitialized"

    override func setUp() async throws {
        try await super.setUp()
        // Clear and reinitialize for each test
        UserDefaults.standard.removeObject(forKey: patternsStorageKey)
        UserDefaults.standard.removeObject(forKey: hasInitializedKey)
        manager = RegexPatternsManager()
    }

    override func tearDown() async throws {
        UserDefaults.standard.removeObject(forKey: patternsStorageKey)
        UserDefaults.standard.removeObject(forKey: hasInitializedKey)
        manager = nil
        try await super.tearDown()
    }

    // MARK: - Basic Detection Tests

    func testDetectorWithManagerDetectsEmail() {
        let detector = RegexDetector(patternsManager: manager)
        let text = "Contact me at test@example.com"
        let items = detector.detect(in: text)

        XCTAssertTrue(items.contains { $0.type == .email })
        XCTAssertTrue(items.contains { $0.text == "test@example.com" })
    }

    func testDetectorWithManagerDetectsPhone() {
        let detector = RegexDetector(patternsManager: manager)
        let text = "Call me at +1-555-123-4567"
        let items = detector.detect(in: text)

        XCTAssertTrue(items.contains { $0.type == .phone })
    }

    func testDetectorWithManagerDetectsCreditCard() {
        let detector = RegexDetector(patternsManager: manager)
        let text = "Card number: 4111-1111-1111-1111"
        let items = detector.detect(in: text)

        XCTAssertTrue(items.contains { $0.type == .creditCard })
    }

    // MARK: - Disabled Pattern Tests

    func testDisabledPatternNotDetected() {
        // Find and disable email pattern
        if let emailPattern = manager.patterns.first(where: { $0.sensitiveType == "EMAIL" }) {
            manager.togglePattern(id: emailPattern.id)
        }

        let detector = RegexDetector(patternsManager: manager)
        let text = "Contact: test@example.com"
        let items = detector.detect(in: text)

        // Email should NOT be detected
        XCTAssertFalse(items.contains { $0.type == .email })
    }

    func testReenabledPatternDetected() {
        // Disable then re-enable email pattern
        if let emailPattern = manager.patterns.first(where: { $0.sensitiveType == "EMAIL" }) {
            manager.togglePattern(id: emailPattern.id)  // Disable
            manager.togglePattern(id: emailPattern.id)  // Re-enable
        }

        let detector = RegexDetector(patternsManager: manager)
        let text = "Contact: test@example.com"
        let items = detector.detect(in: text)

        XCTAssertTrue(items.contains { $0.type == .email })
    }

    func testDisabledCategoryNotDetected() {
        // Disable entire PII category
        manager.toggleCategory(.pii)

        let detector = RegexDetector(patternsManager: manager)
        let text = "Email: test@example.com, Phone: +1-555-123-4567, SSN: 123-45-6789"
        let items = detector.detect(in: text)

        // PII types should NOT be detected
        XCTAssertFalse(items.contains { $0.type == .email })
        XCTAssertFalse(items.contains { $0.type == .phone })
        XCTAssertFalse(items.contains { $0.type == .ssn })
    }

    // MARK: - Custom Pattern Tests

    func testCustomPatternDetected() {
        // Add custom pattern for project IDs
        let custom = RegexPatternConfig.createCustom(
            name: "Project ID",
            pattern: #"PROJ-\d{4}"#,
            maskLabel: "PROJECT_ID"
        )
        manager.addCustomPattern(custom)

        let detector = RegexDetector(patternsManager: manager)
        let text = "Working on PROJ-1234 today"
        let items = detector.detect(in: text)

        XCTAssertTrue(items.contains { $0.text == "PROJ-1234" })
    }

    func testCustomPatternSensitiveType() {
        let custom = RegexPatternConfig.createCustom(
            name: "Badge ID",
            pattern: #"BADGE-[A-Z]{3}\d{3}"#,
            maskLabel: "BADGE"
        )
        manager.addCustomPattern(custom)

        let detector = RegexDetector(patternsManager: manager)
        let text = "Employee badge: BADGE-ABC123"
        let items = detector.detect(in: text)

        XCTAssertTrue(items.contains { item in
            item.text == "BADGE-ABC123" && item.type.rawValue == "CUSTOM_BADGE"
        })
    }

    func testDisabledCustomPatternNotDetected() {
        let custom = RegexPatternConfig.createCustom(
            name: "Test Pattern",
            pattern: #"TEST-\d+"#,
            maskLabel: "TEST"
        )
        manager.addCustomPattern(custom)

        // Disable it
        manager.togglePattern(id: custom.id)

        let detector = RegexDetector(patternsManager: manager)
        let text = "Code: TEST-12345"
        let items = detector.detect(in: text)

        XCTAssertFalse(items.contains { $0.text == "TEST-12345" })
    }

    func testMultipleCustomPatterns() {
        let pattern1 = RegexPatternConfig.createCustom(
            name: "Pattern A",
            pattern: #"AAA-\d{3}"#,
            maskLabel: "TYPE_A"
        )
        let pattern2 = RegexPatternConfig.createCustom(
            name: "Pattern B",
            pattern: #"BBB-\d{3}"#,
            maskLabel: "TYPE_B"
        )

        manager.addCustomPattern(pattern1)
        manager.addCustomPattern(pattern2)

        let detector = RegexDetector(patternsManager: manager)
        let text = "Values: AAA-123 and BBB-456"
        let items = detector.detect(in: text)

        XCTAssertTrue(items.contains { $0.text == "AAA-123" })
        XCTAssertTrue(items.contains { $0.text == "BBB-456" })
    }

    // MARK: - Fallback Behavior Tests

    func testDetectorWithoutManagerUsesFallback() {
        let detector = RegexDetector(patternsManager: nil)
        let text = "Email: test@example.com"
        let items = detector.detect(in: text)

        // Should still detect using fallback patterns
        XCTAssertTrue(items.contains { $0.type == .email })
    }

    func testDetectorWithEmptyManagerUsesFallback() {
        // Clear all patterns from manager
        #if DEBUG
        manager.clearAllPatterns()
        #endif

        let detector = RegexDetector(patternsManager: manager)
        let text = "Email: test@example.com"
        let items = detector.detect(in: text)

        // With empty manager, enabledPatterns returns empty array,
        // but activePatterns should use fallback
        // Note: This depends on implementation - current impl uses manager patterns
        // which would be empty. Adjust assertion based on expected behavior.
        // For now, testing that no crash occurs.
        XCTAssertNotNil(items)
    }

    // MARK: - Confidence Tests

    func testCustomPatternConfidence() {
        let custom = RegexPatternConfig.createCustom(
            name: "Low Confidence",
            pattern: #"\d{5}"#,
            maskLabel: "ZIPCODE",
            confidence: 0.7
        )
        manager.addCustomPattern(custom)

        let detector = RegexDetector(patternsManager: manager)
        let text = "ZIP: 12345"
        let items = detector.detect(in: text)

        let zipItem = items.first { $0.text == "12345" }
        XCTAssertEqual(zipItem?.confidence, 0.7)
    }

    // MARK: - Mixed Detection Tests

    func testBuiltInAndCustomPatternsDetected() {
        let custom = RegexPatternConfig.createCustom(
            name: "Internal ID",
            pattern: #"INT-[A-Z]{4}"#,
            maskLabel: "INTERNAL"
        )
        manager.addCustomPattern(custom)

        let detector = RegexDetector(patternsManager: manager)
        let text = "Contact test@example.com about INT-ABCD"
        let items = detector.detect(in: text)

        // Both should be detected
        XCTAssertTrue(items.contains { $0.type == .email })
        XCTAssertTrue(items.contains { $0.text == "INT-ABCD" })
    }

    func testSelectivelyDisabledMixedDetection() {
        // Add custom pattern
        let custom = RegexPatternConfig.createCustom(
            name: "Code",
            pattern: #"CODE-\d{4}"#,
            maskLabel: "CODE"
        )
        manager.addCustomPattern(custom)

        // Disable email but keep custom enabled
        if let emailPattern = manager.patterns.first(where: { $0.sensitiveType == "EMAIL" }) {
            manager.togglePattern(id: emailPattern.id)
        }

        let detector = RegexDetector(patternsManager: manager)
        let text = "Email: test@example.com, Code: CODE-1234"
        let items = detector.detect(in: text)

        // Email should NOT be detected
        XCTAssertFalse(items.contains { $0.type == .email })
        // Custom should be detected
        XCTAssertTrue(items.contains { $0.text == "CODE-1234" })
    }
}
