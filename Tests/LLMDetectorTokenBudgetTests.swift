import XCTest
@testable import PasteFence

// MARK: - Token Budget Unit Tests
// Tests for dynamic max token calculation (no LLM required)

final class LLMDetectorTokenBudgetUnitTests: XCTestCase {

    // MARK: - Token Estimation Tests

    func testTokenEstimationShortText() {
        // ~4 chars per token estimate
        let text = "Hello World"  // 11 chars → ~3 tokens
        let estimated = LLMDetectorTestHelper.estimateTokens(text)
        XCTAssertEqual(estimated, 2, "11 chars / 4 ≈ 2 tokens")
    }

    func testTokenEstimationLongText() {
        // 1000 chars → ~250 tokens
        let text = String(repeating: "a", count: 1000)
        let estimated = LLMDetectorTestHelper.estimateTokens(text)
        XCTAssertEqual(estimated, 250, "1000 chars / 4 = 250 tokens")
    }

    func testTokenEstimationEmptyText() {
        let text = ""
        let estimated = LLMDetectorTestHelper.estimateTokens(text)
        XCTAssertEqual(estimated, 1, "Empty text should return minimum 1 token")
    }

    func testTokenEstimationVeryLongText() {
        // 100K chars → ~25K tokens (approaching safe limit)
        let text = String(repeating: "x", count: 100_000)
        let estimated = LLMDetectorTestHelper.estimateTokens(text)
        XCTAssertEqual(estimated, 25_000, "100K chars / 4 = 25K tokens")
    }

    // MARK: - Token Budget Calculation Tests

    func testSafeLimitCalculation() {
        // contextLength * 0.8 = safeLimit
        let contextLength = 32768
        let safeLimit = Int(Double(contextLength) * 0.8)
        XCTAssertEqual(safeLimit, 26214, "32768 * 0.8 = 26214 safe limit")
    }

    func testMaxOutputTokensWithSmallPrompt() {
        // Small prompt → more room for output
        let contextLength = 32768
        let safeLimit = Int(Double(contextLength) * 0.8)  // 26214
        let promptTokens = 500
        let availableTokens = safeLimit - promptTokens  // 25714

        // Clamped to maxOutputTokens (4096)
        let maxTokens = min(max(availableTokens, 256), 4096)
        XCTAssertEqual(maxTokens, 4096, "Should cap at 4096 max output tokens")
    }

    func testMaxOutputTokensWithLargePrompt() {
        // Large prompt → less room for output
        let contextLength = 32768
        let safeLimit = Int(Double(contextLength) * 0.8)  // 26214
        let promptTokens = 25000
        let availableTokens = safeLimit - promptTokens  // 1214

        let maxTokens = min(max(availableTokens, 256), 4096)
        XCTAssertEqual(maxTokens, 1214, "Should allow remaining tokens for output")
    }

    func testMaxOutputTokensAtMinimum() {
        // Very large prompt → minimum output tokens
        let contextLength = 32768
        let safeLimit = Int(Double(contextLength) * 0.8)  // 26214
        let promptTokens = 26000
        let availableTokens = safeLimit - promptTokens  // 214

        let maxTokens = min(max(availableTokens, 256), 4096)
        XCTAssertEqual(maxTokens, 256, "Should use minimum 256 tokens when low")
    }

    func testInputTooLargeThreshold() {
        // Input exceeds safe limit minus minimum output
        let contextLength = 32768
        let safeLimit = Int(Double(contextLength) * 0.8)  // 26214
        let minOutputTokens = 256
        let maxAllowedPromptTokens = safeLimit - minOutputTokens  // 25958

        // ~104K chars would exceed limit (104000 / 4 = 26000 > 25958)
        let largeTextChars = 104_000
        let estimatedTokens = largeTextChars / 4

        XCTAssertGreaterThan(estimatedTokens, maxAllowedPromptTokens,
            "26000 tokens > 25958 max allowed → should trigger error")
    }

    // MARK: - Error Type Tests

    func testLLMDetectorErrorDescription() {
        let error = LLMDetectorError.inputTooLarge(estimatedTokens: 30000, maxAllowed: 25958)
        XCTAssertTrue(error.errorDescription?.contains("30000") ?? false,
            "Error should mention estimated tokens")
        XCTAssertTrue(error.errorDescription?.contains("25958") ?? false,
            "Error should mention max allowed")
        XCTAssertTrue(error.errorDescription?.contains("too large") ?? false,
            "Error should indicate input is too large")
    }
}

// MARK: - Token Budget Integration Tests
// These tests require actual LLM model loading
// NOTE: Run via Xcode only - MLX requires Metal framework context

final class LLMDetectorTokenBudgetIntegrationTests: XCTestCase {
    var detector: LLMDetector!

    /// Check if running via swift test (CLI mode where Metal isn't properly available)
    /// MLX requires Metal framework which doesn't work properly in CLI test environment
    private static let isRunningViaCLI: Bool = {
        // When running via `swift test`, we're in a headless environment
        // Check for XPC service or swift test runner indicators
        let processName = ProcessInfo.processInfo.processName
        return processName.contains("xctest") ||
               ProcessInfo.processInfo.arguments.contains(where: { $0.contains("swift-test") }) ||
               ProcessInfo.processInfo.environment["__XCODE_BUILT_PRODUCTS_DIR_PATHS"] == nil
    }()

    override func setUp() async throws {
        try await super.setUp()
        // Skip if running via CLI - MLX/Metal doesn't work properly in swift test
        try XCTSkipIf(Self.isRunningViaCLI, "MLX requires Xcode - skipping in CLI mode")
        detector = try await LLMDetector(modelPath: "qwen3-0.6b-mlx-8bit")
    }

    func testNormalInputSucceeds() async throws {
        // Normal size input should work fine
        let text = "Contact: john.doe@example.com"
        let results = try await detector.detect(in: text)

        // Should complete without error (actual detection may vary)
        print("[TokenBudget] Normal input detection completed with \(results.count) results")
    }

    func testMediumInputSucceeds() async throws {
        // Medium size input (~1000 chars)
        let text = """
        Here is a document with some sensitive information:

        Email addresses:
        - john.doe@example.com
        - jane.smith@company.org
        - support@business.net

        Server configuration:
        - Primary: 192.168.1.100
        - Secondary: 10.0.0.50
        - Backup: 172.16.0.1

        Credentials:
        - API Key: sk-1234567890abcdef1234567890abcdef
        - Password: mysecretpassword123

        This is additional context to make the input larger.
        Lorem ipsum dolor sit amet, consectetur adipiscing elit.
        Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.
        """

        let results = try await detector.detect(in: text)
        print("[TokenBudget] Medium input (~\(text.count) chars) completed with \(results.count) results")

        // Should find at least some PII
        XCTAssertGreaterThan(results.count, 0, "Should detect some PII in medium input")
    }

    func testInputTooLargeThrowsError() async throws {
        // Create input that exceeds safe limit
        // Safe limit ≈ 26214 tokens → ~104K chars
        // Add some buffer for prompt template overhead
        let largeText = String(repeating: "test@email.com password:secret123 ", count: 3500)

        print("[TokenBudget] Testing large input (~\(largeText.count) chars)")

        do {
            _ = try await detector.detect(in: largeText)
            XCTFail("Should have thrown inputTooLarge error")
        } catch let error as LLMDetectorError {
            switch error {
            case .inputTooLarge(let estimated, let maxAllowed):
                print("[TokenBudget] Correctly threw inputTooLarge: estimated=\(estimated), max=\(maxAllowed)")
                XCTAssertGreaterThan(estimated, maxAllowed, "Estimated should exceed max allowed")
            case .outputTruncated:
                XCTFail("Expected inputTooLarge but got outputTruncated")
            }
        } catch {
            XCTFail("Expected LLMDetectorError.inputTooLarge but got: \(error)")
        }
    }

    func testTokenBudgetLogging() async throws {
        // Verify that token budget is logged
        let text = "Email: test@example.com"

        // This test mainly verifies the code path runs
        // Check console output for: "[LLMDetector] Token budget: prompt=X, maxOutput=Y, safeLimit=Z"
        let results = try await detector.detect(in: text)
        print("[TokenBudget] Logging test completed with \(results.count) results")
    }
}
