import XCTest
@testable import PasteFence

// MARK: - RegexPatternConfig Unit Tests

final class RegexPatternConfigTests: XCTestCase {

    // MARK: - Regex Validation Tests

    func testValidRegex() {
        let config = RegexPatternConfig(
            name: "Test",
            pattern: #"\d{4}-\d{4}"#,
            sensitiveType: "TEST",
            category: .custom
        )
        XCTAssertTrue(config.isValidRegex)
        XCTAssertNotNil(config.compiledRegex())
    }

    func testInvalidRegex() {
        let config = RegexPatternConfig(
            name: "Test",
            pattern: "[invalid(",
            sensitiveType: "TEST",
            category: .custom
        )
        XCTAssertFalse(config.isValidRegex)
        XCTAssertNil(config.compiledRegex())
    }

    func testEmptyPatternIsInvalid() {
        let config = RegexPatternConfig(
            name: "Empty",
            pattern: "",
            sensitiveType: "TEST",
            category: .custom
        )
        XCTAssertFalse(config.isValidRegex)
        XCTAssertNil(config.compiledRegex())
    }

    func testComplexValidRegex() {
        let config = RegexPatternConfig(
            name: "Email",
            pattern: #"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"#,
            sensitiveType: "EMAIL",
            category: .pii
        )
        XCTAssertTrue(config.isValidRegex)
        XCTAssertNotNil(config.compiledRegex())
    }

    // MARK: - Factory Method Tests

    func testCreateCustomPattern() {
        let config = RegexPatternConfig.createCustom(
            name: "Project ID",
            pattern: #"PROJ-\d{4}"#,
            maskLabel: "PROJECT_ID"
        )

        XCTAssertEqual(config.name, "Project ID")
        XCTAssertEqual(config.pattern, #"PROJ-\d{4}"#)
        XCTAssertEqual(config.sensitiveType, "CUSTOM_PROJECT_ID")
        XCTAssertEqual(config.category, .custom)
        XCTAssertFalse(config.isBuiltIn)
        XCTAssertTrue(config.isEnabled)
        XCTAssertEqual(config.confidence, 1.0)
    }

    func testCreateCustomPatternWithConfidence() {
        let config = RegexPatternConfig.createCustom(
            name: "Low Confidence Pattern",
            pattern: #"\d+"#,
            maskLabel: "NUMBER",
            confidence: 0.7
        )

        XCTAssertEqual(config.confidence, 0.7)
    }

    func testCreateCustomPatternUppercasesMaskLabel() {
        let config = RegexPatternConfig.createCustom(
            name: "Test",
            pattern: #"\d+"#,
            maskLabel: "lowercase_label"
        )

        XCTAssertEqual(config.sensitiveType, "CUSTOM_LOWERCASE_LABEL")
    }

    // MARK: - Codable Tests

    func testCodableRoundTrip() throws {
        let original = RegexPatternConfig(
            name: "Test Pattern",
            pattern: #"\d+"#,
            sensitiveType: "TEST",
            category: .pii,
            confidence: 0.9,
            isBuiltIn: true,
            isEnabled: false
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RegexPatternConfig.self, from: encoded)

        XCTAssertEqual(original.id, decoded.id)
        XCTAssertEqual(original.name, decoded.name)
        XCTAssertEqual(original.pattern, decoded.pattern)
        XCTAssertEqual(original.sensitiveType, decoded.sensitiveType)
        XCTAssertEqual(original.category, decoded.category)
        XCTAssertEqual(original.confidence, decoded.confidence)
        XCTAssertEqual(original.isBuiltIn, decoded.isBuiltIn)
        XCTAssertEqual(original.isEnabled, decoded.isEnabled)
    }

    func testCodablePreservesDates() throws {
        let now = Date()
        let original = RegexPatternConfig(
            name: "Test",
            pattern: #"\d+"#,
            sensitiveType: "TEST",
            category: .custom,
            createdAt: now,
            modifiedAt: now
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RegexPatternConfig.self, from: encoded)

        // Compare with some tolerance for JSON encoding
        XCTAssertEqual(original.createdAt.timeIntervalSince1970, decoded.createdAt.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(original.modifiedAt.timeIntervalSince1970, decoded.modifiedAt.timeIntervalSince1970, accuracy: 0.001)
    }

    // MARK: - Equatable Tests

    func testEquality() {
        let id = UUID()
        let date = Date()

        let config1 = RegexPatternConfig(
            id: id,
            name: "Test",
            pattern: #"\d+"#,
            sensitiveType: "TEST",
            category: .custom,
            confidence: 1.0,
            isBuiltIn: false,
            isEnabled: true,
            createdAt: date,
            modifiedAt: date
        )

        let config2 = RegexPatternConfig(
            id: id,
            name: "Test",
            pattern: #"\d+"#,
            sensitiveType: "TEST",
            category: .custom,
            confidence: 1.0,
            isBuiltIn: false,
            isEnabled: true,
            createdAt: date,
            modifiedAt: date
        )

        XCTAssertEqual(config1, config2)
    }

    func testInequalityDifferentId() {
        let config1 = RegexPatternConfig(
            name: "Test",
            pattern: #"\d+"#,
            sensitiveType: "TEST",
            category: .custom
        )

        let config2 = RegexPatternConfig(
            name: "Test",
            pattern: #"\d+"#,
            sensitiveType: "TEST",
            category: .custom
        )

        XCTAssertNotEqual(config1, config2)
    }

    // MARK: - PatternCategory Tests

    func testPatternCategoryDisplayNames() {
        XCTAssertEqual(PatternCategory.pii.displayName, "Personal Information")
        XCTAssertEqual(PatternCategory.financial.displayName, "Financial")
        XCTAssertEqual(PatternCategory.auth.displayName, "Authentication")
        XCTAssertEqual(PatternCategory.cloudApi.displayName, "Cloud & API Keys")
        XCTAssertEqual(PatternCategory.infrastructure.displayName, "Infrastructure")
        XCTAssertEqual(PatternCategory.custom.displayName, "Custom Patterns")
    }

    func testPatternCategoryIconNames() {
        XCTAssertEqual(PatternCategory.pii.iconName, "person.fill")
        XCTAssertEqual(PatternCategory.financial.iconName, "creditcard.fill")
        XCTAssertEqual(PatternCategory.auth.iconName, "key.fill")
        XCTAssertEqual(PatternCategory.cloudApi.iconName, "cloud.fill")
        XCTAssertEqual(PatternCategory.infrastructure.iconName, "server.rack")
        XCTAssertEqual(PatternCategory.custom.iconName, "plus.square.fill")
    }

    func testPatternCategoryIdentifiable() {
        XCTAssertEqual(PatternCategory.pii.id, "PII")
        XCTAssertEqual(PatternCategory.custom.id, "Custom")
    }

    func testPatternCategoryCaseIterable() {
        XCTAssertEqual(PatternCategory.allCases.count, 6)
        XCTAssertTrue(PatternCategory.allCases.contains(.pii))
        XCTAssertTrue(PatternCategory.allCases.contains(.custom))
    }

    // MARK: - CategoryToggleState Tests

    func testCategoryToggleStateDefaults() {
        let state = CategoryToggleState()
        XCTAssertTrue(state.isEnabled)
    }

    func testCategoryToggleStateCodable() throws {
        let original = CategoryToggleState(isEnabled: false)

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CategoryToggleState.self, from: encoded)

        XCTAssertEqual(original, decoded)
    }
}
