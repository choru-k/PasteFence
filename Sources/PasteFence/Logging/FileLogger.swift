import Foundation

// MARK: - File Logger

/// Logger implementation that writes to persistent log files
/// Features daily rotation, 7-day retention, and thread-safe writes
public final class FileLogger: ErrorLogger, @unchecked Sendable {

    // MARK: - Constants

    private let logsDirectoryName = "logs"
    private let logFilePrefix = "pastefence-"
    private let logFileExtension = "log"
    private let retentionDays = 7

    // MARK: - Properties

    private let logsDirectory: URL
    private let dateFormatter: DateFormatter
    private let timestampFormatter: DateFormatter
    private let queue = DispatchQueue(label: "com.pastefence.filelogger", qos: .utility)

    // MARK: - Initialization

    public init() {
        // Setup logs directory
        AppSupportPaths.ensurePasteFenceDirectoryExists()
        let appDir = AppSupportPaths.pasteFenceDirectory
        self.logsDirectory = appDir.appendingPathComponent(logsDirectoryName)

        // Create directory if needed
        try? FileManager.default.createDirectory(at: logsDirectory, withIntermediateDirectories: true)

        // Setup date formatter for filenames (YYYY-MM-DD)
        self.dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        // Setup timestamp formatter for log entries
        self.timestampFormatter = DateFormatter()
        timestampFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"

        // Cleanup old logs on initialization
        cleanupOldLogs()
    }

    // MARK: - ErrorLogger Protocol

    public func log(_ error: Error, context: ErrorContext) {
        let category = LogCategory.from(error)
        let level = logLevel(for: error)
        let message = formatError(error, context: context)

        writeLog(message, level: level, category: category)
    }

    public func log(_ message: String, level: LogLevel, category: LogCategory) {
        writeLog(message, level: level, category: category)
    }

    public func log(_ message: String, level: LogLevel, category: LogCategory, context: ErrorContext) {
        let formattedMessage = "\(context.sourceLocation) \(message)"
        writeLog(formattedMessage, level: level, category: category)
    }

    // MARK: - Log Writing

    private func writeLog(_ message: String, level: LogLevel, category: LogCategory) {
        let timestamp = timestampFormatter.string(from: Date())
        let logLine = "[\(timestamp)] [\(level.rawValue)] [\(category.rawValue)] \(message)\n"

        queue.async { [weak self] in
            guard let self = self else { return }

            let logFileURL = self.currentLogFileURL()

            guard let data = logLine.data(using: .utf8) else { return }

            if FileManager.default.fileExists(atPath: logFileURL.path) {
                // Append to existing file
                if let handle = try? FileHandle(forWritingTo: logFileURL) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    try? handle.close()
                }
            } else {
                // Create new file
                try? data.write(to: logFileURL)
            }
        }
    }

    private func currentLogFileURL() -> URL {
        let dateString = dateFormatter.string(from: Date())
        let filename = "\(logFilePrefix)\(dateString).\(logFileExtension)"
        return logsDirectory.appendingPathComponent(filename)
    }

    // MARK: - Error Formatting

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

    // MARK: - Log Management

    /// Remove log files older than retention period
    public func cleanupOldLogs() {
        queue.async { [weak self] in
            guard let self = self else { return }

            let cutoffDate = Date().addingTimeInterval(-Double(self.retentionDays) * 24 * 60 * 60)

            guard let files = try? FileManager.default.contentsOfDirectory(
                at: self.logsDirectory,
                includingPropertiesForKeys: [.creationDateKey]
            ) else { return }

            for file in files {
                guard file.pathExtension == self.logFileExtension else { continue }

                if let attrs = try? file.resourceValues(forKeys: [.creationDateKey]),
                   let created = attrs.creationDate,
                   created < cutoffDate {
                    try? FileManager.default.removeItem(at: file)
                }
            }
        }
    }

    /// Get URL to current log file (for debugging/export)
    public func currentLogFile() -> URL {
        currentLogFileURL()
    }

    /// Get all log file URLs
    public func allLogFiles() -> [URL] {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: logsDirectory,
            includingPropertiesForKeys: [.creationDateKey]
        ) else { return [] }

        return files
            .filter { $0.pathExtension == logFileExtension }
            .sorted { ($0.lastPathComponent) < ($1.lastPathComponent) }
    }

    /// Read contents of current log file
    public func readCurrentLog() -> String? {
        try? String(contentsOf: currentLogFileURL(), encoding: .utf8)
    }

    /// Get logs directory URL (for export functionality)
    public func logsDirectoryURL() -> URL {
        logsDirectory
    }
}
