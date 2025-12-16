import Foundation

// MARK: - Storage Errors

/// Errors related to file storage and persistence
public enum StorageError: PasteFenceError {
    /// Failed to read from file
    case readFailed(path: String, reason: String)

    /// Failed to write to file
    case writeFailed(path: String, reason: String)

    /// Failed to decode data from storage
    case decodingFailed(type: String, reason: String)

    /// Failed to encode data for storage
    case encodingFailed(type: String, reason: String)

    /// File or directory not found
    case notFound(path: String)

    /// Permission denied
    case permissionDenied(path: String)

    /// Failed to create directory
    case directoryCreationFailed(path: String, reason: String)

    // MARK: - Error Code

    public var errorCode: String {
        switch self {
        case .readFailed: return "STO001"
        case .writeFailed: return "STO002"
        case .decodingFailed: return "STO003"
        case .encodingFailed: return "STO004"
        case .notFound: return "STO005"
        case .permissionDenied: return "STO006"
        case .directoryCreationFailed: return "STO007"
        }
    }

    // MARK: - Error Description

    public var errorDescription: String? {
        switch self {
        case .readFailed(let path, let reason):
            return "Failed to read '\(path)': \(reason)"
        case .writeFailed(let path, let reason):
            return "Failed to write '\(path)': \(reason)"
        case .decodingFailed(let type, let reason):
            return "Failed to decode \(type): \(reason)"
        case .encodingFailed(let type, let reason):
            return "Failed to encode \(type): \(reason)"
        case .notFound(let path):
            return "File not found: \(path)"
        case .permissionDenied(let path):
            return "Permission denied: \(path)"
        case .directoryCreationFailed(let path, let reason):
            return "Failed to create directory '\(path)': \(reason)"
        }
    }

    // MARK: - Severity

    public var severity: ErrorSeverity {
        switch self {
        case .readFailed, .writeFailed, .decodingFailed, .encodingFailed:
            return .error
        case .notFound:
            return .warning
        case .permissionDenied, .directoryCreationFailed:
            return .error
        }
    }

    // MARK: - Recoverability

    public var isRecoverable: Bool {
        switch self {
        case .notFound:
            return true  // Can create the file
        case .permissionDenied:
            return false  // Requires user intervention outside app
        case .decodingFailed:
            return false  // Data is corrupted
        default:
            return false
        }
    }

    // MARK: - Suggested Action

    public var suggestedAction: String? {
        switch self {
        case .readFailed, .writeFailed:
            return "Check disk space and file permissions"
        case .decodingFailed, .encodingFailed:
            return "The data may be corrupted. Try resetting settings."
        case .notFound:
            return nil  // Usually handled automatically
        case .permissionDenied:
            return "Check file permissions in Finder"
        case .directoryCreationFailed:
            return "Check disk space and permissions"
        }
    }
}

// MARK: - Clipboard Errors

/// Errors related to clipboard operations
public enum ClipboardError: PasteFenceError {
    /// Cannot access system clipboard
    case accessDenied

    /// Clipboard is empty
    case emptyClipboard

    /// Clipboard contains unsupported content type
    case unsupportedType(type: String)

    /// Failed to set clipboard content
    case setFailed(reason: String)

    // MARK: - Error Code

    public var errorCode: String {
        switch self {
        case .accessDenied: return "CB001"
        case .emptyClipboard: return "CB002"
        case .unsupportedType: return "CB003"
        case .setFailed: return "CB004"
        }
    }

    // MARK: - Error Description

    public var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Cannot access clipboard"
        case .emptyClipboard:
            return "Clipboard is empty"
        case .unsupportedType(let type):
            return "Unsupported clipboard content type: \(type)"
        case .setFailed(let reason):
            return "Failed to set clipboard content: \(reason)"
        }
    }

    // MARK: - Severity

    public var severity: ErrorSeverity {
        switch self {
        case .accessDenied:
            return .error
        case .emptyClipboard:
            return .info
        case .unsupportedType:
            return .warning
        case .setFailed:
            return .error
        }
    }

    // MARK: - Recoverability

    public var isRecoverable: Bool {
        switch self {
        case .emptyClipboard:
            return true  // User can copy something
        case .unsupportedType:
            return true  // User can copy text
        case .accessDenied, .setFailed:
            return false
        }
    }

    // MARK: - Suggested Action

    public var suggestedAction: String? {
        switch self {
        case .accessDenied:
            return "Check app permissions in System Settings"
        case .emptyClipboard:
            return "Copy some text first"
        case .unsupportedType:
            return "PasteFence only works with text content"
        case .setFailed:
            return "Try copying the text again"
        }
    }
}
