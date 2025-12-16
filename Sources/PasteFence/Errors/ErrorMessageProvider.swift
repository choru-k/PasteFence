import Foundation

// MARK: - Error Message Provider Protocol

/// Protocol for converting errors to user-friendly messages
public protocol ErrorMessageProvider {
    /// Convert any error to a user-friendly message
    func userMessage(for error: Error) -> UserErrorMessage

    /// Get contextual actions for an error
    func actions(for error: Error) -> [ErrorAction]
}

// MARK: - Default Implementation

/// Default provider that maps PasteFenceError protocol errors to user messages
public final class DefaultErrorMessageProvider: ErrorMessageProvider {

    public init() {}

    // MARK: - User Message

    public func userMessage(for error: Error) -> UserErrorMessage {
        if let maskedError = error as? PasteFenceError {
            return UserErrorMessage(from: maskedError)
        }

        // Fallback for unknown errors
        return UserErrorMessage.generic(from: error)
    }

    // MARK: - Contextual Actions

    public func actions(for error: Error) -> [ErrorAction] {
        // LLM-specific actions
        if let llmError = error as? LLMError {
            return actions(for: llmError)
        }

        // Ollama-specific actions
        if let ollamaError = error as? OllamaError {
            return actions(for: ollamaError)
        }

        // Download-specific actions
        if let downloadError = error as? DownloadError {
            return actions(for: downloadError)
        }

        // Generic recoverable error actions
        if let maskedError = error as? PasteFenceError {
            return genericActions(for: maskedError)
        }

        // Fallback
        return [
            ErrorAction(title: "OK", style: .primary)
        ]
    }

    // MARK: - LLM Actions

    private func actions(for error: LLMError) -> [ErrorAction] {
        switch error {
        case .modelNotFound, .modelNotLoaded:
            return [
                ErrorAction(title: "Open Settings", style: .primary) {
                    NotificationCenter.default.post(name: .openModelSettings, object: nil)
                },
                ErrorAction(title: "Dismiss", style: .secondary)
            ]

        case .modelLoadFailed, .tokenizerError:
            return [
                ErrorAction(title: "Re-download Model", style: .primary) {
                    NotificationCenter.default.post(name: .redownloadModel, object: nil)
                },
                ErrorAction(title: "Dismiss", style: .secondary)
            ]

        case .outOfMemory:
            return [
                ErrorAction(title: "Use Smaller Model", style: .primary) {
                    NotificationCenter.default.post(name: .switchToSmallerModel, object: nil)
                },
                ErrorAction(title: "Dismiss", style: .secondary)
            ]

        case .contextLengthExceeded:
            return [
                ErrorAction(title: "OK", style: .primary)
            ]

        case .generationFailed:
            return [
                ErrorAction(title: "Try Again", style: .primary) {
                    NotificationCenter.default.post(name: .retryGeneration, object: nil)
                },
                ErrorAction(title: "Dismiss", style: .secondary)
            ]

        default:
            return [
                ErrorAction(title: "OK", style: .primary)
            ]
        }
    }

    // MARK: - Ollama Actions

    private func actions(for error: OllamaError) -> [ErrorAction] {
        switch error {
        case .notRunning:
            return [
                ErrorAction(title: "Use Local LLM", style: .primary) {
                    NotificationCenter.default.post(name: .switchToLocalLLM, object: nil)
                },
                ErrorAction(title: "Dismiss", style: .secondary)
            ]

        case .modelNotAvailable:
            return [
                ErrorAction(title: "Pull Model", style: .primary) {
                    NotificationCenter.default.post(name: .pullOllamaModel, object: nil)
                },
                ErrorAction(title: "Use Different Model", style: .secondary) {
                    NotificationCenter.default.post(name: .openModelSettings, object: nil)
                }
            ]

        case .requestTimeout, .connectionFailed:
            return [
                ErrorAction(title: "Retry", style: .primary) {
                    NotificationCenter.default.post(name: .retryOllamaConnection, object: nil)
                },
                ErrorAction(title: "Dismiss", style: .secondary)
            ]

        default:
            return [
                ErrorAction(title: "OK", style: .primary)
            ]
        }
    }

    // MARK: - Download Actions

    private func actions(for error: DownloadError) -> [ErrorAction] {
        switch error {
        case .networkUnavailable:
            return [
                ErrorAction(title: "Retry", style: .primary) {
                    NotificationCenter.default.post(name: .retryDownload, object: nil)
                },
                ErrorAction(title: "Dismiss", style: .secondary)
            ]

        case .insufficientStorage:
            return [
                ErrorAction(title: "Open Storage Settings", style: .primary) {
                    NotificationCenter.default.post(name: .openStorageSettings, object: nil)
                },
                ErrorAction(title: "Dismiss", style: .secondary)
            ]

        case .cancelled:
            return [
                ErrorAction(title: "Resume Download", style: .primary) {
                    NotificationCenter.default.post(name: .resumeDownload, object: nil)
                },
                ErrorAction(title: "Dismiss", style: .secondary)
            ]

        default:
            return [
                ErrorAction(title: "Retry", style: .primary) {
                    NotificationCenter.default.post(name: .retryDownload, object: nil)
                },
                ErrorAction(title: "Dismiss", style: .secondary)
            ]
        }
    }

    // MARK: - Generic Actions

    private func genericActions(for error: PasteFenceError) -> [ErrorAction] {
        if error.isRecoverable {
            return [
                ErrorAction(title: "Try Again", style: .primary),
                ErrorAction(title: "Dismiss", style: .secondary)
            ]
        } else {
            return [
                ErrorAction(title: "OK", style: .primary)
            ]
        }
    }
}

// MARK: - Notification Names

public extension Notification.Name {
    // Model settings
    static let openModelSettings = Notification.Name("openModelSettings")
    static let redownloadModel = Notification.Name("redownloadModel")
    static let switchToSmallerModel = Notification.Name("switchToSmallerModel")

    // Generation
    static let retryGeneration = Notification.Name("retryGeneration")

    // Ollama
    static let switchToLocalLLM = Notification.Name("switchToLocalLLM")
    static let pullOllamaModel = Notification.Name("pullOllamaModel")
    static let retryOllamaConnection = Notification.Name("retryOllamaConnection")

    // Downloads
    static let retryDownload = Notification.Name("retryDownload")
    static let resumeDownload = Notification.Name("resumeDownload")
    static let openStorageSettings = Notification.Name("openStorageSettings")
}
