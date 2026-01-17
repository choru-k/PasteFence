import Foundation

// MARK: - Log Level

/// Log severity levels compatible with Apple's unified logging
public enum LogLevel: String, CaseIterable, Sendable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
    case critical = "CRITICAL"

    /// Numeric priority for filtering (higher = more severe)
    public var priority: Int {
        switch self {
        case .debug: return 0
        case .info: return 1
        case .warning: return 2
        case .error: return 3
        case .critical: return 4
        }
    }
}

// MARK: - Log Category

/// Categories for organizing log output by subsystem
public enum LogCategory: String, CaseIterable, Sendable {
    case llm = "LLM"
    case ollama = "Ollama"
    case clipboard = "Clipboard"
    case masking = "Masking"
    case download = "Download"
    case storage = "Storage"
    case ui = "UI"
    case general = "General"

    /// Auto-detect category from error type
    public static func from(_ error: Error) -> LogCategory {
        switch error {
        case is LLMError: return .llm
        case is OllamaError: return .ollama
        case is ClipboardError: return .clipboard
        case is DownloadError: return .download
        case is StorageError: return .storage
        default: return .general
        }
    }
}

// MARK: - Error Context

/// Captures the source location and additional context for log entries
public struct ErrorContext: Sendable {
    public let file: String
    public let function: String
    public let line: Int
    public let additionalInfo: [String: String]

    public init(
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        additionalInfo: [String: String] = [:]
    ) {
        self.file = file
        self.function = function
        self.line = line
        self.additionalInfo = additionalInfo
    }

    /// Short filename without path
    public var filename: String {
        (file as NSString).lastPathComponent
    }

    /// Formatted source location
    public var sourceLocation: String {
        "[\(filename):\(line) \(function)]"
    }
}

// MARK: - Error Logger Protocol

/// Protocol for logging errors and messages
public protocol ErrorLogger: Sendable {
    /// Log an error with context
    func log(_ error: Error, context: ErrorContext)

    /// Log a message with level and category
    func log(_ message: String, level: LogLevel, category: LogCategory)

    /// Log a message with full context
    func log(_ message: String, level: LogLevel, category: LogCategory, context: ErrorContext)
}

// MARK: - Default Implementations

extension ErrorLogger {
    /// Log error with automatic context capture
    public func logError(
        _ error: Error,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        additionalInfo: [String: String] = [:]
    ) {
        let context = ErrorContext(
            file: file,
            function: function,
            line: line,
            additionalInfo: additionalInfo
        )
        log(error, context: context)
    }

    /// Log message with automatic context capture
    public func logMessage(
        _ message: String,
        level: LogLevel,
        category: LogCategory,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let context = ErrorContext(file: file, function: function, line: line)
        log(message, level: level, category: category, context: context)
    }
}

// MARK: - ErrorSeverity Extension

extension ErrorSeverity {
    /// Convert ErrorSeverity to LogLevel
    public var logLevel: LogLevel {
        switch self {
        case .info: return .info
        case .warning: return .warning
        case .error: return .error
        case .critical: return .critical
        }
    }
}
