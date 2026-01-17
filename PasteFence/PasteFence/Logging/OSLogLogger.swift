import Foundation
import os.log

// MARK: - OSLog Logger

/// Logger implementation using Apple's unified logging system (os.log)
/// Logs are viewable in Console.app with filtering by subsystem and category
public final class OSLogLogger: ErrorLogger, @unchecked Sendable {

    // MARK: - Constants

    private let subsystem = "com.pastefence"

    // MARK: - Loggers

    private var loggers: [LogCategory: Logger] = [:]
    private let lock = NSLock()

    // MARK: - Initialization

    public init() {
        // Pre-create loggers for all categories
        for category in LogCategory.allCases {
            loggers[category] = Logger(subsystem: subsystem, category: category.rawValue)
        }
    }

    // MARK: - ErrorLogger Protocol

    public func log(_ error: Error, context: ErrorContext) {
        let category = LogCategory.from(error)
        let level = logLevel(for: error)
        let message = formatError(error, context: context)

        log(message, level: level, category: category)
    }

    public func log(_ message: String, level: LogLevel, category: LogCategory) {
        lock.lock()
        defer { lock.unlock() }

        guard let logger = loggers[category] else { return }

        switch level {
        case .debug:
            logger.debug("\(message, privacy: .public)")
        case .info:
            logger.info("\(message, privacy: .public)")
        case .warning:
            logger.warning("\(message, privacy: .public)")
        case .error:
            logger.error("\(message, privacy: .public)")
        case .critical:
            logger.critical("\(message, privacy: .public)")
        }
    }

    public func log(_ message: String, level: LogLevel, category: LogCategory, context: ErrorContext) {
        let formattedMessage = "\(context.sourceLocation) \(message)"
        log(formattedMessage, level: level, category: category)
    }

    // MARK: - Private Helpers

    private func formatError(_ error: Error, context: ErrorContext) -> String {
        var message = context.sourceLocation

        if let maskedError = error as? PasteFenceError {
            message += " [\(maskedError.errorCode)]"
            message += " \(maskedError.errorDescription ?? error.localizedDescription)"
        } else {
            message += " \(error.localizedDescription)"
        }

        if !context.additionalInfo.isEmpty {
            let info = context.additionalInfo.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
            message += " {\(info)}"
        }

        return message
    }

    private func logLevel(for error: Error) -> LogLevel {
        if let maskedError = error as? PasteFenceError {
            return maskedError.severity.logLevel
        }
        return .error
    }
}
