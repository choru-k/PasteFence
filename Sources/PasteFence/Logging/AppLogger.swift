import Foundation

// MARK: - App Logger (Composite)

/// Composite logger that combines OSLog and File logging
/// Use `AppLogger.shared` for app-wide logging
public final class AppLogger: ErrorLogger, @unchecked Sendable {

    // MARK: - Shared Instance

    /// Shared app-wide logger instance
    public static let shared = AppLogger()

    // MARK: - Properties

    private let loggers: [ErrorLogger]
    private let osLogLogger: OSLogLogger
    private let fileLogger: FileLogger

    // MARK: - Initialization

    public init() {
        self.osLogLogger = OSLogLogger()
        self.fileLogger = FileLogger()
        self.loggers = [osLogLogger, fileLogger]
    }

    // MARK: - ErrorLogger Protocol

    public func log(_ error: Error, context: ErrorContext) {
        for logger in loggers {
            logger.log(error, context: context)
        }
    }

    public func log(_ message: String, level: LogLevel, category: LogCategory) {
        for logger in loggers {
            logger.log(message, level: level, category: category)
        }
    }

    public func log(_ message: String, level: LogLevel, category: LogCategory, context: ErrorContext) {
        for logger in loggers {
            logger.log(message, level: level, category: category, context: context)
        }
    }

    // MARK: - File Logger Access

    /// Get the file logger for log file management
    public var file: FileLogger {
        fileLogger
    }

    /// Cleanup old log files
    public func cleanupOldLogs() {
        fileLogger.cleanupOldLogs()
    }
}

// MARK: - Global Convenience Functions

/// Log an error with automatic source location capture
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
    AppLogger.shared.log(error, context: context)
}

/// Log a debug message
public func logDebug(
    _ message: String,
    category: LogCategory = .general,
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    let context = ErrorContext(file: file, function: function, line: line)
    AppLogger.shared.log(message, level: .debug, category: category, context: context)
}

/// Log an info message
public func logInfo(
    _ message: String,
    category: LogCategory = .general,
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    let context = ErrorContext(file: file, function: function, line: line)
    AppLogger.shared.log(message, level: .info, category: category, context: context)
}

/// Log a warning message
public func logWarning(
    _ message: String,
    category: LogCategory = .general,
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    let context = ErrorContext(file: file, function: function, line: line)
    AppLogger.shared.log(message, level: .warning, category: category, context: context)
}

/// Log an error message (not an Error object)
public func logErrorMessage(
    _ message: String,
    category: LogCategory = .general,
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    let context = ErrorContext(file: file, function: function, line: line)
    AppLogger.shared.log(message, level: .error, category: category, context: context)
}

/// Log a critical message
public func logCritical(
    _ message: String,
    category: LogCategory = .general,
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    let context = ErrorContext(file: file, function: function, line: line)
    AppLogger.shared.log(message, level: .critical, category: category, context: context)
}
