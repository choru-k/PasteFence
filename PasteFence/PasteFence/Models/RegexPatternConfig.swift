import Foundation

/// Category grouping for regex patterns
enum PatternCategory: String, Codable, CaseIterable, Identifiable {
    case pii = "PII"
    case financial = "Financial"
    case auth = "Auth"
    case cloudApi = "Cloud/API"
    case infrastructure = "Infrastructure"
    case custom = "Custom"

    var id: String { rawValue }

    /// Human-readable display name for the category
    var displayName: String {
        switch self {
        case .pii: return "Personal Information"
        case .financial: return "Financial"
        case .auth: return "Authentication"
        case .cloudApi: return "Cloud & API Keys"
        case .infrastructure: return "Infrastructure"
        case .custom: return "Custom Patterns"
        }
    }

    /// SF Symbol name for the category icon
    var iconName: String {
        switch self {
        case .pii: return "person.fill"
        case .financial: return "creditcard.fill"
        case .auth: return "key.fill"
        case .cloudApi: return "cloud.fill"
        case .infrastructure: return "server.rack"
        case .custom: return "plus.square.fill"
        }
    }
}

/// Configuration for a single regex pattern (built-in or custom)
struct RegexPatternConfig: Codable, Identifiable, Equatable {
    /// Unique identifier
    let id: UUID

    /// Display name (e.g., "Email Address")
    let name: String

    /// Human-readable description of what this pattern detects
    let description: String

    /// Example text that matches this pattern (for UI display)
    let examples: String

    /// The regex pattern string
    let pattern: String

    /// Maps to SensitiveType.rawValue (e.g., "EMAIL", "CUSTOM_PROJECT_ID")
    let sensitiveType: String

    /// Category for grouping in UI
    let category: PatternCategory

    /// Detection confidence level (0.0 - 1.0)
    let confidence: Double

    /// Whether this is a built-in pattern (cannot be deleted)
    let isBuiltIn: Bool

    /// Whether this pattern is currently enabled for detection
    var isEnabled: Bool

    /// When the pattern was created
    let createdAt: Date

    /// When the pattern was last modified
    var modifiedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        examples: String = "",
        pattern: String,
        sensitiveType: String,
        category: PatternCategory,
        confidence: Double = 1.0,
        isBuiltIn: Bool = false,
        isEnabled: Bool = true,
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.examples = examples
        self.pattern = pattern
        self.sensitiveType = sensitiveType
        self.category = category
        self.confidence = confidence
        self.isBuiltIn = isBuiltIn
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    /// Validates that the regex pattern compiles successfully
    var isValidRegex: Bool {
        do {
            _ = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            return true
        } catch {
            return false
        }
    }

    /// Creates compiled regex (returns nil if pattern is invalid)
    func compiledRegex() -> NSRegularExpression? {
        try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }

    /// Creates a custom pattern with generated sensitive type
    static func createCustom(
        name: String,
        description: String = "",
        examples: String = "",
        pattern: String,
        maskLabel: String,
        confidence: Double = 1.0
    ) -> RegexPatternConfig {
        RegexPatternConfig(
            name: name,
            description: description,
            examples: examples,
            pattern: pattern,
            sensitiveType: "CUSTOM_\(maskLabel.uppercased())",
            category: .custom,
            confidence: confidence,
            isBuiltIn: false,
            isEnabled: true
        )
    }
}

/// State for category-level toggle (tracks user preference)
struct CategoryToggleState: Codable, Equatable {
    var isEnabled: Bool = true
}
