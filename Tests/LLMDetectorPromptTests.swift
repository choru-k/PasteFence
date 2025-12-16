import XCTest
@testable import PasteFence

// MARK: - Prompt Building Tests
// Tests for LLMDetectorTestHelper prompt building methods

final class LLMDetectorPromptBuildingTests: XCTestCase {

    func testBuildPromptContainsQwen3Format() {
        let prompt = LLMDetectorTestHelper.buildPrompt(for: "test input")

        XCTAssertTrue(prompt.contains("<|im_start|>system"))
        XCTAssertTrue(prompt.contains("<|im_end|>"))
        XCTAssertTrue(prompt.contains("<|im_start|>user"))
        XCTAssertTrue(prompt.contains("<|im_start|>assistant"))
    }

    func testBuildPromptContainsInputMarkers() {
        let prompt = LLMDetectorTestHelper.buildPrompt(for: "test input")

        // Uses INPUT_START/INPUT_END markers (not XML tags)
        XCTAssertTrue(prompt.contains("INPUT_START"))
        XCTAssertTrue(prompt.contains("INPUT_END"))
        XCTAssertTrue(prompt.contains("test input"))
    }

    func testBuildPromptContainsSchemaAndTypes() {
        let prompt = LLMDetectorTestHelper.buildPrompt(for: "test")

        // Check for schema with types
        XCTAssertTrue(prompt.contains("Schema:"))
        XCTAssertTrue(prompt.contains("detected"))

        // Check for type definitions in schema
        XCTAssertTrue(prompt.contains("EMAIL"))
        XCTAssertTrue(prompt.contains("API_KEY"))
        XCTAssertTrue(prompt.contains("IP_ADDRESS"))
        XCTAssertTrue(prompt.contains("PRIVATE_KEY"))
        XCTAssertTrue(prompt.contains("PASSWORD"))
        XCTAssertTrue(prompt.contains("SECRET"))
    }

    func testBuildPromptPrefilledJSONStart() {
        let prompt = LLMDetectorTestHelper.buildPrompt(for: "test")

        // Should end with pre-filled JSON start to guide model output
        XCTAssertTrue(prompt.contains("{\"detected\": ["))
    }

    func testUserPromptContainsInputMarkers() {
        let userPrompt = LLMDetectorTestHelper.createUserPrompt(for: "test")

        // Uses INPUT_START/INPUT_END markers
        XCTAssertTrue(userPrompt.contains("INPUT_START"))
        XCTAssertTrue(userPrompt.contains("INPUT_END"))
    }

    func testFormatForQwen3Structure() {
        let formatted = LLMDetectorTestHelper.formatForQwen3(system: "System message", user: "User message")

        // Verify proper structure
        XCTAssertTrue(formatted.contains("<|im_start|>system"))
        XCTAssertTrue(formatted.contains("System message"))
        XCTAssertTrue(formatted.contains("<|im_start|>user"))
        XCTAssertTrue(formatted.contains("User message"))
        XCTAssertTrue(formatted.contains("<|im_start|>assistant"))
    }

    func testUserPromptIncludesInputText() {
        let testText = "Contact: admin@example.com"
        let userPrompt = LLMDetectorTestHelper.createUserPrompt(for: testText)

        XCTAssertTrue(userPrompt.contains(testText))
        XCTAssertTrue(userPrompt.contains("INPUT_START"))
        XCTAssertTrue(userPrompt.contains("INPUT_END"))
    }

    func testUserPromptIncludesInstructions() {
        let userPrompt = LLMDetectorTestHelper.createUserPrompt(for: "test")

        // Current format uses concise instructions
        XCTAssertTrue(userPrompt.contains("Analyze text"))
        XCTAssertTrue(userPrompt.contains("Return JSON"))
    }

    func testSystemPromptContainsRules() {
        let prompt = LLMDetectorTestHelper.buildPrompt(for: "test")

        // Check for rules in system prompt
        XCTAssertTrue(prompt.contains("Rules:"))
        XCTAssertTrue(prompt.contains("EXACTLY"))
        XCTAssertTrue(prompt.contains("JSON"))
    }
}
