import Foundation

// MARK: - User Error Message

/// User-facing error message with actionable information
/// Designed for display in UI alerts and notifications
public struct UserErrorMessage: Sendable {
    /// Alert title (e.g., "Error", "Warning", "Notice")
    public let title: String

    /// Detailed description of what went wrong
    public let description: String

    /// Optional suggestion for how to resolve the error
    public let suggestion: String?

    /// Severity level for visual styling
    public let severity: ErrorSeverity

    /// Error code for reference
    public let errorCode: String

    /// Whether this error should be shown as a toast (brief) or modal (requires action)
    public let presentationStyle: PresentationStyle

    public init(
        title: String,
        description: String,
        suggestion: String? = nil,
        severity: ErrorSeverity,
        errorCode: String = "",
        presentationStyle: PresentationStyle = .modal
    ) {
        self.title = title
        self.description = description
        self.suggestion = suggestion
        self.severity = severity
        self.errorCode = errorCode
        self.presentationStyle = presentationStyle
    }
}

// MARK: - Presentation Style

extension UserErrorMessage {
    /// How the error should be presented to the user
    public enum PresentationStyle: Sendable {
        /// Modal alert requiring user dismissal
        case modal
        /// Brief toast notification (auto-dismisses)
        case toast
    }
}

// MARK: - Error Action

/// An action button for error alerts
public struct ErrorAction: Sendable {
    /// Button title
    public let title: String

    /// Button style
    public let style: ActionStyle

    /// Action to perform when tapped (non-Sendable, handle carefully)
    public let handler: @Sendable () -> Void

    public init(title: String, style: ActionStyle = .secondary, handler: @escaping @Sendable () -> Void = {}) {
        self.title = title
        self.style = style
        self.handler = handler
    }

    /// Action button styles
    public enum ActionStyle: Sendable {
        /// Primary action (prominent, e.g., "Try Again")
        case primary
        /// Secondary action (subtle, e.g., "Cancel")
        case secondary
        /// Destructive action (red, e.g., "Delete")
        case destructive
    }
}

// MARK: - Convenience Initializers

extension UserErrorMessage {
    /// Create from any PasteFenceError
    public init(from error: PasteFenceError) {
        self.title = Self.titleForSeverity(error.severity)
        self.description = error.errorDescription ?? "An unknown error occurred"
        self.suggestion = error.suggestedAction
        self.severity = error.severity
        self.errorCode = error.errorCode
        self.presentationStyle = error.severity >= .error ? .modal : .toast
    }

    /// Create a generic error message for unknown errors
    public static func generic(from error: Error) -> UserErrorMessage {
        UserErrorMessage(
            title: "Error",
            description: error.localizedDescription,
            suggestion: "Please try again or restart the application.",
            severity: .error,
            errorCode: "GEN001",
            presentationStyle: .modal
        )
    }

    /// Title based on severity
    private static func titleForSeverity(_ severity: ErrorSeverity) -> String {
        switch severity {
        case .info: return "Notice"
        case .warning: return "Warning"
        case .error: return "Error"
        case .critical: return "Critical Error"
        }
    }
}
