import Foundation
import Combine

/// Manages prompt rules with UserDefaults persistence
/// Includes built-in rules and custom user-defined rules
@MainActor
final class PromptRulesManager: ObservableObject {
    // MARK: - Shared Instance

    static let shared = PromptRulesManager()

    // MARK: - Published Properties

    @Published private(set) var rules: [PromptRule] = []

    // MARK: - Constants

    private let storageKey = "com.pastefence.promptRules"
    private let hasInitializedKey = "com.pastefence.promptRulesInitialized"

    // MARK: - Initialization

    init() {
        loadRules()
        if !UserDefaults.standard.bool(forKey: hasInitializedKey) {
            initializeBuiltInRules()
            UserDefaults.standard.set(true, forKey: hasInitializedKey)
        }
    }
}

// MARK: - Built-in Rule Definitions

extension PromptRulesManager {
    /// Built-in prompt rule definitions extracted from LLMDetector system prompt
    /// Format: (name, description, patternExamples, maskLabel)
    private static let builtInRuleDefinitions: [(name: String, description: String, patternExamples: String, maskLabel: String)] = [
        (
            "Private Key",
            "PEM format private keys for cryptographic operations",
            "-----BEGIN RSA PRIVATE KEY-----, -----BEGIN EC PRIVATE KEY-----, -----BEGIN PRIVATE KEY-----, -----BEGIN OPENSSH PRIVATE KEY-----",
            "PRIVATE_KEY"
        ),
        (
            "API Key",
            "API keys from various services",
            "OpenAI: sk-..., GitHub: ghp_/gho_/ghu_..., Slack: xoxb-/xoxp-/xoxa-..., GCP: AIza..., Stripe: sk_live_/pk_live_/sk_test_/rk_live_..., Twilio: SK..., SendGrid: SG....",
            "API_KEY"
        ),
        (
            "AWS Key",
            "AWS access keys and secret access keys",
            "AKIA..., ASIA..., aws_secret_access_key=...",
            "AWS_KEY"
        ),
        (
            "Password",
            "Passwords in common configuration formats",
            "Text after password:, passwd:, pwd:, secret:",
            "PASSWORD"
        ),
        (
            "JWT Token",
            "JSON Web Tokens for authentication",
            "eyJ... (base64 tokens with header.payload.signature format)",
            "JWT"
        ),
        (
            "Secret",
            "Generic secrets, tokens, and credentials",
            "Azure connection strings: DefaultEndpointsProtocol=..., Database URLs: mongodb://, postgres://, mysql:// with credentials",
            "SECRET"
        ),
        (
            "Email",
            "Email addresses",
            "Standard email format: user@domain.com",
            "EMAIL"
        ),
        (
            "Phone",
            "Phone numbers in various formats",
            "International: +1-234-567-8900, Local: (123) 456-7890",
            "PHONE"
        ),
        (
            "IP Address",
            "IPv4 addresses",
            "192.168.1.1, 10.0.0.1 (excluding localhost and common ranges)",
            "IP_ADDRESS"
        ),
        (
            "Credit Card",
            "Credit card numbers",
            "16-digit card numbers with optional separators: 1234-5678-9012-3456",
            "CREDIT_CARD"
        ),
    ]
}

// MARK: - Toggle Operations

extension PromptRulesManager {
    /// Toggles the enabled state of a single rule
    func toggleRule(id: UUID) {
        guard let index = rules.firstIndex(where: { $0.id == id }) else { return }
        rules[index].isEnabled.toggle()
        rules[index].modifiedAt = Date()
        saveRules()
    }
}

// MARK: - Custom Rule CRUD

extension PromptRulesManager {
    /// Adds a new custom rule
    func addRule(_ rule: PromptRule) {
        rules.append(rule)
        saveRules()
    }

    /// Updates an existing rule
    func updateRule(_ rule: PromptRule) {
        guard let index = rules.firstIndex(where: { $0.id == rule.id }) else { return }
        var updated = rule
        updated.modifiedAt = Date()
        rules[index] = updated
        saveRules()
    }

    /// Deletes a rule by ID (only custom rules can be deleted)
    func deleteRule(id: UUID) {
        rules.removeAll { $0.id == id && !$0.isBuiltIn }
        saveRules()
    }

    /// Reorders rules (for drag-and-drop in UI)
    func moveRules(from source: IndexSet, to destination: Int) {
        rules.move(fromOffsets: source, toOffset: destination)
        saveRules()
    }
}

// MARK: - Query Methods

extension PromptRulesManager {
    /// Returns all enabled rules
    var enabledRules: [PromptRule] {
        rules.filter { $0.isEnabled }
    }

    /// Returns only built-in rules
    var builtInRules: [PromptRule] {
        rules.filter { $0.isBuiltIn }
    }

    /// Returns only custom (user-created) rules
    var customRules: [PromptRule] {
        rules.filter { !$0.isBuiltIn }
    }

    /// Returns the list of type identifiers for enabled rules
    var enabledTypes: [String] {
        rules.filter { $0.isEnabled }.map { $0.sensitiveType }
    }

    /// Builds instructions string for all enabled rules (for LLM prompt)
    func buildPromptInstructions() -> String? {
        let enabled = enabledRules
        guard !enabled.isEmpty else { return nil }

        var instructions = "Pattern Examples:\n"

        for rule in enabled where !rule.patternExamples.isEmpty {
            instructions += "- \(rule.maskLabel): \(rule.patternExamples)\n"
        }

        // Add custom rule descriptions
        let customEnabled = enabled.filter { !$0.isBuiltIn }
        if !customEnabled.isEmpty {
            instructions += "\nADDITIONAL DETECTION RULES:\n"
            for (index, rule) in customEnabled.enumerated() {
                let examplesText = rule.examples.isEmpty
                    ? ""
                    : " Examples: \(rule.examples.joined(separator: ", "))"
                instructions += "\(index + 1). [\(rule.name)]: \(rule.description).\(examplesText)\n"
            }
        }

        return instructions
    }
}

// MARK: - Persistence

extension PromptRulesManager {
    private func loadRules() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            rules = []
            return
        }

        do {
            rules = try JSONDecoder().decode([PromptRule].self, from: data)
        } catch {
            print("[PromptRulesManager] Failed to decode rules: \(error)")
            rules = []
        }
    }

    private func saveRules() {
        do {
            let data = try JSONEncoder().encode(rules)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("[PromptRulesManager] Failed to encode rules: \(error)")
        }
    }

    private func initializeBuiltInRules() {
        let builtIn = Self.builtInRuleDefinitions.map { def in
            PromptRule(
                name: def.name,
                description: def.description,
                patternExamples: def.patternExamples,
                examples: [],
                maskLabel: def.maskLabel,
                isBuiltIn: true,
                isEnabled: true
            )
        }
        rules = builtIn + rules.filter { !$0.isBuiltIn } // Preserve custom rules
        saveRules()
    }

    /// Resets all rules to default state
    func resetToDefaults() {
        UserDefaults.standard.removeObject(forKey: hasInitializedKey)
        UserDefaults.standard.removeObject(forKey: storageKey)
        rules = []
        initializeBuiltInRules()
        UserDefaults.standard.set(true, forKey: hasInitializedKey)
    }
}

// MARK: - Debug/Testing

#if DEBUG
extension PromptRulesManager {
    /// Clears all rules (for testing)
    func clearAllRules() {
        rules = []
        saveRules()
    }

    /// Re-initializes built-in rules (for testing)
    func reinitializeBuiltInRules() {
        initializeBuiltInRules()
    }

    /// Adds sample custom rules (for testing)
    func addSampleRules() {
        let samples = [
            PromptRule(
                name: "Project Codenames",
                description: "Detect internal project names and codenames used within the company",
                patternExamples: "",
                examples: ["Phoenix", "Atlas", "Titan-2024"],
                maskLabel: "PROJECT",
                isBuiltIn: false
            ),
            PromptRule(
                name: "Employee IDs",
                description: "Detect employee identification numbers",
                patternExamples: "",
                examples: ["EMP-123456", "EMP-789012"],
                maskLabel: "EMPLOYEE_ID",
                isBuiltIn: false
            )
        ]
        rules.append(contentsOf: samples)
        saveRules()
    }
}
#endif
