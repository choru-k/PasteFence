import Foundation

// MARK: - HistoryDetectedItem

/// Codable version of DetectedItem for persistent storage
/// Uses integer offsets instead of Range<String.Index> which is not Codable
struct HistoryDetectedItem: Identifiable, Codable, Hashable {
    let id: UUID
    let text: String
    let type: String        // SensitiveType.rawValue
    let startOffset: Int    // UTF-16 offset for compatibility
    let endOffset: Int
    let confidence: Double
    let source: String      // "regex" or "llm"

    /// Initialize from a DetectedItem and its source text
    init(from detectedItem: DetectedItem, in text: String) {
        self.id = detectedItem.id
        self.text = detectedItem.text
        self.type = detectedItem.type.rawValue
        self.startOffset = text.distance(from: text.startIndex, to: detectedItem.range.lowerBound)
        self.endOffset = text.distance(from: text.startIndex, to: detectedItem.range.upperBound)
        self.confidence = detectedItem.confidence
        self.source = detectedItem.source == .regex ? "regex" : "llm"
    }

    /// Direct initializer for testing and deserialization
    init(id: UUID = UUID(), text: String, type: String, startOffset: Int, endOffset: Int, confidence: Double, source: String) {
        self.id = id
        self.text = text
        self.type = type
        self.startOffset = startOffset
        self.endOffset = endOffset
        self.confidence = confidence
        self.source = source
    }
}

// MARK: - MaskingHistoryEntry

/// Represents a single masking operation in history
struct MaskingHistoryEntry: Identifiable, Codable, Hashable {
    let id: UUID
    let timestamp: Date
    let originalText: String
    let maskedText: String
    let detectedItems: [HistoryDetectedItem]
    let appliedItems: [HistoryDetectedItem]  // Items user chose to mask
    let source: MaskingSource

    /// Source of detection for this masking operation
    enum MaskingSource: String, Codable {
        case regexOnly = "regex"
        case hybrid = "hybrid"       // Both regex and LLM
        case ollamaOnly = "ollama"
    }

    // MARK: - Computed Properties

    /// Total number of detected items
    var detectedCount: Int { detectedItems.count }

    /// Number of items that were actually masked
    var appliedCount: Int { appliedItems.count }

    /// Number of items detected but not masked (user excluded)
    var skippedCount: Int { detectedCount - appliedCount }

    /// Truncated preview of original text for list display
    var originalPreview: String {
        let maxLength = 100
        if originalText.count <= maxLength {
            return originalText
        }
        return String(originalText.prefix(maxLength)) + "..."
    }

    // MARK: - Initializers

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        originalText: String,
        maskedText: String,
        detectedItems: [HistoryDetectedItem],
        appliedItems: [HistoryDetectedItem],
        source: MaskingSource
    ) {
        self.id = id
        self.timestamp = timestamp
        self.originalText = originalText
        self.maskedText = maskedText
        self.detectedItems = detectedItems
        self.appliedItems = appliedItems
        self.source = source
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: MaskingHistoryEntry, rhs: MaskingHistoryEntry) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - MaskingHistory

/// Collection of masking history entries with max limit and utility methods
struct MaskingHistory: Codable {
    var entries: [MaskingHistoryEntry]
    let maxEntries: Int

    // MARK: - Initialization

    init(maxEntries: Int = 50) {
        self.entries = []
        self.maxEntries = maxEntries
    }

    init(entries: [MaskingHistoryEntry], maxEntries: Int = 50) {
        self.entries = entries
        self.maxEntries = maxEntries
    }

    // MARK: - Mutations

    /// Add a new entry (newest first), enforcing max limit
    mutating func add(_ entry: MaskingHistoryEntry) {
        entries.insert(entry, at: 0)  // Newest first

        // Trim to max
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }
    }

    /// Remove a specific entry by ID
    mutating func remove(_ entry: MaskingHistoryEntry) {
        entries.removeAll { $0.id == entry.id }
    }

    /// Remove entry by ID
    mutating func remove(id: UUID) {
        entries.removeAll { $0.id == id }
    }

    /// Clear all history entries
    mutating func clear() {
        entries.removeAll()
    }

    // MARK: - Queries

    /// Filter entries containing a specific sensitive type
    func entries(for type: SensitiveType) -> [MaskingHistoryEntry] {
        entries.filter { entry in
            entry.detectedItems.contains { $0.type == type.rawValue }
        }
    }

    /// Filter entries within a date range
    func entries(in dateRange: ClosedRange<Date>) -> [MaskingHistoryEntry] {
        entries.filter { dateRange.contains($0.timestamp) }
    }

    /// Search entries by text content
    func search(query: String) -> [MaskingHistoryEntry] {
        guard !query.isEmpty else { return entries }
        return entries.filter {
            $0.originalText.localizedCaseInsensitiveContains(query) ||
            $0.maskedText.localizedCaseInsensitiveContains(query)
        }
    }
}

// MARK: - Statistics Extension

extension MaskingHistory {
    /// Statistics about masking history
    struct Statistics {
        let totalOperations: Int
        let totalItemsDetected: Int
        let totalItemsMasked: Int
        let typeBreakdown: [String: Int]
        let averageItemsPerOperation: Double

        /// Percentage of detected items that were masked
        var maskingRate: Double {
            guard totalItemsDetected > 0 else { return 0 }
            return Double(totalItemsMasked) / Double(totalItemsDetected)
        }
    }

    /// Calculate statistics across all history entries
    func calculateStatistics() -> Statistics {
        let totalDetected = entries.reduce(0) { $0 + $1.detectedCount }
        let totalMasked = entries.reduce(0) { $0 + $1.appliedCount }

        var typeCount: [String: Int] = [:]
        for entry in entries {
            for item in entry.detectedItems {
                typeCount[item.type, default: 0] += 1
            }
        }

        let average = entries.isEmpty ? 0.0 : Double(totalDetected) / Double(entries.count)

        return Statistics(
            totalOperations: entries.count,
            totalItemsDetected: totalDetected,
            totalItemsMasked: totalMasked,
            typeBreakdown: typeCount,
            averageItemsPerOperation: average
        )
    }
}
