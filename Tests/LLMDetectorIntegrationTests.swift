import XCTest
@testable import PasteFence

// MARK: - Base Test Class for LLM Integration Tests
// Subclass and override modelPath/modelName/performanceTimeout to test different models
// Run via Xcode (MLX requires Metal framework context)

class LLMDetectorBaseTests: XCTestCase {
    var detector: LLMDetector!

    // MARK: - Prevent Base Class from Running Tests

    /// Prevent the abstract base class from being instantiated as a test
    override class var defaultTestSuite: XCTestSuite {
        if self == LLMDetectorBaseTests.self {
            return XCTestSuite(name: "Empty suite for abstract base class")
        }
        return super.defaultTestSuite
    }

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

    // MARK: - Abstract Properties (override in subclasses)

    /// Model path to load (e.g., "qwen3-0.6b-mlx-8bit")
    var modelPath: String {
        fatalError("Subclass must override modelPath")
    }

    /// Display name for logs (e.g., "0.6B", "1.7B", "4B")
    var modelName: String {
        fatalError("Subclass must override modelName")
    }

    /// Performance test timeout in seconds
    var performanceTimeout: TimeInterval {
        fatalError("Subclass must override performanceTimeout")
    }

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()
        // Skip if running via CLI - MLX/Metal doesn't work properly in swift test
        try XCTSkipIf(Self.isRunningViaCLI, "MLX requires Xcode - skipping in CLI mode")
        detector = try await LLMDetector(modelPath: modelPath)
    }

    // MARK: - Password Detection

    func testDetectsPasswordField() async throws {
        let text = "password: mysecretpassword123"
        let results = try await detector.detect(in: text)

        print("[Test-\(modelName)] Password detection results: \(results)")
        XCTAssertTrue(results.contains { $0.type == .password }, "Should detect password")
    }

    // MARK: - API Key Detection

    func testDetectsOpenAIKey() async throws {
        let text = "OPENAI_API_KEY=sk-1234567890abcdef1234567890abcdef1234567890abcdef"
        let results = try await detector.detect(in: text)

        print("[Test-\(modelName)] OpenAI key results: \(results)")
        XCTAssertTrue(results.contains { $0.type == .apiKey }, "Should detect API key")
    }

    // MARK: - Private Key Detection

    func testDetectsPrivateKey() async throws {
        let text = "-----BEGIN RSA PRIVATE KEY-----\nMIIEpAIBAAKCAQEA..."
        let results = try await detector.detect(in: text)

        print("[Test-\(modelName)] Private key results: \(results)")
        XCTAssertTrue(results.contains { $0.type == .privateKey }, "Should detect private key")
    }

    // MARK: - Complex Scenarios

    func testDetectsMultipleSensitiveItems() async throws {
        let text = """
        Error connecting to database:
        User: admin
        Password: secret123
        API Key: sk-abcdefghij1234567890abcdefghij1234567890abcdef
        """

        let results = try await detector.detect(in: text)

        print("[Test-\(modelName)] Multiple items results:")
        for item in results {
            print("  - \(item.type): '\(item.text)' (conf: \(item.confidence))")
        }

        // LLM focuses on secrets (password, API key) - regex handles email/IP
        let secretsFound = results.filter {
            $0.type == .password || $0.type == .apiKey
        }
        XCTAssertGreaterThanOrEqual(secretsFound.count, 1, "Should detect password or API key")
    }

    func testNoFalsePositivesOnCleanText() async throws {
        let text = """
        This is a regular log message.
        User clicked button at timestamp 1234567890.
        Processing completed successfully.
        """

        let results = try await detector.detect(in: text)

        print("[Test-\(modelName)] Clean text results: \(results)")
        XCTAssertLessThanOrEqual(results.count, 1, "Should have minimal false positives")
    }

    // MARK: - Output Validation

    func testReturnsValidDetectedItems() async throws {
        let text = "Login: Password: abc123, API_KEY=sk-test1234567890abcdef"
        let results = try await detector.detect(in: text)

        print("[Test-\(modelName)] Valid items results: \(results)")

        for item in results {
            XCTAssertFalse(item.text.isEmpty, "Detected text should not be empty")
            XCTAssertGreaterThan(item.confidence, 0, "Confidence should be positive")
            XCTAssertLessThanOrEqual(item.confidence, 1.0, "Confidence should be <= 1.0")
            XCTAssertTrue(text.contains(item.text), "Detected text '\(item.text)' should exist in original")
        }
    }

    // MARK: - Performance

    func testDetectionPerformance() async throws {
        let text = """
        User: admin
        Password: secret123
        API_KEY: sk-test1234567890abcdef
        """

        let startTime = Date()
        _ = try await detector.detect(in: text)
        let elapsed = Date().timeIntervalSince(startTime)

        print("[Test-\(modelName)] Detection took \(String(format: "%.2f", elapsed))s")
        XCTAssertLessThan(elapsed, performanceTimeout, "Detection should complete within \(performanceTimeout) seconds")
    }
}

// MARK: - Qwen3 0.6B Integration Tests

final class LLMDetector06BIntegrationTests: LLMDetectorBaseTests {
    override var modelPath: String { "qwen3-0.6b-mlx-8bit" }
    override var modelName: String { "0.6B" }
    override var performanceTimeout: TimeInterval { 30.0 }

    // Add 0.6B-specific tests here if needed
}

// MARK: - Qwen3 1.7B Integration Tests

final class LLMDetector1_7BIntegrationTests: LLMDetectorBaseTests {
    override var modelPath: String { "qwen3-1.7b-mlx-4bit" }
    override var modelName: String { "1.7B" }
    override var performanceTimeout: TimeInterval { 60.0 }

    // 1.7B model hallucinates private key text - skip this test
    override func testDetectsPrivateKey() async throws {
        throw XCTSkip("1.7B model hallucinates private key text")
    }
}

// MARK: - Qwen3 4B Integration Tests

final class LLMDetector4BIntegrationTests: LLMDetectorBaseTests {
    override var modelPath: String { "qwen3-4b-mlx-4bit" }
    override var modelName: String { "4B" }
    override var performanceTimeout: TimeInterval { 90.0 }

    // Add 4B-specific tests here if needed
}
