import XCTest
@testable import PasteFence

/// Integration tests for LLM prompt engineering
/// Run with: swift test --filter LLMPromptTests
/// NOTE: Run via Xcode only - MLX requires Metal framework context
final class LLMPromptTests: XCTestCase {

    // MARK: - CLI Detection

    /// Check if running via swift test (CLI mode where Metal isn't properly available)
    private static let isRunningViaCLI: Bool = {
        let processName = ProcessInfo.processInfo.processName
        return processName.contains("xctest") ||
               ProcessInfo.processInfo.arguments.contains(where: { $0.contains("swift-test") }) ||
               ProcessInfo.processInfo.environment["__XCODE_BUILT_PRODUCTS_DIR_PATHS"] == nil
    }()

    override func setUp() async throws {
        try await super.setUp()
        try XCTSkipIf(Self.isRunningViaCLI, "MLX requires Xcode - skipping in CLI mode")
    }

    // MARK: - Test Data

    /// Sample text with various PII types for testing
    static let testText = """
        Contact: john.doe@example.com
        Phone: 010-1234-5678
        API Key: sk-abcdefghij1234567890abcdefghij1234567890abcdef
        Password: secret123
        IP: 192.168.1.100
        """

    /// Expected items that should be detected
    static let expectedItems = [
        "john.doe@example.com",
        "010-1234-5678",
        "sk-abcdefghij1234567890abcdefghij1234567890abcdef",
        "secret123",
        "192.168.1.100"
    ]

    // MARK: - Prompt Variants

    /// Production prompt from LLMDetector (zero-shot with INPUT markers)
    func buildProductionPrompt(for text: String) -> String {
        let systemPrompt = """
            You are a strict PII detector. Output ONLY valid JSON.

            Schema: {"detected": [{"text": string, "type": "PASSWORD"|"API_KEY"|"SECRET"|"EMAIL"|"PHONE"|"IP_ADDRESS"|"CREDIT_CARD"|"PRIVATE_KEY"|"JWT"|"AWS_KEY"}]}

            Rules:
            1. Extract text EXACTLY as it appears between INPUT_START and INPUT_END.
            2. Prioritize: PASSWORD, API_KEY, SECRET (others handled by regex).
            3. If nothing found, output ]}
            4. NO markdown. NO explanations. JSON only.
            5. Do NOT invent data. Only output text that exists in the input.
            """

        let userPrompt = """
            INPUT_START
            \(text)
            INPUT_END

            Analyze text. Return JSON now.
            """

        return """
            <|im_start|>system
            \(systemPrompt)<|im_end|>
            <|im_start|>user
            \(userPrompt)<|im_end|>
            <|im_start|>assistant
            {"detected": [
            """
    }

    /// Legacy prompt (baseline for comparison - known to cause hallucination)
    func buildLegacyPrompt(for text: String) -> String {
        let systemPrompt = """
            You are a PII (Personally Identifiable Information) detector.
            Identify sensitive information and output ONLY valid JSON. No explanations.
            Look for: API keys, passwords, emails, phone numbers, credit cards, SSN, \
            resident registration numbers, personal names in sensitive contexts, \
            addresses, private keys, tokens, database credentials, connection strings.
            """

        let userPrompt = """
            Analyze this text for sensitive information:
            \"\"\"
            \(text)
            \"\"\"

            Output ONLY valid JSON with this exact structure:
            {"detected": [{"text": "the exact text found", "type": "EMAIL", "confidence": 0.95}]}

            Rules:
            - "text" must be the EXACT substring from the input
            - "type" must be one of: EMAIL, PHONE, CREDIT_CARD, API_KEY, JWT, IP_ADDRESS, PASSWORD, PRIVATE_KEY, AWS_KEY, SECRET
            - "confidence" must be a decimal number between 0.0 and 1.0 (e.g., 0.85, 0.92)
            - If nothing found, output: {"detected": []}
            """

        return """
            <|im_start|>system
            \(systemPrompt)/no_think<|im_end|>
            <|im_start|>user
            \(userPrompt)<|im_end|>
            <|im_start|>assistant
            """
    }

    /// Zero-shot prompt - no examples to copy
    func buildZeroShotPrompt(for text: String) -> String {
        """
        <|im_start|>system
        You are a PII detector. Output valid JSON only./no_think<|im_end|>
        <|im_start|>user
        Find all sensitive data in this text:

        \(text)

        Return JSON with format: {"detected": [{"text": "...", "type": "...", "confidence": 0.0-1.0}]}
        - text: the EXACT characters from the input (copy exactly)
        - type: EMAIL, PHONE, API_KEY, PASSWORD, IP_ADDRESS, or SECRET
        - confidence: how confident you are (0.0 to 1.0)

        If no sensitive data found: {"detected": []}
        <|im_end|>
        <|im_start|>assistant
        """
    }

    /// XML-structured prompt with clear boundaries
    func buildXMLPrompt(for text: String) -> String {
        """
        <|im_start|>system
        Extract PII from text. Return JSON only./no_think<|im_end|>
        <|im_start|>user
        <input>
        \(text)
        </input>

        Extract sensitive data and return JSON:
        - "text": copy the EXACT characters from <input>
        - "type": EMAIL|PHONE|API_KEY|PASSWORD|IP_ADDRESS|SECRET
        - "confidence": number between 0.0 and 1.0

        If nothing found: {"detected": []}
        <|im_end|>
        <|im_start|>assistant
        """
    }

    /// Pre-filled assistant response to guide output
    func buildPrefilledPrompt(for text: String) -> String {
        """
        <|im_start|>system
        Extract PII from text. Return JSON only./no_think<|im_end|>
        <|im_start|>user
        <input>
        \(text)
        </input>

        Find sensitive data (emails, phones, API keys, passwords, IPs).
        Return as JSON array with text, type, and confidence.
        <|im_end|>
        <|im_start|>assistant
        {"detected": [
        """
    }

    // MARK: - Test Methods

    /// Test production prompt (zero-shot with INPUT markers and pre-fill)
    func testProductionPrompt() async throws {
        let engine = try await createEngine()
        let prompt = buildProductionPrompt(for: Self.testText)

        print("\n" + String(repeating: "=", count: 60))
        print("TEST: Production Prompt (zero-shot)")
        print(String(repeating: "=", count: 60))
        print("\n--- PROMPT ---")
        print(prompt)
        print("--- END PROMPT ---\n")

        // Production prompt uses pre-fill, parser extracts JSON from output
        let response = try await engine.generate(prompt: prompt, maxTokens: 1024)
        let fullResponse = "{\"detected\": [" + response

        print("--- RAW RESPONSE ---")
        print(fullResponse)
        print("--- END RESPONSE ---\n")

        analyzeResponse(fullResponse, testName: "Production Prompt")
    }

    /// Test legacy prompt to see baseline behavior (known to cause hallucination)
    func testLegacyPrompt() async throws {
        let engine = try await createEngine()
        let prompt = buildLegacyPrompt(for: Self.testText)

        print("\n" + String(repeating: "=", count: 60))
        print("TEST: Legacy Prompt (baseline - may hallucinate)")
        print(String(repeating: "=", count: 60))
        print("\n--- PROMPT ---")
        print(prompt)
        print("--- END PROMPT ---\n")

        let response = try await engine.generate(prompt: prompt, maxTokens: 512)

        print("--- RAW RESPONSE ---")
        print(response)
        print("--- END RESPONSE ---\n")

        analyzeResponse(response, testName: "Legacy Prompt")
    }

    /// Test zero-shot prompt
    func testZeroShotPrompt() async throws {
        let engine = try await createEngine()
        let prompt = buildZeroShotPrompt(for: Self.testText)

        print("\n" + String(repeating: "=", count: 60))
        print("TEST: Zero-Shot Prompt")
        print(String(repeating: "=", count: 60))
        print("\n--- PROMPT ---")
        print(prompt)
        print("--- END PROMPT ---\n")

        let response = try await engine.generate(prompt: prompt, maxTokens: 512)

        print("--- RAW RESPONSE ---")
        print(response)
        print("--- END RESPONSE ---\n")

        analyzeResponse(response, testName: "Zero-Shot")
    }

    /// Test XML-structured prompt
    func testXMLPrompt() async throws {
        let engine = try await createEngine()
        let prompt = buildXMLPrompt(for: Self.testText)

        print("\n" + String(repeating: "=", count: 60))
        print("TEST: XML-Structured Prompt")
        print(String(repeating: "=", count: 60))
        print("\n--- PROMPT ---")
        print(prompt)
        print("--- END PROMPT ---\n")

        let response = try await engine.generate(prompt: prompt, maxTokens: 512)

        print("--- RAW RESPONSE ---")
        print(response)
        print("--- END RESPONSE ---\n")

        analyzeResponse(response, testName: "XML")
    }

    /// Test pre-filled assistant prompt
    func testPrefilledPrompt() async throws {
        let engine = try await createEngine()
        let prompt = buildPrefilledPrompt(for: Self.testText)

        print("\n" + String(repeating: "=", count: 60))
        print("TEST: Pre-filled Assistant Prompt")
        print(String(repeating: "=", count: 60))
        print("\n--- PROMPT ---")
        print(prompt)
        print("--- END PROMPT ---\n")

        // For pre-filled, we need to prepend the partial response
        let response = try await engine.generate(prompt: prompt, maxTokens: 512)
        let fullResponse = "{\"detected\": [" + response

        print("--- RAW RESPONSE ---")
        print(fullResponse)
        print("--- END RESPONSE ---\n")

        analyzeResponse(fullResponse, testName: "Pre-filled")
    }

    // MARK: - Helper Methods

    private func createEngine() async throws -> LLMEngine {
        // Use HuggingFace ID directly since that's what LLMEngine expects
        return try await LLMEngine(huggingFaceId: "Qwen/Qwen3-0.6B-MLX-8bit")
    }

    private func analyzeResponse(_ response: String, testName: String) {
        print("--- ANALYSIS: \(testName) ---")

        // Check for hallucination (copying the example)
        if response.contains("the exact text found") {
            print("❌ HALLUCINATION: Copied example text 'the exact text found'")
        }

        if response.contains("<exact_match>") {
            print("❌ HALLUCINATION: Copied placeholder '<exact_match>'")
        }

        // Check which expected items were found
        var foundCount = 0
        for item in Self.expectedItems {
            if response.contains(item) {
                print("✅ Found: \(item)")
                foundCount += 1
            } else {
                print("❌ Missing: \(item)")
            }
        }

        print("\nScore: \(foundCount)/\(Self.expectedItems.count) items detected")

        // Try to parse JSON
        if let jsonString = extractFirstJSONObject(from: response) {
            print("✅ Valid JSON structure found")
            if let data = jsonString.data(using: .utf8) {
                do {
                    let decoded = try JSONDecoder().decode(LLMResponseTestable.self, from: data)
                    print("✅ JSON decoded successfully: \(decoded.detected.count) items")
                    for item in decoded.detected {
                        print("   - \(item.type): '\(item.text)' (conf: \(item.confidence ?? 0.85))")
                    }
                } catch {
                    print("❌ JSON decode failed: \(error.localizedDescription)")
                }
            }
        } else {
            print("❌ No valid JSON found in response")
        }

        print("--- END ANALYSIS ---\n")
    }

    /// Extract the first complete JSON object from a string by matching braces
    private func extractFirstJSONObject(from text: String) -> String? {
        guard let startIndex = text.firstIndex(of: "{") else { return nil }

        var braceCount = 0
        var inString = false
        var escaped = false

        for (offset, char) in text[startIndex...].enumerated() {
            if escaped {
                escaped = false
                continue
            }

            if char == "\\" && inString {
                escaped = true
                continue
            }

            if char == "\"" {
                inString = !inString
                continue
            }

            if !inString {
                if char == "{" {
                    braceCount += 1
                } else if char == "}" {
                    braceCount -= 1
                    if braceCount == 0 {
                        let endIndex = text.index(startIndex, offsetBy: offset)
                        return String(text[startIndex...endIndex])
                    }
                }
            }
        }

        return nil
    }
}
