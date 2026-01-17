import Foundation

// MARK: - Ollama Errors

/// Errors related to Ollama integration and API communication
public enum OllamaError: PasteFenceError {
    /// Ollama server is not running
    case notRunning

    /// Failed to connect to Ollama server
    case connectionFailed(reason: String)

    /// Requested model is not available in Ollama
    case modelNotAvailable(model: String)

    /// Request to Ollama timed out
    case requestTimeout(timeoutSeconds: Int)

    /// Received invalid response from Ollama
    case invalidResponse(reason: String)

    /// Ollama API returned an error
    case apiError(statusCode: Int, message: String)

    /// Failed to parse Ollama response
    case parseError(reason: String)

    // MARK: - Error Code

    public var errorCode: String {
        switch self {
        case .notRunning: return "OLL001"
        case .connectionFailed: return "OLL002"
        case .modelNotAvailable: return "OLL003"
        case .requestTimeout: return "OLL004"
        case .invalidResponse: return "OLL005"
        case .apiError: return "OLL006"
        case .parseError: return "OLL007"
        }
    }

    // MARK: - Error Description

    public var errorDescription: String? {
        switch self {
        case .notRunning:
            return "Ollama is not running"
        case .connectionFailed(let reason):
            return "Failed to connect to Ollama: \(reason)"
        case .modelNotAvailable(let model):
            return "Model '\(model)' is not available in Ollama"
        case .requestTimeout(let timeout):
            return "Request to Ollama timed out after \(timeout) seconds"
        case .invalidResponse(let reason):
            return "Invalid response from Ollama: \(reason)"
        case .apiError(let code, let message):
            return "Ollama API error (\(code)): \(message)"
        case .parseError(let reason):
            return "Failed to parse Ollama response: \(reason)"
        }
    }

    // MARK: - Severity

    public var severity: ErrorSeverity {
        switch self {
        case .notRunning, .connectionFailed:
            return .error
        case .modelNotAvailable:
            return .error
        case .requestTimeout:
            return .warning
        case .invalidResponse, .apiError, .parseError:
            return .error
        }
    }

    // MARK: - Recoverability

    public var isRecoverable: Bool {
        // All Ollama errors are potentially recoverable
        // by starting Ollama, pulling models, or retrying
        return true
    }

    // MARK: - Suggested Action

    public var suggestedAction: String? {
        switch self {
        case .notRunning:
            return "Start Ollama with 'ollama serve' in Terminal"
        case .connectionFailed:
            return "Check if Ollama is running and accessible at localhost:11434"
        case .modelNotAvailable(let model):
            return "Pull the model with 'ollama pull \(model)'"
        case .requestTimeout:
            return "Check Ollama status and try again"
        case .invalidResponse, .parseError:
            return "Try again or check Ollama version compatibility"
        case .apiError:
            return "Check Ollama logs for more details"
        }
    }
}
