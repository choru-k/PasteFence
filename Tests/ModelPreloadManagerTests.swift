import XCTest
@testable import PasteFence

/// Tests for ModelPreloadManager state machine and state transitions
/// These tests prevent regression of the "Model not loaded" bug where
/// initializeLLMIfAvailable() bypassed PreloadManager state updates.
@MainActor
final class ModelPreloadManagerTests: XCTestCase {

    // MARK: - Setup/Teardown

    override func setUp() async throws {
        try await super.setUp()
        // Ensure clean state before each test
        ModelPreloadManager.shared.invalidate()
    }

    override func tearDown() async throws {
        // Cleanup after each test
        ModelPreloadManager.shared.invalidate()
        try await super.tearDown()
    }

    // MARK: - Initial State Tests

    func testInitialStateIsIdle() {
        let manager = ModelPreloadManager.shared
        manager.invalidate() // Ensure clean state
        XCTAssertEqual(manager.state, .idle, "Initial state should be idle")
    }

    func testInitialProgressIsZero() {
        let manager = ModelPreloadManager.shared
        manager.invalidate()
        XCTAssertEqual(manager.progress, 0.0, "Initial progress should be 0")
    }

    // MARK: - State Transition Tests

    func testStartPreloadingWithNoModelStaysIdle() {
        let manager = ModelPreloadManager.shared

        // When no model is available, should stay idle
        if ModelManager.shared.activeModel == nil {
            manager.startPreloading(delay: 0)
            XCTAssertEqual(manager.state, .idle,
                "Should stay idle when no model available")
        }
    }

    func testStartPreloadingTransitionsToWaiting() {
        let manager = ModelPreloadManager.shared

        // Precondition: Need an active downloaded model
        guard ModelManager.shared.activeModel != nil,
              ModelManager.shared.downloadedModels.count > 0 else {
            // Skip if no model - this is expected in CI environment
            return
        }

        // Use long delay to catch the waiting state
        manager.startPreloading(delay: 100.0)
        XCTAssertEqual(manager.state, .waiting,
            "Should transition to waiting when preloading starts")

        // Cleanup
        manager.invalidate()
    }

    func testInvalidateResetsToIdle() {
        let manager = ModelPreloadManager.shared

        // Start preloading (will stay waiting if model exists)
        manager.startPreloading(delay: 100.0)

        // Invalidate should reset to idle
        manager.invalidate()

        XCTAssertEqual(manager.state, .idle,
            "invalidate() should reset state to idle")
        XCTAssertEqual(manager.progress, 0.0,
            "invalidate() should reset progress to 0")
    }

    func testMultipleStartPreloadingCancelsFirst() {
        let manager = ModelPreloadManager.shared

        guard ModelManager.shared.activeModel != nil,
              ModelManager.shared.downloadedModels.count > 0 else {
            return
        }

        // Start first preload
        manager.startPreloading(delay: 100.0)
        let firstState = manager.state

        // Start second preload (should cancel first)
        manager.startPreloading(delay: 100.0)
        let secondState = manager.state

        // Both should be waiting (second call doesn't fail)
        XCTAssertEqual(firstState, .waiting)
        XCTAssertEqual(secondState, .waiting)

        manager.invalidate()
    }

    // MARK: - Status Text Tests

    func testStatusTextForIdleState() {
        let manager = ModelPreloadManager.shared
        manager.invalidate()
        XCTAssertEqual(manager.statusText, "Model not loaded",
            "Idle state should show 'Model not loaded'")
    }

    func testStatusTextForWaitingState() {
        let manager = ModelPreloadManager.shared

        guard ModelManager.shared.activeModel != nil,
              ModelManager.shared.downloadedModels.count > 0 else {
            return
        }

        manager.startPreloading(delay: 100.0)
        XCTAssertEqual(manager.statusText, "Preparing to load...",
            "Waiting state should show 'Preparing to load...'")

        manager.invalidate()
    }

    // MARK: - Status Symbol Tests

    func testStatusSymbolForIdleState() {
        let manager = ModelPreloadManager.shared
        manager.invalidate()
        XCTAssertEqual(manager.statusSymbol, "circle",
            "Idle state should show circle symbol")
    }

    func testStatusSymbolForWaitingState() {
        let manager = ModelPreloadManager.shared

        guard ModelManager.shared.activeModel != nil,
              ModelManager.shared.downloadedModels.count > 0 else {
            return
        }

        manager.startPreloading(delay: 100.0)
        XCTAssertEqual(manager.statusSymbol, "arrow.clockwise",
            "Waiting state should show arrow.clockwise symbol")

        manager.invalidate()
    }

    // MARK: - isReady Tests

    func testIsReadyFalseWhenIdle() {
        let manager = ModelPreloadManager.shared
        manager.invalidate()
        XCTAssertFalse(manager.isReady,
            "isReady should be false when idle")
    }

    func testIsReadyFalseWhenWaiting() {
        let manager = ModelPreloadManager.shared

        guard ModelManager.shared.activeModel != nil,
              ModelManager.shared.downloadedModels.count > 0 else {
            return
        }

        manager.startPreloading(delay: 100.0)
        XCTAssertFalse(manager.isReady,
            "isReady should be false when waiting")

        manager.invalidate()
    }

    // MARK: - PreloadState Equality Tests

    func testPreloadStateEquality() {
        XCTAssertEqual(
            ModelPreloadManager.PreloadState.idle,
            ModelPreloadManager.PreloadState.idle
        )
        XCTAssertEqual(
            ModelPreloadManager.PreloadState.waiting,
            ModelPreloadManager.PreloadState.waiting
        )
        XCTAssertEqual(
            ModelPreloadManager.PreloadState.preloading,
            ModelPreloadManager.PreloadState.preloading
        )
        XCTAssertEqual(
            ModelPreloadManager.PreloadState.ready,
            ModelPreloadManager.PreloadState.ready
        )
        XCTAssertEqual(
            ModelPreloadManager.PreloadState.failed("error"),
            ModelPreloadManager.PreloadState.failed("error")
        )
    }

    func testPreloadStateInequality() {
        XCTAssertNotEqual(
            ModelPreloadManager.PreloadState.idle,
            ModelPreloadManager.PreloadState.waiting
        )
        XCTAssertNotEqual(
            ModelPreloadManager.PreloadState.ready,
            ModelPreloadManager.PreloadState.failed("error")
        )
        XCTAssertNotEqual(
            ModelPreloadManager.PreloadState.failed("error1"),
            ModelPreloadManager.PreloadState.failed("error2")
        )
    }

    // MARK: - Regression Test: initializeLLMIfAvailable() must update state
    // This is the critical test that would have caught the original bug

    func testInitializeLLMIfAvailableTriggerPreloading() async {
        // This test verifies that initializeLLMIfAvailable() properly triggers
        // the PreloadManager, which was the root cause of the "Model not loaded" bug.

        guard ModelManager.shared.downloadedModels.count > 0,
              ModelManager.shared.activeModel != nil else {
            // No model available - can't test this scenario
            // This is expected in CI without downloaded models
            return
        }

        let manager = ModelPreloadManager.shared
        manager.invalidate() // Ensure idle state

        // Act: Call the method that previously bypassed PreloadManager
        AppCoordinator.shared?.initializeLLMIfAvailable()

        // Give it a moment to transition state
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms

        // Assert: State should NOT be idle - it should have triggered preloading
        // The bug was that state stayed .idle after calling initializeLLMIfAvailable()
        XCTAssertNotEqual(manager.state, .idle,
            "initializeLLMIfAvailable() must trigger PreloadManager state transition. " +
            "State stayed idle which means the fix for 'Model not loaded' bug regressed.")

        // Cleanup
        manager.invalidate()
    }
}
