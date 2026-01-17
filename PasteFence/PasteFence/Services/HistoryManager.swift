import AppKit
import Combine
import Foundation

/// Observable manager for masking history with SwiftUI integration
@MainActor
class HistoryManager: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var history: MaskingHistory

    // MARK: - Singleton

    static let shared = HistoryManager()

    // MARK: - Initialization

    private init() {
        self.history = HistoryStorage.load()
    }

    /// Initialize with custom history (for testing)
    init(history: MaskingHistory) {
        self.history = history
    }

    // MARK: - Entry Management

    /// Add a new masking operation to history
    /// - Parameters:
    ///   - original: Original text before masking
    ///   - masked: Text after masking
    ///   - detected: All detected items
    ///   - applied: Items that were actually masked
    ///   - source: Source of detection (regex, hybrid, ollama)
    func addEntry(
        original: String,
        masked: String,
        detected: [DetectedItem],
        applied: [DetectedItem],
        source: MaskingHistoryEntry.MaskingSource
    ) {
        let entry = MaskingHistoryEntry(
            originalText: original,
            maskedText: masked,
            detectedItems: detected.map { HistoryDetectedItem(from: $0, in: original) },
            appliedItems: applied.map { HistoryDetectedItem(from: $0, in: original) },
            source: source
        )

        history.add(entry)
        HistoryStorage.saveAsync(history)
    }

    /// Remove a specific entry from history
    /// - Parameter entry: The entry to remove
    func removeEntry(_ entry: MaskingHistoryEntry) {
        history.remove(entry)
        HistoryStorage.saveAsync(history)
    }

    /// Remove entry by ID
    /// - Parameter id: The ID of the entry to remove
    func removeEntry(id: UUID) {
        history.remove(id: id)
        HistoryStorage.saveAsync(history)
    }

    /// Clear all history entries
    func clearHistory() {
        history.clear()
        HistoryStorage.saveAsync(history)
    }

    // MARK: - Export

    /// Export history to a temporary JSON file
    /// - Returns: URL to the exported file
    /// - Throws: Encoding or file write errors
    func exportHistory() throws -> URL {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate, .withTime, .withDashSeparatorInDate]
        let timestamp = dateFormatter.string(from: Date())
            .replacingOccurrences(of: ":", with: "-")

        let exportURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("pastefence_history_\(timestamp).json")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(history)
        try data.write(to: exportURL, options: [.atomic])

        return exportURL
    }

    // MARK: - Statistics

    /// Get statistics for current history
    var statistics: MaskingHistory.Statistics {
        history.calculateStatistics()
    }

    // MARK: - Query Methods

    /// Filter entries by sensitive type
    /// - Parameter type: The type to filter by
    /// - Returns: Entries containing the specified type
    func entries(for type: SensitiveType) -> [MaskingHistoryEntry] {
        history.entries(for: type)
    }

    /// Filter entries by date range
    /// - Parameter dateRange: The date range to filter by
    /// - Returns: Entries within the date range
    func entries(in dateRange: ClosedRange<Date>) -> [MaskingHistoryEntry] {
        history.entries(in: dateRange)
    }

    /// Search entries by text content
    /// - Parameter query: Search query
    /// - Returns: Matching entries
    func search(query: String) -> [MaskingHistoryEntry] {
        history.search(query: query)
    }

    // MARK: - Auto-Save

    private var terminationObserver: NSObjectProtocol?

    /// Setup auto-save on app termination
    nonisolated func setupAutoSave() {
        Task { @MainActor in
            self.terminationObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.willTerminateNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    guard let self = self else { return }
                    // Synchronous save on termination to ensure data is persisted
                    try? HistoryStorage.save(self.history)
                }
            }
        }
    }

    /// Remove auto-save observer
    func teardownAutoSave() {
        if let observer = terminationObserver {
            NotificationCenter.default.removeObserver(observer)
            terminationObserver = nil
        }
    }

    deinit {
        if let observer = terminationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
