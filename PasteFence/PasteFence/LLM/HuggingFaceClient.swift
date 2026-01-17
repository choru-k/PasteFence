import Foundation

// MARK: - HuggingFace API Endpoints

/// HuggingFace Hub API endpoint configuration
enum HuggingFaceAPI {
    static let baseURL = "https://huggingface.co"

    /// URL to list files in a model repository
    /// - Parameters:
    ///   - repoId: Repository ID (e.g., "Qwen/Qwen3-0.6B-MLX-8bit")
    ///   - revision: Git revision (default: "main")
    /// - Returns: URL for the tree API endpoint
    static func filesURL(for repoId: String, revision: String = "main") -> URL {
        // swiftlint:disable:next force_unwrapping
        URL(string: "\(baseURL)/api/models/\(repoId)/tree/\(revision)")!
    }

    /// URL to download a specific file from a repository
    /// - Parameters:
    ///   - repoId: Repository ID
    ///   - path: File path within the repository
    ///   - revision: Git revision (default: "main")
    /// - Returns: URL to download the file
    static func downloadURL(for repoId: String, path: String, revision: String = "main") -> URL {
        // swiftlint:disable:next force_unwrapping
        URL(string: "\(baseURL)/\(repoId)/resolve/\(revision)/\(path)")!
    }
}

// MARK: - File Info Model

/// Information about a file or directory in a HuggingFace repository
struct HFFileInfo: Codable, Equatable, Sendable {
    /// Type of the entry ("file" or "directory")
    let type: String
    /// Path relative to repository root
    let path: String
    /// Size in bytes (nil for directories)
    let size: Int?
    /// Git object ID for versioning
    let oid: String?

    /// Whether this entry is a file (not a directory)
    var isFile: Bool { type == "file" }

    /// Whether this entry is a directory
    var isDirectory: Bool { type == "directory" }

    enum CodingKeys: String, CodingKey {
        case type, path, size, oid
    }
}

// MARK: - Error Types

/// Errors that can occur when interacting with HuggingFace Hub API
enum HFError: LocalizedError {
    /// Network-level error (no connectivity, timeout, etc.)
    case networkError(Error)
    /// HTTP error with non-success status code
    case httpError(statusCode: Int)
    /// Repository not found (404)
    case notFound(repoId: String)
    /// Rate limited by HuggingFace (429)
    case rateLimited(retryAfter: Int?)
    /// Response could not be parsed
    case invalidResponse
    /// JSON decoding failed
    case decodingError(Error)
    /// File download failed
    case downloadFailed(filename: String, reason: String?)
    /// Download was cancelled, optionally with resume data
    case cancelled(resumeData: Data?)
    /// No resume data available for continuing download
    case noResumeData

    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        case .notFound(let repoId):
            return "Repository not found: \(repoId)"
        case .rateLimited(let retryAfter):
            if let seconds = retryAfter {
                return "Rate limited. Retry after \(seconds) seconds"
            }
            return "Rate limited. Please try again later"
        case .invalidResponse:
            return "Invalid response from HuggingFace API"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .downloadFailed(let filename, let reason):
            if let reason = reason {
                return "Download failed for \(filename): \(reason)"
            }
            return "Download failed for \(filename)"
        case .cancelled:
            return "Download was cancelled"
        case .noResumeData:
            return "No resume data available to continue download"
        }
    }
}

// MARK: - Download Progress

/// Progress information for model downloads
struct DownloadProgress: Sendable, Equatable {
    /// Path of the file currently being downloaded
    let currentFile: String
    /// Index of the current file (0-based)
    let fileIndex: Int
    /// Total number of files to download
    let totalFiles: Int
    /// Total bytes downloaded so far
    let bytesDownloaded: Int64
    /// Total bytes to download
    let totalBytes: Int64

    /// Percentage complete (0.0 to 1.0)
    var percentComplete: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(bytesDownloaded) / Double(totalBytes)
    }

    /// Whether the download is complete
    var isComplete: Bool {
        fileIndex >= totalFiles
    }
}

// MARK: - HuggingFace Client

/// Actor-based client for interacting with HuggingFace Hub API
actor HuggingFaceClient {
    private let session: URLSession

    /// Initialize with a URLSession (default: shared session)
    /// - Parameter session: URLSession to use for requests
    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - API Methods

    /// List all files in a HuggingFace model repository
    /// - Parameters:
    ///   - repoId: Repository ID (e.g., "Qwen/Qwen3-0.6B-MLX-8bit")
    ///   - revision: Git revision (default: "main")
    /// - Returns: Array of file info objects
    /// - Throws: HFError on failure
    func listFiles(repoId: String, revision: String = "main") async throws -> [HFFileInfo] {
        let url = HuggingFaceAPI.filesURL(for: repoId, revision: revision)

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw HFError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw HFError.invalidResponse
        }

        // Handle HTTP status codes
        switch httpResponse.statusCode {
        case 200:
            break // Success
        case 404:
            throw HFError.notFound(repoId: repoId)
        case 429:
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                .flatMap { Int($0) }
            throw HFError.rateLimited(retryAfter: retryAfter)
        default:
            throw HFError.httpError(statusCode: httpResponse.statusCode)
        }

        // Decode response
        do {
            return try JSONDecoder().decode([HFFileInfo].self, from: data)
        } catch {
            throw HFError.decodingError(error)
        }
    }

    // MARK: - Filtering

    /// File extensions required for MLX model operation
    private static let requiredExtensions: Set<String> = [
        "json",        // config.json, tokenizer.json, tokenizer_config.json
        "safetensors", // Model weights
        "bin",         // PyTorch model weights
        "txt",         // vocab.txt, merges.txt
        "model"        // sentencepiece.model
    ]

    /// File patterns to exclude from downloads
    private static let excludePatterns: [String] = [
        "README",
        "LICENSE",
        ".gitattributes",
        ".gitignore"
    ]

    /// Filter file list to only include files required for model operation
    /// - Parameter files: Full list of files from repository
    /// - Returns: Filtered list containing only model-essential files
    func filterRequiredFiles(_ files: [HFFileInfo]) -> [HFFileInfo] {
        files.filter { file in
            // Only include files, not directories
            guard file.isFile else { return false }

            // Check file extension
            let ext = (file.path as NSString).pathExtension.lowercased()
            guard Self.requiredExtensions.contains(ext) || ext.isEmpty else {
                return false
            }

            // Exclude non-essential files
            for pattern in Self.excludePatterns {
                if file.path.contains(pattern) {
                    return false
                }
            }

            return true
        }
    }

    /// Calculate total download size for a list of files
    /// - Parameter files: Files to calculate size for
    /// - Returns: Total size in bytes
    func totalDownloadSize(_ files: [HFFileInfo]) -> Int64 {
        files.reduce(0) { total, file in
            total + Int64(file.size ?? 0)
        }
    }

    /// Format bytes as human-readable string
    /// - Parameter bytes: Number of bytes
    /// - Returns: Formatted string (e.g., "1.5 GB")
    static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    // MARK: - Download Methods

    /// Download a single file from a HuggingFace repository
    /// - Parameters:
    ///   - repoId: Repository ID (e.g., "Qwen/Qwen3-0.6B-MLX-8bit")
    ///   - path: File path within the repository
    ///   - destination: Local URL to save the file
    ///   - revision: Git revision (default: "main")
    /// - Throws: HFError on failure
    func downloadFile(
        repoId: String,
        path: String,
        to destination: URL,
        revision: String = "main"
    ) async throws {
        let url = HuggingFaceAPI.downloadURL(for: repoId, path: path, revision: revision)

        let tempURL: URL
        let response: URLResponse

        do {
            (tempURL, response) = try await session.download(from: url)
        } catch {
            throw HFError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw HFError.invalidResponse
        }

        // Handle HTTP status codes
        switch httpResponse.statusCode {
        case 200:
            break // Success
        case 404:
            throw HFError.downloadFailed(filename: path, reason: "File not found")
        case 429:
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                .flatMap { Int($0) }
            throw HFError.rateLimited(retryAfter: retryAfter)
        default:
            throw HFError.downloadFailed(filename: path, reason: "HTTP \(httpResponse.statusCode)")
        }

        // Create parent directories if needed
        let parentDir = destination.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: parentDir,
            withIntermediateDirectories: true
        )

        // Remove existing file if present
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }

        // Move from temp location to final destination
        try FileManager.default.moveItem(at: tempURL, to: destination)
    }

    /// Download multiple files from a HuggingFace repository with progress tracking
    /// - Parameters:
    ///   - repoId: Repository ID (e.g., "Qwen/Qwen3-0.6B-MLX-8bit")
    ///   - files: List of files to download
    ///   - destinationDir: Local directory to save files
    ///   - revision: Git revision (default: "main")
    ///   - progress: Callback invoked with download progress updates
    /// - Throws: HFError on failure
    func downloadModel(
        repoId: String,
        files: [HFFileInfo],
        to destinationDir: URL,
        revision: String = "main",
        progress: @escaping @Sendable (DownloadProgress) -> Void
    ) async throws {
        let totalSize = totalDownloadSize(files)
        var downloadedSize: Int64 = 0

        for (index, file) in files.enumerated() {
            // Report progress before starting each file
            progress(DownloadProgress(
                currentFile: file.path,
                fileIndex: index,
                totalFiles: files.count,
                bytesDownloaded: downloadedSize,
                totalBytes: totalSize
            ))

            let destFile = destinationDir.appendingPathComponent(file.path)
            try await downloadFile(repoId: repoId, path: file.path, to: destFile, revision: revision)

            downloadedSize += Int64(file.size ?? 0)
        }

        // Report completion
        progress(DownloadProgress(
            currentFile: "",
            fileIndex: files.count,
            totalFiles: files.count,
            bytesDownloaded: totalSize,
            totalBytes: totalSize
        ))
    }

    /// Download a single file with byte-level progress tracking
    /// - Parameters:
    ///   - repoId: Repository ID (e.g., "Qwen/Qwen3-0.6B-MLX-8bit")
    ///   - path: File path within the repository
    ///   - destination: Local URL to save the file
    ///   - revision: Git revision (default: "main")
    ///   - byteProgress: Callback invoked with (bytesWritten, totalBytes)
    /// - Throws: HFError on failure
    func downloadFileWithProgress(
        repoId: String,
        path: String,
        to destination: URL,
        revision: String = "main",
        byteProgress: @escaping @Sendable (Int64, Int64) -> Void
    ) async throws {
        let url = HuggingFaceAPI.downloadURL(for: repoId, path: path, revision: revision)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let delegate = DownloadProgressDelegate(
                progressHandler: byteProgress,
                completionHandler: { tempURL, error in
                    if let error = error {
                        continuation.resume(throwing: HFError.networkError(error))
                        return
                    }

                    guard let tempURL = tempURL else {
                        continuation.resume(throwing: HFError.invalidResponse)
                        return
                    }

                    // Move file to destination on background queue
                    Task {
                        do {
                            // Create parent directories if needed
                            let parentDir = destination.deletingLastPathComponent()
                            try FileManager.default.createDirectory(
                                at: parentDir,
                                withIntermediateDirectories: true
                            )

                            // Remove existing file if present
                            if FileManager.default.fileExists(atPath: destination.path) {
                                try FileManager.default.removeItem(at: destination)
                            }

                            // Move from temp location to final destination
                            try FileManager.default.moveItem(at: tempURL, to: destination)
                            continuation.resume()
                        } catch {
                            continuation.resume(throwing: HFError.downloadFailed(
                                filename: path,
                                reason: error.localizedDescription
                            ))
                        }
                    }
                }
            )

            let delegateSession = URLSession(
                configuration: .default,
                delegate: delegate,
                delegateQueue: nil
            )

            let task = delegateSession.downloadTask(with: url)
            task.resume()
        }
    }

    // MARK: - Resumable Download

    /// Download a single file with resume capability
    /// - Parameters:
    ///   - repoId: Repository ID (e.g., "Qwen/Qwen3-0.6B-MLX-8bit")
    ///   - path: File path within the repository
    ///   - destination: Local URL to save the file
    ///   - revision: Git revision (default: "main")
    ///   - resumeData: Optional resume data from previous interrupted download
    ///   - byteProgress: Callback invoked with (bytesWritten, totalBytes)
    /// - Returns: Resume data if download was cancelled, nil on success
    /// - Throws: HFError on failure
    func downloadFileResumable(
        repoId: String,
        path: String,
        to destination: URL,
        revision: String = "main",
        resumeData: Data? = nil,
        byteProgress: @escaping @Sendable (Int64, Int64) -> Void
    ) async throws {
        let url = HuggingFaceAPI.downloadURL(for: repoId, path: path, revision: revision)

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                let delegate = ResumableDownloadDelegate(
                    progressHandler: byteProgress,
                    completionHandler: { tempURL, error, cancelledResumeData in
                        // Handle cancellation with resume data
                        if let cancelledResumeData = cancelledResumeData {
                            continuation.resume(throwing: HFError.cancelled(resumeData: cancelledResumeData))
                            return
                        }

                        if let error = error {
                            continuation.resume(throwing: HFError.networkError(error))
                            return
                        }

                        guard let tempURL = tempURL else {
                            continuation.resume(throwing: HFError.invalidResponse)
                            return
                        }

                        // Move file to destination
                        Task {
                            do {
                                let parentDir = destination.deletingLastPathComponent()
                                try FileManager.default.createDirectory(
                                    at: parentDir,
                                    withIntermediateDirectories: true
                                )

                                if FileManager.default.fileExists(atPath: destination.path) {
                                    try FileManager.default.removeItem(at: destination)
                                }

                                try FileManager.default.moveItem(at: tempURL, to: destination)
                                continuation.resume()
                            } catch {
                                continuation.resume(throwing: HFError.downloadFailed(
                                    filename: path,
                                    reason: error.localizedDescription
                                ))
                            }
                        }
                    }
                )

                let delegateSession = URLSession(
                    configuration: .default,
                    delegate: delegate,
                    delegateQueue: nil
                )

                let task: URLSessionDownloadTask
                if let resumeData = resumeData {
                    task = delegateSession.downloadTask(withResumeData: resumeData)
                } else {
                    task = delegateSession.downloadTask(with: url)
                }

                // Store task reference for cancellation
                delegate.downloadTask = task
                task.resume()
            }
        } onCancel: {
            // Task cancellation is handled by the delegate
        }
    }

    // MARK: - Download with Retry

    /// Download a file with automatic retry and exponential backoff
    /// - Parameters:
    ///   - repoId: Repository ID
    ///   - path: File path within the repository
    ///   - destination: Local URL to save the file
    ///   - revision: Git revision (default: "main")
    ///   - maxRetries: Maximum number of retry attempts (default: 3)
    ///   - baseDelay: Base delay for exponential backoff in seconds (default: 2.0)
    ///   - byteProgress: Callback invoked with (bytesWritten, totalBytes)
    /// - Throws: HFError on failure after all retries exhausted
    func downloadWithRetry(
        repoId: String,
        path: String,
        to destination: URL,
        revision: String = "main",
        maxRetries: Int = 3,
        baseDelay: TimeInterval = 2.0,
        byteProgress: @escaping @Sendable (Int64, Int64) -> Void
    ) async throws {
        var lastError: Error?
        var resumeData: Data?

        for attempt in 0..<maxRetries {
            do {
                try await downloadFileResumable(
                    repoId: repoId,
                    path: path,
                    to: destination,
                    revision: revision,
                    resumeData: resumeData,
                    byteProgress: byteProgress
                )
                return // Success
            } catch let error as HFError {
                switch error {
                case .cancelled(let data):
                    // Don't retry cancellation, but preserve resume data
                    resumeData = data
                    throw error

                case .rateLimited(let retryAfter):
                    // Use server-provided delay if available
                    let delay = TimeInterval(retryAfter ?? Int(baseDelay * pow(2.0, Double(attempt))))
                    let cappedDelay = min(delay, 60.0) // Cap at 60 seconds
                    lastError = error
                    if attempt < maxRetries - 1 {
                        try await Task.sleep(for: .seconds(cappedDelay))
                    }

                case .networkError:
                    // Network errors may be transient, retry with backoff
                    lastError = error
                    resumeData = nil // Start fresh on network error
                    if attempt < maxRetries - 1 {
                        let delay = min(baseDelay * pow(2.0, Double(attempt)), 60.0)
                        try await Task.sleep(for: .seconds(delay))
                    }

                case .notFound, .invalidResponse, .decodingError, .downloadFailed, .httpError, .noResumeData:
                    // These are not retryable
                    throw error
                }
            } catch {
                // Non-HFError errors
                lastError = error
                if attempt < maxRetries - 1 {
                    let delay = min(baseDelay * pow(2.0, Double(attempt)), 60.0)
                    try await Task.sleep(for: .seconds(delay))
                }
            }
        }

        throw lastError ?? HFError.downloadFailed(filename: path, reason: "Unknown error after retries")
    }

    /// Download multiple files with byte-level progress tracking and speed/ETA
    /// - Parameters:
    ///   - repoId: Repository ID
    ///   - files: Files to download
    ///   - destinationDir: Local directory
    ///   - revision: Git revision
    ///   - state: Observable state to update (from main actor)
    /// - Throws: HFError on failure
    nonisolated func downloadModelWithProgress(
        repoId: String,
        files: [HFFileInfo],
        to destinationDir: URL,
        revision: String = "main",
        state: DownloadState
    ) async throws {
        let totalSize = files.reduce(Int64(0)) { $0 + Int64($1.size ?? 0) }
        let tracker = DownloadTracker(totalSize: totalSize)

        await MainActor.run {
            state.startDownload(totalBytes: totalSize, totalFiles: files.count)
        }

        for (index, file) in files.enumerated() {
            let fileSize = Int64(file.size ?? 0)
            let destFile = destinationDir.appendingPathComponent(file.path)
            let baseBytes = tracker.downloadedSize
            let filePath = file.path
            let fileIndex = index

            do {
                try await downloadFileWithProgress(
                    repoId: repoId,
                    path: file.path,
                    to: destFile,
                    revision: revision
                ) { bytesWritten, _ in
                    let currentTotal = baseBytes + bytesWritten
                    tracker.addSample(bytes: currentTotal)
                    let speed = tracker.calculateSpeed()
                    let remaining = totalSize - currentTotal
                    let eta = tracker.estimatedTimeRemaining(for: remaining)

                    Task { @MainActor in
                        state.updateProgress(
                            downloadedBytes: currentTotal,
                            currentFile: filePath,
                            fileIndex: fileIndex,
                            speed: speed,
                            eta: eta
                        )
                    }
                }

                tracker.addDownloadedBytes(fileSize)
            } catch {
                await MainActor.run {
                    state.failDownload(with: error)
                }
                throw error
            }
        }

        await MainActor.run {
            state.completeDownload()
        }
    }
}

// MARK: - Download Tracker

/// Thread-safe tracker for download progress across multiple files
final class DownloadTracker: @unchecked Sendable {
    private let lock = NSLock()
    private var samples: [(time: Date, bytes: Int64)] = []
    private let sampleWindow: TimeInterval = 5.0
    private let totalSize: Int64
    private var _downloadedSize: Int64 = 0

    var downloadedSize: Int64 {
        lock.lock()
        defer { lock.unlock() }
        return _downloadedSize
    }

    init(totalSize: Int64) {
        self.totalSize = totalSize
    }

    func addDownloadedBytes(_ bytes: Int64) {
        lock.lock()
        defer { lock.unlock() }
        _downloadedSize += bytes
    }

    func addSample(bytes: Int64) {
        lock.lock()
        defer { lock.unlock() }

        let now = Date()
        samples.append((now, bytes))
        samples.removeAll { now.timeIntervalSince($0.time) > sampleWindow }
    }

    func calculateSpeed() -> Double {
        lock.lock()
        defer { lock.unlock() }

        guard samples.count >= 2,
              let first = samples.first,
              let last = samples.last else {
            return 0
        }

        let timeInterval = last.time.timeIntervalSince(first.time)
        guard timeInterval > 0 else { return 0 }

        let bytesTransferred = last.bytes - first.bytes
        return Double(bytesTransferred) / timeInterval
    }

    func estimatedTimeRemaining(for remainingBytes: Int64) -> TimeInterval {
        let speed = calculateSpeed()
        guard speed > 0 else { return .infinity }
        return TimeInterval(remainingBytes) / speed
    }
}

// MARK: - Resumable Download Delegate

/// URLSession delegate that captures resume data on cancellation
final class ResumableDownloadDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    /// Callback for progress updates (bytesWritten, totalBytes)
    let progressHandler: @Sendable (Int64, Int64) -> Void

    /// Callback for download completion (tempFileURL, error, resumeData)
    let completionHandler: @Sendable (URL?, Error?, Data?) -> Void

    /// Reference to the download task (set externally for cancellation)
    var downloadTask: URLSessionDownloadTask?

    private var downloadedFileURL: URL?
    private var didComplete = false
    private let lock = NSLock()

    init(
        progressHandler: @escaping @Sendable (Int64, Int64) -> Void,
        completionHandler: @escaping @Sendable (URL?, Error?, Data?) -> Void
    ) {
        self.progressHandler = progressHandler
        self.completionHandler = completionHandler
        super.init()
    }

    // MARK: - URLSessionDownloadDelegate

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        progressHandler(totalBytesWritten, totalBytesExpectedToWrite)
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // Copy to a temp location that won't be auto-deleted
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent(UUID().uuidString)
        do {
            try FileManager.default.copyItem(at: location, to: tempURL)
            downloadedFileURL = tempURL
        } catch {
            downloadedFileURL = nil
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        lock.lock()
        guard !didComplete else {
            lock.unlock()
            return
        }
        didComplete = true
        lock.unlock()

        if let error = error as? URLError, error.code == .cancelled {
            // Get resume data from the error's userInfo
            let resumeData = error.userInfo[NSURLSessionDownloadTaskResumeData] as? Data
            completionHandler(nil, nil, resumeData)
        } else if let error = error {
            completionHandler(nil, error, nil)
        } else {
            completionHandler(downloadedFileURL, nil, nil)
        }
    }
}
