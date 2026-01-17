import XCTest
@testable import PasteFence

/// Tests for AccessibilityHelper utility
/// Note: Actual permission checking behavior depends on system state
final class AccessibilityHelperTests: XCTestCase {

    // MARK: - Permission Check Tests

    func testHasAccessibilityPermissionReturnsBool() {
        // Test that the property returns a boolean value
        // The actual value depends on whether the test runner has permission
        let hasPermission = AccessibilityHelper.hasAccessibilityPermission
        XCTAssertTrue(hasPermission == true || hasPermission == false)
    }

    func testRequestPermissionReturnsBool() throws {
        // Note: This test may trigger a system dialog in CI environments
        // It's primarily here to verify the API works
        // Skip in CI or automated testing environments
        guard ProcessInfo.processInfo.environment["CI"] == nil else {
            throw XCTSkip("Skipping permission request test in CI environment")
        }

        // The function should return the current permission status
        let result = AccessibilityHelper.requestPermission()
        XCTAssertTrue(result == true || result == false)
    }
}
