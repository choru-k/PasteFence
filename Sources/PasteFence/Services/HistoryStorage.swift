import Foundation

/// Static utility struct for persistent history storage operations
struct HistoryStorage {

    // MARK: - Storage Location

    /// URL for the history JSON file in Application Support directory
    static let storageURL: URL = {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!

        let appDir = appSupport.appendingPathComponent("PasteFence")

        // Ensure directory exists
        try? FileManager.default.createDirectory(
            at: appDir,
            withIntermediateDirectories: true
        )

        return appDir.appendingPathComponent("history.json")
    }()

    // MARK: - Save Operations

    /// Save history to disk synchronously
    /// - Parameter history: The history to save
    /// - Throws: Encoding or file write errors
    static func save(_ history: MaskingHistory) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(history)
        try data.write(to: storageURL, options: [.atomic])
    }

    /// Save history to disk asynchronously in background
    /// - Parameter history: The history to save
    static func saveAsync(_ history: MaskingHistory) {
        Task.detached(priority: .background) {
            do {
                try save(history)
            } catch {
                print("[HistoryStorage] Save failed: \(error)")
            }
        }
    }

    // MARK: - Load Operations

    /// Load history from disk
    /// - Returns: The loaded history, or empty history if file doesn't exist or is corrupt
    static func load() -> MaskingHistory {
        guard FileManager.default.fileExists(atPath: storageURL.path) else {
            return MaskingHistory()
        }

        do {
            let data = try Data(contentsOf: storageURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(MaskingHistory.self, from: data)
        } catch {
            print("[HistoryStorage] Load failed: \(error)")
            return MaskingHistory()
        }
    }

    // MARK: - Utility

    /// Delete the history file
    /// - Throws: File deletion errors
    static func deleteStorage() throws {
        if FileManager.default.fileExists(atPath: storageURL.path) {
            try FileManager.default.removeItem(at: storageURL)
        }
    }

    /// Check if history file exists
    static var exists: Bool {
        FileManager.default.fileExists(atPath: storageURL.path)
    }
}
