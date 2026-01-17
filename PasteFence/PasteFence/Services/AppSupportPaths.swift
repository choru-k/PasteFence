import Foundation

/// Central place to determine where PasteFence stores per-user files.
///
/// - Production: `~/Library/Application Support/PasteFence`
/// - Tests: a temp directory under `FileManager.default.temporaryDirectory`
/// - Override: set `PASTEFENCE_APP_SUPPORT_DIR` to an absolute path
enum AppSupportPaths {
    /// The base directory for PasteFence app support files (the `PasteFence/` folder itself).
    static var pasteFenceDirectory: URL {
        if let overridePath = ProcessInfo.processInfo.environment["PASTEFENCE_APP_SUPPORT_DIR"],
           !overridePath.isEmpty {
            return URL(fileURLWithPath: overridePath, isDirectory: true)
        }

        if isRunningTests {
            // Keep the final component as "PasteFence" so existing path expectations remain stable.
            let pid = ProcessInfo.processInfo.processIdentifier
            return FileManager.default.temporaryDirectory
                .appendingPathComponent("PasteFenceTests", isDirectory: true)
                .appendingPathComponent(String(pid), isDirectory: true)
                .appendingPathComponent("PasteFence", isDirectory: true)
        }

        // swiftlint:disable:next force_unwrapping
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("PasteFence", isDirectory: true)
    }

    static func ensurePasteFenceDirectoryExists() {
        try? FileManager.default.createDirectory(at: pasteFenceDirectory, withIntermediateDirectories: true)
    }

    private static var isRunningTests: Bool {
        if NSClassFromString("XCTestCase") != nil {
            return true
        }

        let env = ProcessInfo.processInfo.environment
        return env["XCTestConfigurationFilePath"] != nil ||
            env["XCTestBundlePath"] != nil ||
            env["XCTestSessionIdentifier"] != nil
    }
}
