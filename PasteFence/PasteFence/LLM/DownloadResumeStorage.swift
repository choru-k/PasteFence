import Foundation

// MARK: - Download Resume Info

/// Information needed to resume an interrupted download
struct DownloadResumeInfo: Codable, Sendable {
    /// Repository ID on HuggingFace
    let repoId: String
    /// Filename being downloaded
    let filename: String
    /// URLSession resume data for continuing download
    let resumeData: Data
    /// Bytes downloaded before interruption
    let downloadedBytes: Int64
    /// Total bytes expected
    let totalBytes: Int64
    /// When the download was interrupted
    let timestamp: Date
    /// Git revision/branch
    let revision: String

    /// Check if resume info is stale (older than 24 hours)
    var isStale: Bool {
        Date().timeIntervalSince(timestamp) > 24 * 60 * 60
    }
}

// MARK: - Download Resume Storage

/// Persistent storage for download resume data
final class DownloadResumeStorage: Sendable {
    /// Storage file URL
    private let storageURL: URL

    /// Initialize with default storage location
    init() {
        self.storageURL = ModelPaths.appSupport.appendingPathComponent("download_resume.json")
    }

    /// Initialize with custom storage URL (for testing)
    init(storageURL: URL) {
        self.storageURL = storageURL
    }

    // MARK: - Save

    /// Save resume info for a download
    /// - Parameter info: Resume information to persist
    /// - Throws: Encoding or file write errors
    func save(_ info: DownloadResumeInfo) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(info)
        try data.write(to: storageURL, options: .atomic)
    }

    /// Save multiple resume infos (for batch downloads)
    /// - Parameter infos: Array of resume information
    /// - Throws: Encoding or file write errors
    func saveMultiple(_ infos: [DownloadResumeInfo]) throws {
        let batchURL = storageURL.deletingLastPathComponent()
            .appendingPathComponent("download_resume_batch.json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(infos)
        try data.write(to: batchURL, options: .atomic)
    }

    // MARK: - Load

    /// Load saved resume info
    /// - Returns: Resume info if available and not stale, nil otherwise
    func load() -> DownloadResumeInfo? {
        guard let data = try? Data(contentsOf: storageURL) else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let info = try? decoder.decode(DownloadResumeInfo.self, from: data) else {
            return nil
        }

        // Clear stale resume data
        if info.isStale {
            clear()
            return nil
        }

        return info
    }

    /// Load multiple resume infos (for batch downloads)
    /// - Returns: Array of resume infos, filtering out stale entries
    func loadMultiple() -> [DownloadResumeInfo] {
        let batchURL = storageURL.deletingLastPathComponent()
            .appendingPathComponent("download_resume_batch.json")

        guard let data = try? Data(contentsOf: batchURL) else {
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let infos = try? decoder.decode([DownloadResumeInfo].self, from: data) else {
            return []
        }

        // Filter out stale entries
        let validInfos = infos.filter { !$0.isStale }

        // Update storage if some entries were stale
        if validInfos.count < infos.count {
            if validInfos.isEmpty {
                clearMultiple()
            } else {
                try? saveMultiple(validInfos)
            }
        }

        return validInfos
    }

    // MARK: - Clear

    /// Clear saved resume info
    func clear() {
        try? FileManager.default.removeItem(at: storageURL)
    }

    /// Clear batch resume info
    func clearMultiple() {
        let batchURL = storageURL.deletingLastPathComponent()
            .appendingPathComponent("download_resume_batch.json")
        try? FileManager.default.removeItem(at: batchURL)
    }

    /// Clear all resume data (single and batch)
    func clearAll() {
        clear()
        clearMultiple()
    }

    // MARK: - Query

    /// Check if resume data exists for a specific file
    /// - Parameters:
    ///   - repoId: Repository ID
    ///   - filename: File name
    /// - Returns: Resume info if available for this file
    func resumeInfo(for repoId: String, filename: String) -> DownloadResumeInfo? {
        // Check single file first
        if let info = load(),
           info.repoId == repoId,
           info.filename == filename {
            return info
        }

        // Check batch
        return loadMultiple().first {
            $0.repoId == repoId && $0.filename == filename
        }
    }

    /// Check if any resume data exists
    var hasResumeData: Bool {
        load() != nil || !loadMultiple().isEmpty
    }
}
