import XCTest
@testable import PasteFence

// MARK: - PromptRulesManager Unit Tests

@MainActor
final class PromptRulesManagerTests: XCTestCase {

    private var manager: PromptRulesManager!
    private let testStorageKey = "com.pastefence.promptRules"
    private let testInitializedKey = "com.pastefence.promptRulesInitialized"

    override func setUp() async throws {
        try await super.setUp()
        // Clear any existing rules before each test
        UserDefaults.standard.removeObject(forKey: testStorageKey)
        UserDefaults.standard.removeObject(forKey: testInitializedKey)
        manager = PromptRulesManager()
    }

    override func tearDown() async throws {
        // Clean up after each test
        UserDefaults.standard.removeObject(forKey: testStorageKey)
        UserDefaults.standard.removeObject(forKey: testInitializedKey)
        manager = nil
        try await super.tearDown()
    }

    // MARK: - Built-in Rules Tests

    func testBuiltInRulesInitialized() {
        // Manager should have 10 built-in rules after initialization
        XCTAssertEqual(manager.builtInRules.count, 10)
    }

    func testBuiltInRulesAreEnabled() {
        // All built-in rules should be enabled by default
        for rule in manager.builtInRules {
            XCTAssertTrue(rule.isEnabled, "Built-in rule '\(rule.name)' should be enabled")
        }
    }

    func testBuiltInRulesMarkedAsBuiltIn() {
        for rule in manager.builtInRules {
            XCTAssertTrue(rule.isBuiltIn, "Rule '\(rule.name)' should be marked as built-in")
        }
    }

    func testBuiltInRulesHavePatternExamples() {
        for rule in manager.builtInRules {
            XCTAssertFalse(rule.patternExamples.isEmpty, "Built-in rule '\(rule.name)' should have pattern examples")
        }
    }

    func testExpectedBuiltInRuleNames() {
        let expectedNames = [
            "Private Key", "API Key", "AWS Key", "Password", "JWT Token",
            "Secret", "Email", "Phone", "IP Address", "Credit Card"
        ]

        let actualNames = manager.builtInRules.map { $0.name }

        for name in expectedNames {
            XCTAssertTrue(actualNames.contains(name), "Missing built-in rule: \(name)")
        }
    }

    // MARK: - Add Custom Rule Tests

    func testAddCustomRule() {
        let rule = PromptRule(
            name: "Test Rule",
            description: "Test description",
            maskLabel: "TEST",
            isBuiltIn: false
        )

        manager.addRule(rule)

        XCTAssertEqual(manager.customRules.count, 1)
        XCTAssertEqual(manager.customRules.first?.name, "Test Rule")
    }

    func testAddMultipleCustomRules() {
        let rule1 = PromptRule(name: "Rule 1", description: "Desc 1", maskLabel: "TEST1")
        let rule2 = PromptRule(name: "Rule 2", description: "Desc 2", maskLabel: "TEST2")

        manager.addRule(rule1)
        manager.addRule(rule2)

        XCTAssertEqual(manager.customRules.count, 2)
    }

    // MARK: - Update Rule Tests

    func testUpdateCustomRule() {
        var rule = PromptRule(
            name: "Original Name",
            description: "Original description",
            maskLabel: "ORIGINAL"
        )
        manager.addRule(rule)

        rule.name = "Updated Name"
        manager.updateRule(rule)

        XCTAssertEqual(manager.customRules.first?.name, "Updated Name")
    }

    func testUpdateRuleUpdatesModifiedAt() {
        let rule = PromptRule(
            name: "Test",
            description: "Test",
            maskLabel: "TEST"
        )
        manager.addRule(rule)

        let originalModifiedAt = manager.customRules.first!.modifiedAt

        // Wait a tiny bit to ensure time difference
        Thread.sleep(forTimeInterval: 0.01)

        var updatedRule = rule
        updatedRule.name = "Updated"
        manager.updateRule(updatedRule)

        XCTAssertGreaterThan(manager.customRules.first!.modifiedAt, originalModifiedAt)
    }

    // MARK: - Delete Rule Tests

    func testDeleteCustomRule() {
        let rule = PromptRule(name: "To Delete", description: "Desc", maskLabel: "TEST")
        manager.addRule(rule)

        manager.deleteRule(id: rule.id)

        XCTAssertTrue(manager.customRules.isEmpty)
    }

    func testCannotDeleteBuiltInRule() {
        // Get a built-in rule
        let builtInRule = manager.builtInRules.first!
        let initialCount = manager.builtInRules.count

        // Try to delete it
        manager.deleteRule(id: builtInRule.id)

        // Should still have same number of built-in rules
        XCTAssertEqual(manager.builtInRules.count, initialCount)
    }

    // MARK: - Toggle Rule Tests

    func testToggleBuiltInRuleDisables() {
        let builtInRule = manager.builtInRules.first!
        XCTAssertTrue(builtInRule.isEnabled)

        manager.toggleRule(id: builtInRule.id)

        let updatedRule = manager.rules.first { $0.id == builtInRule.id }!
        XCTAssertFalse(updatedRule.isEnabled)
    }

    func testToggleBuiltInRuleEnables() {
        let builtInRule = manager.builtInRules.first!

        // Disable first
        manager.toggleRule(id: builtInRule.id)
        // Enable again
        manager.toggleRule(id: builtInRule.id)

        let updatedRule = manager.rules.first { $0.id == builtInRule.id }!
        XCTAssertTrue(updatedRule.isEnabled)
    }

    func testToggleCustomRuleDisables() {
        let rule = PromptRule(
            name: "Test",
            description: "Test",
            maskLabel: "TEST",
            isEnabled: true
        )
        manager.addRule(rule)

        manager.toggleRule(id: rule.id)

        XCTAssertFalse(manager.customRules.first!.isEnabled)
    }

    // MARK: - Move Rules Tests

    func testMoveRules() {
        let rule1 = PromptRule(name: "First", description: "Desc", maskLabel: "TEST1")
        let rule2 = PromptRule(name: "Second", description: "Desc", maskLabel: "TEST2")
        let rule3 = PromptRule(name: "Third", description: "Desc", maskLabel: "TEST3")

        manager.addRule(rule1)
        manager.addRule(rule2)
        manager.addRule(rule3)

        let totalRules = manager.rules.count
        // Move last to second position
        manager.moveRules(from: IndexSet(integer: totalRules - 1), to: totalRules - 2)

        // Verify the order changed
        XCTAssertEqual(manager.rules.count, totalRules)
    }

    // MARK: - Build Prompt Instructions Tests

    func testBuildPromptInstructionsWithBuiltInRules() {
        let instructions = manager.buildPromptInstructions()

        XCTAssertNotNil(instructions)
        XCTAssertTrue(instructions!.contains("Pattern Examples:"))
        XCTAssertTrue(instructions!.contains("PRIVATE_KEY"))
        XCTAssertTrue(instructions!.contains("API_KEY"))
    }

    func testBuildPromptInstructionsWithDisabledBuiltIn() {
        // Disable all built-in rules
        for rule in manager.builtInRules {
            manager.toggleRule(id: rule.id)
        }

        XCTAssertNil(manager.buildPromptInstructions())
    }

    func testBuildPromptInstructionsWithCustomRule() {
        let rule = PromptRule(
            name: "Project Codenames",
            description: "Detect project names",
            examples: ["Phoenix", "Atlas"],
            maskLabel: "PROJECT",
            isEnabled: true
        )
        manager.addRule(rule)

        let instructions = manager.buildPromptInstructions()

        XCTAssertNotNil(instructions)
        XCTAssertTrue(instructions!.contains("ADDITIONAL DETECTION RULES:"))
        XCTAssertTrue(instructions!.contains("Project Codenames"))
        XCTAssertTrue(instructions!.contains("Detect project names"))
        XCTAssertTrue(instructions!.contains("Phoenix, Atlas"))
    }

    func testBuildPromptInstructionsExcludesDisabledCustom() {
        let rule = PromptRule(
            name: "Disabled Rule",
            description: "Should not appear",
            maskLabel: "DISABLED",
            isEnabled: false
        )
        manager.addRule(rule)

        let instructions = manager.buildPromptInstructions()

        XCTAssertNotNil(instructions)  // Still has built-in rules
        XCTAssertFalse(instructions!.contains("Disabled Rule"))
    }

    // MARK: - Enabled Types Tests

    func testEnabledTypesIncludesBuiltIn() {
        let types = manager.enabledTypes

        XCTAssertTrue(types.contains("PRIVATE_KEY"))
        XCTAssertTrue(types.contains("API_KEY"))
        XCTAssertTrue(types.contains("EMAIL"))
    }

    func testEnabledTypesIncludesCustom() {
        let rule = PromptRule(
            name: "Test",
            description: "Test",
            maskLabel: "PROJECT",
            isEnabled: true
        )
        manager.addRule(rule)

        let types = manager.enabledTypes

        XCTAssertTrue(types.contains("CUSTOM_PROJECT"))
    }

    func testEnabledTypesExcludesDisabled() {
        // Disable one built-in rule
        let builtInRule = manager.builtInRules.first!
        manager.toggleRule(id: builtInRule.id)

        let types = manager.enabledTypes

        XCTAssertFalse(types.contains(builtInRule.maskLabel))
    }

    // MARK: - Query Methods Tests

    func testEnabledRulesProperty() {
        // Disable one built-in rule
        let builtInRule = manager.builtInRules.first!
        manager.toggleRule(id: builtInRule.id)

        // All enabled rules should have isEnabled = true
        for rule in manager.enabledRules {
            XCTAssertTrue(rule.isEnabled)
        }

        XCTAssertEqual(manager.enabledRules.count, manager.rules.count - 1)
    }

    func testBuiltInRulesProperty() {
        XCTAssertEqual(manager.builtInRules.count, 10)

        for rule in manager.builtInRules {
            XCTAssertTrue(rule.isBuiltIn)
        }
    }

    func testCustomRulesPropertyEmpty() {
        XCTAssertTrue(manager.customRules.isEmpty)
    }

    func testCustomRulesPropertyWithRules() {
        let rule = PromptRule(name: "Custom", description: "Desc", maskLabel: "TEST")
        manager.addRule(rule)

        XCTAssertEqual(manager.customRules.count, 1)

        for rule in manager.customRules {
            XCTAssertFalse(rule.isBuiltIn)
        }
    }

    // MARK: - Persistence Tests

    func testPersistenceAcrossInstances() {
        let rule = PromptRule(
            name: "Persist Me",
            description: "Test persistence",
            maskLabel: "PERSIST"
        )
        manager.addRule(rule)

        // Create a new manager - should load from UserDefaults
        let newManager = PromptRulesManager()

        XCTAssertEqual(newManager.customRules.count, 1)
        XCTAssertEqual(newManager.customRules.first?.name, "Persist Me")
    }

    func testBuiltInRulesPersistedWithToggle() {
        // Disable a built-in rule
        let builtInRule = manager.builtInRules.first!
        manager.toggleRule(id: builtInRule.id)

        // Create new manager
        let newManager = PromptRulesManager()

        // Find the same rule by name
        let persistedRule = newManager.builtInRules.first { $0.name == builtInRule.name }!
        XCTAssertFalse(persistedRule.isEnabled)
    }

    // MARK: - Reset to Defaults Tests

    func testResetToDefaults() {
        // Make some changes
        manager.toggleRule(id: manager.builtInRules.first!.id)
        manager.addRule(PromptRule(name: "Custom", description: "Desc", maskLabel: "TEST"))

        // Reset
        manager.resetToDefaults()

        // Should have 10 built-in rules, all enabled, no custom rules
        XCTAssertEqual(manager.builtInRules.count, 10)
        XCTAssertTrue(manager.customRules.isEmpty)

        for rule in manager.builtInRules {
            XCTAssertTrue(rule.isEnabled)
        }
    }

    #if DEBUG
    // MARK: - Debug Methods Tests

    func testClearAllRules() {
        manager.addRule(PromptRule(name: "Rule 1", description: "Desc", maskLabel: "TEST1"))
        manager.addRule(PromptRule(name: "Rule 2", description: "Desc", maskLabel: "TEST2"))

        manager.clearAllRules()

        XCTAssertTrue(manager.rules.isEmpty)
    }

    func testAddSampleRules() {
        manager.addSampleRules()

        XCTAssertEqual(manager.customRules.count, 2)
        XCTAssertTrue(manager.customRules.contains { $0.name == "Project Codenames" })
        XCTAssertTrue(manager.customRules.contains { $0.name == "Employee IDs" })
    }
    #endif
}
