import Foundation

// MARK: - Base Error Protocol

/// Base protocol for all PasteFence errors
/// Provides consistent error handling with codes, severity, and recovery hints
public protocol PasteFenceError: LocalizedError {
    /// Unique error code for logging and debugging (e.g., "LLM001")
    var errorCode: String { get }

    /// Severity level of the error
    var severity: ErrorSeverity { get }

    /// Whether the error can be recovered from automatically or with user action
    var isRecoverable: Bool { get }

    /// Suggested action for the user to resolve the error
    var suggestedAction: String? { get }
}

// MARK: - Error Severity

/// Severity levels for error classification
public enum ErrorSeverity: Int, Comparable, Sendable {
    /// Informational - operation completed but with notes
    case info = 0
    /// Warning - operation completed but may have issues
    case warning = 1
    /// Error - operation failed but app can continue
    case error = 2
    /// Critical - operation failed and may affect app stability
    case critical = 3

    public static func < (lhs: ErrorSeverity, rhs: ErrorSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Human-readable description
    public var description: String {
        switch self {
        case .info: return "Info"
        case .warning: return "Warning"
        case .error: return "Error"
        case .critical: return "Critical"
        }
    }

    /// SF Symbol name for UI display
    public var symbolName: String {
        switch self {
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.circle"
        case .critical: return "xmark.octagon"
        }
    }
}

// MARK: - Error Extensions

extension PasteFenceError {
    /// Full error message including code and description
    public var fullDescription: String {
        "[\(errorCode)] \(errorDescription ?? "Unknown error")"
    }

    /// Log-friendly format
    public var logMessage: String {
        var message = "[\(severity.description.uppercased())] \(errorCode): \(errorDescription ?? "Unknown error")"
        if let action = suggestedAction {
            message += " | Action: \(action)"
        }
        return message
    }
}
