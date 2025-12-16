import XCTest
@testable import PasteFence

/// Tests that verify actor isolation works correctly when called from non-MainActor contexts.
/// These tests simulate production call paths where MaskingEngine.mask() is called
/// from its actor context, not from MainActor.
///
/// Background:
/// - Test classes marked @MainActor run all test code on the main actor
/// - In production, MaskingEngine is an actor, and its mask() method runs in actor isolation
/// - Task.detached creates tasks that run outside MainActor, simulating production
@MainActor
final class ActorIsolationTests: XCTestCase {
    var maskingEngine: MaskingEngine!

    override func setUp() async throws {
        try await super.setUp()
        // Initialize on MainActor (same as production's AppCoordinator init)
        maskingEngine = MaskingEngine()
    }

    // MARK: - Detached Task Tests (Simulates Production Call Path)

    /// Test masking from a detached task (simulates production call path)
    /// This would have caught the EXC_BREAKPOINT crash from MainActor.assumeIsolated
    func testMaskingFromDetachedTask() async throws {
        let result = try await Task.detached { [maskingEngine] in
            // This runs on a background thread, NOT MainActor
            // This is how MaskingEngine.mask() is called in production
            return try await maskingEngine!.mask(text: "Email: test@example.com")
        }.value

        XCTAssertTrue(result.maskedText.contains("[EMAIL_MASKED]"))
        XCTAssertEqual(result.detectedItems.count, 1)
        XCTAssertEqual(result.detectedItems.first?.type, .email)
    }

    /// Test concurrent masking from multiple detached tasks
    func testConcurrentMaskingFromDetachedTasks() async throws {
        let inputs = [
            "Email: user1@example.com",
            "Phone: 555-123-4567",
            "Card: 4111111111111111"
        ]

        let results = try await withThrowingTaskGroup(of: MaskingResult.self) { group in
            for input in inputs {
                group.addTask { [maskingEngine] in
                    // Each task runs detached from MainActor
                    return try await maskingEngine!.mask(text: input)
                }
            }

            var results: [MaskingResult] = []
            for try await result in group {
                results.append(result)
            }
            return results
        }

        XCTAssertEqual(results.count, 3)
        XCTAssertTrue(results.allSatisfy { !$0.detectedItems.isEmpty })
    }

    /// Test that RegexDetector's cached patterns work correctly from any context
    func testRegexDetectorPatternsCachedCorrectly() async throws {
        // Multiple concurrent detached tasks hitting the same patterns
        let tasks = (0..<5).map { i in
            Task.detached { [maskingEngine] () -> Int in
                let result = try await maskingEngine!.mask(text: "Email\(i): user\(i)@test.com")
                return result.detectedItems.count
            }
        }

        for task in tasks {
            let count = try await task.value
            XCTAssertEqual(count, 1, "Each task should detect exactly 1 email")
        }
    }

    /// Test empty input from detached context
    func testEmptyInputFromDetachedTask() async throws {
        let result = try await Task.detached { [maskingEngine] in
            return try await maskingEngine!.mask(text: "")
        }.value

        XCTAssertEqual(result.maskedText, "")
        XCTAssertEqual(result.detectedItems.count, 0)
    }

    /// Test text with no sensitive data from detached context
    func testNoSensitiveDataFromDetachedTask() async throws {
        let result = try await Task.detached { [maskingEngine] in
            return try await maskingEngine!.mask(text: "Hello, this is just normal text.")
        }.value

        XCTAssertEqual(result.maskedText, "Hello, this is just normal text.")
        XCTAssertEqual(result.detectedItems.count, 0)
    }
}
