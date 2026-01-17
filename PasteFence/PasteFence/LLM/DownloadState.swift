import Combine
import Foundation

// MARK: - Speed Calculator

/// Calculates download speed using a sliding window of samples
struct SpeedCalculator: Sendable {
    private var samples: [(time: Date, bytes: Int64)] = []
    private let sampleWindow: TimeInterval

    /// Initialize with a sample window duration
    /// - Parameter sampleWindow: Time window for averaging speed (default: 5 seconds)
    init(sampleWindow: TimeInterval = 5.0) {
        self.sampleWindow = sampleWindow
    }

    /// Add a sample of bytes downloaded at the current time
    /// - Parameter bytes: Total bytes downloaded so far
    mutating func addSample(bytes: Int64) {
        let now = Date()
        samples.append((now, bytes))

        // Remove samples outside the window
        samples.removeAll { now.timeIntervalSince($0.time) > sampleWindow }
    }

    /// Calculate the current download speed
    /// - Returns: Speed in bytes per second, or 0 if insufficient samples
    func calculateSpeed() -> Double {
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

    /// Calculate estimated time remaining
    /// - Parameter remainingBytes: Bytes left to download
    /// - Returns: Estimated time in seconds, or infinity if speed is 0
    func estimatedTimeRemaining(for remainingBytes: Int64) -> TimeInterval {
        let speed = calculateSpeed()
        guard speed > 0 else { return .infinity }
        return TimeInterval(remainingBytes) / speed
    }

    /// Reset all samples
    mutating func reset() {
        samples.removeAll()
    }
}

// MARK: - Download State

/// Observable state for tracking download progress in SwiftUI
@MainActor
final class DownloadState: ObservableObject {
    /// Whether a download is currently in progress
    @Published var isDownloading = false

    /// Name of the file currently being downloaded
    @Published var currentFile: String = ""

    /// Overall progress (0.0 to 1.0)
    @Published var progress: Double = 0.0

    /// Total bytes downloaded so far
    @Published var downloadedBytes: Int64 = 0

    /// Total bytes to download
    @Published var totalBytes: Int64 = 0

    /// Current download speed in bytes per second
    @Published var speed: Double = 0.0

    /// Estimated time remaining in seconds
    @Published var estimatedTimeRemaining: TimeInterval = 0

    /// Error if download failed
    @Published var error: Error?

    /// File index being downloaded (0-based)
    @Published var currentFileIndex: Int = 0

    /// Total number of files to download
    @Published var totalFiles: Int = 0

    // MARK: - Formatted Properties

    /// Formatted progress string (e.g., "500 MB / 1 GB")
    var formattedProgress: String {
        let downloaded = ByteCountFormatter.string(fromByteCount: downloadedBytes, countStyle: .file)
        let total = ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
        return "\(downloaded) / \(total)"
    }

    /// Formatted speed string (e.g., "10 MB/s")
    var formattedSpeed: String {
        let speedStr = ByteCountFormatter.string(fromByteCount: Int64(speed), countStyle: .file)
        return "\(speedStr)/s"
    }

    /// Formatted ETA string (e.g., "5m 30s" or "Calculating...")
    var formattedETA: String {
        guard estimatedTimeRemaining > 0, estimatedTimeRemaining < .infinity else {
            return "Calculating..."
        }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        return formatter.string(from: estimatedTimeRemaining) ?? "Calculating..."
    }

    /// File progress string (e.g., "File 2 of 5")
    var fileProgressString: String {
        guard totalFiles > 0 else { return "" }
        return "File \(currentFileIndex + 1) of \(totalFiles)"
    }

    // MARK: - State Management

    /// Reset state for a new download
    func reset() {
        isDownloading = false
        currentFile = ""
        progress = 0.0
        downloadedBytes = 0
        totalBytes = 0
        speed = 0.0
        estimatedTimeRemaining = 0
        error = nil
        currentFileIndex = 0
        totalFiles = 0
    }

    /// Start a new download session
    /// - Parameters:
    ///   - totalBytes: Total bytes to download
    ///   - totalFiles: Total number of files
    func startDownload(totalBytes: Int64, totalFiles: Int) {
        reset()
        self.isDownloading = true
        self.totalBytes = totalBytes
        self.totalFiles = totalFiles
    }

    /// Update progress with new values
    /// - Parameters:
    ///   - downloadedBytes: Total bytes downloaded
    ///   - currentFile: Current file being downloaded
    ///   - fileIndex: Index of current file
    ///   - speed: Current speed in bytes/second
    ///   - eta: Estimated time remaining
    func updateProgress(
        downloadedBytes: Int64,
        currentFile: String,
        fileIndex: Int,
        speed: Double,
        eta: TimeInterval
    ) {
        self.downloadedBytes = downloadedBytes
        self.currentFile = currentFile
        self.currentFileIndex = fileIndex
        self.speed = speed
        self.estimatedTimeRemaining = eta

        if totalBytes > 0 {
            self.progress = Double(downloadedBytes) / Double(totalBytes)
        }
    }

    /// Mark download as complete
    func completeDownload() {
        isDownloading = false
        progress = 1.0
        downloadedBytes = totalBytes
        estimatedTimeRemaining = 0
    }

    /// Mark download as failed
    /// - Parameter error: The error that caused the failure
    func failDownload(with error: Error) {
        self.error = error
        isDownloading = false
    }
}

// MARK: - Download Progress Delegate

/// URLSession delegate for tracking byte-level download progress
final class DownloadProgressDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    /// Callback for progress updates (bytesWritten, totalBytes)
    let progressHandler: @Sendable (Int64, Int64) -> Void

    /// Callback for download completion (tempFileURL, error)
    let completionHandler: @Sendable (URL?, Error?) -> Void

    private var downloadedFileURL: URL?

    /// Initialize with handlers
    /// - Parameters:
    ///   - progressHandler: Called with progress updates
    ///   - completionHandler: Called when download completes or fails
    init(
        progressHandler: @escaping @Sendable (Int64, Int64) -> Void,
        completionHandler: @escaping @Sendable (URL?, Error?) -> Void
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
        // Store the location - will be used in didCompleteWithError
        downloadedFileURL = location
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        if let error = error {
            completionHandler(nil, error)
        } else {
            completionHandler(downloadedFileURL, nil)
        }
    }
}
