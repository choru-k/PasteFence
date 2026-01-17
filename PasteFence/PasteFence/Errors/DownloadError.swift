import Foundation

// MARK: - Download Errors

/// Errors related to model downloads and network operations
public enum DownloadError: PasteFenceError {
    /// No network connection available
    case networkUnavailable

    /// Download failed for a specific URL
    case downloadFailed(url: String, reason: String)

    /// Downloaded file checksum doesn't match expected value
    case checksumMismatch(expected: String, actual: String)

    /// Not enough disk space to complete download
    case insufficientStorage(requiredBytes: Int64, availableBytes: Int64)

    /// Download was cancelled by user
    case cancelled

    /// Failed to resume a paused download
    case resumeFailed(reason: String)

    /// File extraction/decompression failed
    case extractionFailed(reason: String)

    /// Invalid download URL
    case invalidURL(url: String)

    // MARK: - Error Code

    public var errorCode: String {
        switch self {
        case .networkUnavailable: return "DL001"
        case .downloadFailed: return "DL002"
        case .checksumMismatch: return "DL003"
        case .insufficientStorage: return "DL004"
        case .cancelled: return "DL005"
        case .resumeFailed: return "DL006"
        case .extractionFailed: return "DL007"
        case .invalidURL: return "DL008"
        }
    }

    // MARK: - Error Description

    public var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "No network connection available"
        case .downloadFailed(let url, let reason):
            return "Download failed for \(url): \(reason)"
        case .checksumMismatch(let expected, let actual):
            return "Downloaded file is corrupted (expected: \(expected.prefix(8))..., got: \(actual.prefix(8))...)"
        case .insufficientStorage(let required, let available):
            let reqMB = required / 1_000_000
            let avaMB = available / 1_000_000
            return "Not enough storage: need \(reqMB)MB, have \(avaMB)MB"
        case .cancelled:
            return "Download was cancelled"
        case .resumeFailed(let reason):
            return "Could not resume download: \(reason)"
        case .extractionFailed(let reason):
            return "Failed to extract downloaded file: \(reason)"
        case .invalidURL(let url):
            return "Invalid download URL: \(url)"
        }
    }

    // MARK: - Severity

    public var severity: ErrorSeverity {
        switch self {
        case .cancelled:
            return .info
        case .networkUnavailable, .resumeFailed:
            return .warning
        case .downloadFailed, .extractionFailed, .invalidURL:
            return .error
        case .checksumMismatch:
            return .error
        case .insufficientStorage:
            return .critical
        }
    }

    // MARK: - Recoverability

    public var isRecoverable: Bool {
        switch self {
        case .cancelled:
            return true  // User chose to cancel
        case .networkUnavailable:
            return true  // Wait for network
        case .resumeFailed:
            return true  // Can restart download
        case .downloadFailed, .extractionFailed:
            return true  // Can retry
        case .insufficientStorage:
            return true  // User can free space
        case .checksumMismatch:
            return false  // File is corrupted, needs re-download
        case .invalidURL:
            return false  // Configuration issue
        }
    }

    // MARK: - Suggested Action

    public var suggestedAction: String? {
        switch self {
        case .networkUnavailable:
            return "Check your internet connection and try again"
        case .downloadFailed:
            return "Check your connection and try again"
        case .checksumMismatch:
            return "Delete the file and download again"
        case .insufficientStorage:
            return "Free up disk space and try again"
        case .cancelled:
            return nil  // No action needed
        case .resumeFailed:
            return "Start a new download"
        case .extractionFailed:
            return "Delete the file and re-download"
        case .invalidURL:
            return "Check the model source URL"
        }
    }
}
