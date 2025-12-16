import Foundation

// MARK: - LLM Errors

/// Errors related to LLM model loading, configuration, and inference
public enum LLMError: PasteFenceError {
    // Model lifecycle errors
    case modelNotFound(path: String)
    case modelNotLoaded
    case modelLoadFailed(underlyingError: Error)

    // Tokenization errors
    case tokenizerError(reason: String)

    // Generation errors
    case generationFailed(underlyingError: Error)
    case contextLengthExceeded(length: Int, maximum: Int)

    // Configuration errors
    case configNotFound(path: String)
    case configInvalidJSON(underlyingError: Error)
    case configMissingField(field: String)
    case configUnsupportedModelType(type: String, supported: [String])
    case configInvalidValue(field: String, reason: String)

    // Resource errors
    case outOfMemory(requiredMB: Int, availableMB: Int)

    // MARK: - Error Code

    public var errorCode: String {
        switch self {
        case .modelNotFound: return "LLM001"
        case .modelNotLoaded: return "LLM002"
        case .modelLoadFailed: return "LLM003"
        case .tokenizerError: return "LLM004"
        case .generationFailed: return "LLM005"
        case .contextLengthExceeded: return "LLM006"
        case .configNotFound: return "LLM007"
        case .configInvalidJSON: return "LLM008"
        case .configMissingField: return "LLM009"
        case .configUnsupportedModelType: return "LLM010"
        case .configInvalidValue: return "LLM011"
        case .outOfMemory: return "LLM012"
        }
    }

    // MARK: - Error Description

    public var errorDescription: String? {
        switch self {
        case .modelNotFound(let path):
            return "Model not found at path: \(path)"
        case .modelNotLoaded:
            return "No model is currently loaded"
        case .modelLoadFailed(let error):
            return "Failed to load model: \(error.localizedDescription)"
        case .tokenizerError(let reason):
            return "Tokenizer error: \(reason)"
        case .generationFailed(let error):
            return "Text generation failed: \(error.localizedDescription)"
        case .contextLengthExceeded(let length, let max):
            return "Input too long: \(length) tokens exceeds maximum \(max)"
        case .configNotFound(let path):
            return "Model config.json not found at: \(path)"
        case .configInvalidJSON(let error):
            return "Invalid JSON in config.json: \(error.localizedDescription)"
        case .configMissingField(let field):
            return "Missing required field in config.json: \(field)"
        case .configUnsupportedModelType(let type, let supported):
            return "Unsupported model type '\(type)'. Supported: \(supported.joined(separator: ", "))"
        case .configInvalidValue(let field, let reason):
            return "Invalid value for '\(field)': \(reason)"
        case .outOfMemory(let required, let available):
            return "Insufficient memory: requires \(required)MB, available \(available)MB"
        }
    }

    // MARK: - Severity

    public var severity: ErrorSeverity {
        switch self {
        case .modelNotFound, .modelLoadFailed, .outOfMemory:
            return .critical
        case .modelNotLoaded, .tokenizerError, .generationFailed:
            return .error
        case .configNotFound, .configInvalidJSON, .configMissingField,
             .configUnsupportedModelType, .configInvalidValue:
            return .error
        case .contextLengthExceeded:
            return .warning
        }
    }

    // MARK: - Recoverability

    public var isRecoverable: Bool {
        switch self {
        case .contextLengthExceeded:
            return true  // User can shorten input
        case .configInvalidValue, .configMissingField:
            return true  // User can fix config
        case .modelNotLoaded:
            return true  // User can load a model
        case .outOfMemory:
            return true  // User can close apps or use smaller model
        default:
            return false
        }
    }

    // MARK: - Suggested Action

    public var suggestedAction: String? {
        switch self {
        case .modelNotFound:
            return "Download the model from Settings → Model"
        case .modelNotLoaded:
            return "Load a model in Settings → Model"
        case .modelLoadFailed:
            return "Try re-downloading the model or use a different one"
        case .tokenizerError:
            return "The model may be corrupted. Try re-downloading."
        case .generationFailed:
            return "Try again or restart the application"
        case .contextLengthExceeded:
            return "Try with shorter text"
        case .configNotFound, .configInvalidJSON, .configMissingField,
             .configUnsupportedModelType, .configInvalidValue:
            return "Re-download the model to restore configuration"
        case .outOfMemory:
            return "Close other applications or use a smaller model"
        }
    }
}

// MARK: - Backward Compatibility

/// Type alias for backward compatibility with existing code
/// - Note: Deprecated. Use `LLMError` instead.
@available(*, deprecated, renamed: "LLMError")
public typealias LLMEngineError = LLMError
