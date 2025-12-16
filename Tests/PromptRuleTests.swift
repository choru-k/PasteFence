import XCTest
@testable import PasteFence

// MARK: - PromptRule Unit Tests

final class PromptRuleTests: XCTestCase {

    // MARK: - Validation Tests

    func testValidRuleIsValid() {
        let rule = PromptRule(
            name: "Test Rule",
            description: "Test description",
            maskLabel: "TEST"
        )
        XCTAssertTrue(rule.isValid)
    }

    func testEmptyNameIsInvalid() {
        let rule = PromptRule(
            name: "",
            description: "Test description",
            maskLabel: "TEST"
        )
        XCTAssertFalse(rule.isValid)
    }

    func testWhitespaceOnlyNameIsInvalid() {
        let rule = PromptRule(
            name: "   ",
            description: "Test description",
            maskLabel: "TEST"
        )
        XCTAssertFalse(rule.isValid)
    }

    func testEmptyDescriptionIsInvalid() {
        let rule = PromptRule(
            name: "Test Rule",
            description: "",
            maskLabel: "TEST"
        )
        XCTAssertFalse(rule.isValid)
    }

    func testEmptyMaskLabelIsInvalid() {
        let rule = PromptRule(
            name: "Test Rule",
            description: "Test description",
            maskLabel: ""
        )
        XCTAssertFalse(rule.isValid)
    }

    func testWhitespaceOnlyMaskLabelIsInvalid() {
        let rule = PromptRule(
            name: "Test Rule",
            description: "Test description",
            maskLabel: "   "
        )
        XCTAssertFalse(rule.isValid)
    }

    // MARK: - Sensitive Type Generation Tests

    func testCustomRuleSensitiveTypeHasPrefix() {
        let rule = PromptRule(
            name: "Test",
            description: "Test",
            maskLabel: "project",
            isBuiltIn: false
        )
        XCTAssertEqual(rule.sensitiveType, "CUSTOM_PROJECT")
    }

    func testBuiltInRuleSensitiveTypeNoPrefix() {
        let rule = PromptRule(
            name: "Test",
            description: "Test",
            maskLabel: "API_KEY",
            isBuiltIn: true
        )
        XCTAssertEqual(rule.sensitiveType, "API_KEY")
    }

    func testSensitiveTypeUppercases() {
        let rule = PromptRule(
            name: "Test",
            description: "Test",
            maskLabel: "project",
            isBuiltIn: false
        )
        XCTAssertEqual(rule.sensitiveType, "CUSTOM_PROJECT")
    }

    func testSensitiveTypePreservesUppercase() {
        let rule = PromptRule(
            name: "Test",
            description: "Test",
            maskLabel: "API_KEY",
            isBuiltIn: false
        )
        XCTAssertEqual(rule.sensitiveType, "CUSTOM_API_KEY")
    }

    func testSensitiveTypeHandlesMixedCase() {
        let rule = PromptRule(
            name: "Test",
            description: "Test",
            maskLabel: "EmployeeId",
            isBuiltIn: false
        )
        XCTAssertEqual(rule.sensitiveType, "CUSTOM_EMPLOYEEID")
    }

    // MARK: - Default Values Tests

    func testDefaultIsEnabled() {
        let rule = PromptRule(
            name: "Test",
            description: "Test",
            maskLabel: "TEST"
        )
        XCTAssertTrue(rule.isEnabled)
    }

    func testDefaultExamplesEmpty() {
        let rule = PromptRule(
            name: "Test",
            description: "Test",
            maskLabel: "TEST"
        )
        XCTAssertTrue(rule.examples.isEmpty)
    }

    func testDefaultIsBuiltInFalse() {
        let rule = PromptRule(
            name: "Test",
            description: "Test",
            maskLabel: "TEST"
        )
        XCTAssertFalse(rule.isBuiltIn)
    }

    func testDefaultPatternExamplesEmpty() {
        let rule = PromptRule(
            name: "Test",
            description: "Test",
            maskLabel: "TEST"
        )
        XCTAssertTrue(rule.patternExamples.isEmpty)
    }

    func testCreatedAtIsSet() {
        let beforeCreate = Date()
        let rule = PromptRule(
            name: "Test",
            description: "Test",
            maskLabel: "TEST"
        )
        let afterCreate = Date()

        XCTAssertGreaterThanOrEqual(rule.createdAt, beforeCreate)
        XCTAssertLessThanOrEqual(rule.createdAt, afterCreate)
    }

    // MARK: - Built-in Rule Tests

    func testBuiltInRuleWithPatternExamples() {
        let rule = PromptRule(
            name: "API Key",
            description: "API keys from various services",
            patternExamples: "OpenAI: sk-..., GitHub: ghp_...",
            maskLabel: "API_KEY",
            isBuiltIn: true
        )

        XCTAssertTrue(rule.isBuiltIn)
        XCTAssertEqual(rule.patternExamples, "OpenAI: sk-..., GitHub: ghp_...")
        XCTAssertEqual(rule.sensitiveType, "API_KEY")
    }

    // MARK: - Codable Tests

    func testEncodeDecode() throws {
        let original = PromptRule(
            name: "Project Codenames",
            description: "Detect internal project names",
            patternExamples: "",
            examples: ["Phoenix", "Atlas"],
            maskLabel: "PROJECT",
            isBuiltIn: false,
            isEnabled: true
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PromptRule.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.description, original.description)
        XCTAssertEqual(decoded.patternExamples, original.patternExamples)
        XCTAssertEqual(decoded.examples, original.examples)
        XCTAssertEqual(decoded.maskLabel, original.maskLabel)
        XCTAssertEqual(decoded.isBuiltIn, original.isBuiltIn)
        XCTAssertEqual(decoded.isEnabled, original.isEnabled)
    }

    func testEncodeDecodeBuiltIn() throws {
        let original = PromptRule(
            name: "Private Key",
            description: "PEM format private keys",
            patternExamples: "-----BEGIN RSA PRIVATE KEY-----",
            maskLabel: "PRIVATE_KEY",
            isBuiltIn: true,
            isEnabled: true
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PromptRule.self, from: data)

        XCTAssertEqual(decoded.isBuiltIn, true)
        XCTAssertEqual(decoded.patternExamples, "-----BEGIN RSA PRIVATE KEY-----")
    }

    // MARK: - Equatable Tests

    func testDifferentIdsAreNotEqual() {
        let rule1 = PromptRule(
            name: "Rule 1",
            description: "Description 1",
            maskLabel: "LABEL1"
        )
        let rule2 = PromptRule(
            name: "Rule 1",
            description: "Description 1",
            maskLabel: "LABEL1"
        )

        XCTAssertNotEqual(rule1, rule2)  // Different IDs make them not equal
    }

    func testSameRuleIsEqual() {
        let rule = PromptRule(
            name: "Test",
            description: "Test",
            maskLabel: "TEST"
        )
        XCTAssertEqual(rule, rule)
    }
}
