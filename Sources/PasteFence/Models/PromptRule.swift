import Foundation

/// A rule for detecting sensitive data via LLM prompts
/// Can be built-in (system-defined) or custom (user-defined)
struct PromptRule: Codable, Identifiable, Equatable {
    /// Unique identifier
    let id: UUID

    /// Display name (e.g., "API Key", "Private Key")
    var name: String

    /// Description for LLM prompt (e.g., "Detect API keys from various services")
    var description: String

    /// Pattern examples shown to LLM and in UI (e.g., "OpenAI: sk-..., GitHub: ghp_...")
    var patternExamples: String

    /// User-provided example values for custom rules (e.g., ["Phoenix", "Atlas"])
    var examples: [String]

    /// Label used for masking output (e.g., "API_KEY" -> [API_KEY_MASKED])
    var maskLabel: String

    /// Whether this is a built-in (system) rule
    let isBuiltIn: Bool

    /// Whether this rule is currently active
    var isEnabled: Bool

    /// When the rule was created
    let createdAt: Date

    /// When the rule was last modified
    var modifiedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        description: String,
        patternExamples: String = "",
        examples: [String] = [],
        maskLabel: String,
        isBuiltIn: Bool = false,
        isEnabled: Bool = true,
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.patternExamples = patternExamples
        self.examples = examples
        self.maskLabel = maskLabel
        self.isBuiltIn = isBuiltIn
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    /// Generates the sensitive type string (e.g., "API_KEY" or "CUSTOM_PROJECT")
    var sensitiveType: String {
        if isBuiltIn {
            return maskLabel.uppercased()
        } else {
            return "CUSTOM_\(maskLabel.uppercased())"
        }
    }

    /// Validates that the rule has minimum required fields
    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !description.trimmingCharacters(in: .whitespaces).isEmpty &&
        !maskLabel.trimmingCharacters(in: .whitespaces).isEmpty
    }
}
