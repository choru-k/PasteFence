import Foundation
import Combine

/// Manages regex pattern configuration with UserDefaults persistence
@MainActor
final class RegexPatternsManager: ObservableObject {
    // MARK: - Shared Instance

    static let shared = RegexPatternsManager()

    // MARK: - Published Properties

    @Published private(set) var patterns: [RegexPatternConfig] = []

    // MARK: - Constants

    private let patternsStorageKey = "com.pastefence.regexPatterns"
    private let hasInitializedKey = "com.pastefence.regexPatternsInitialized"
    private let schemaVersionKey = "com.pastefence.regexPatternsSchemaVersion"

    /// Current schema version - increment when adding new fields to RegexPatternConfig
    private static let currentSchemaVersion = 2  // v2: Added description and examples fields

    // MARK: - Initialization

    init() {
        loadPatterns()
        let savedVersion = UserDefaults.standard.integer(forKey: schemaVersionKey)

        if !UserDefaults.standard.bool(forKey: hasInitializedKey) {
            // First time initialization
            initializeBuiltInPatterns()
            UserDefaults.standard.set(true, forKey: hasInitializedKey)
            UserDefaults.standard.set(Self.currentSchemaVersion, forKey: schemaVersionKey)
        } else if savedVersion < Self.currentSchemaVersion {
            // Schema upgrade - preserve custom patterns, reinitialize built-in
            migrateToCurrentSchema()
            UserDefaults.standard.set(Self.currentSchemaVersion, forKey: schemaVersionKey)
        }
    }

    /// Migrate patterns to current schema version
    /// Preserves custom patterns while updating built-in patterns with new fields
    private func migrateToCurrentSchema() {
        // Save custom patterns
        let customPatterns = patterns.filter { !$0.isBuiltIn }

        // Reinitialize built-in patterns with new schema
        let newBuiltInPatterns = Self.builtInPatternDefinitions.map { def in
            RegexPatternConfig(
                name: def.name,
                description: def.description,
                examples: def.examples,
                pattern: def.pattern,
                sensitiveType: def.type,
                category: def.category,
                confidence: def.confidence,
                isBuiltIn: true,
                isEnabled: true
            )
        }

        // Merge: new built-in + preserved custom
        patterns = newBuiltInPatterns + customPatterns
        savePatterns()
        print("[RegexPatternsManager] Migrated to schema version \(Self.currentSchemaVersion)")
    }
}

// MARK: - Built-in Pattern Definitions

extension RegexPatternsManager {
    /// Built-in pattern definitions extracted from RegexDetector
    /// Format: (name, description, examples, pattern, sensitiveType, category, confidence)
    private static let builtInPatternDefinitions: [(name: String, description: String, examples: String, pattern: String, type: String, category: PatternCategory, confidence: Double)] = [
        // MARK: PII
        (
            "Email",
            "Standard email addresses",
            "user@example.com, john.doe@company.org",
            #"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"#,
            "EMAIL", .pii, 0.9
        ),
        (
            "Phone Number",
            "Phone numbers in various formats",
            "+1-234-567-8900, (555) 123-4567, 010-1234-5678",
            #"\b(?:\+\d{1,3}[-.\s]?)?\(?\d{2,4}\)?[-.\s]?\d{3,4}[-.\s]?\d{4}\b"#,
            "PHONE", .pii, 0.8
        ),
        (
            "SSN (US)",
            "US Social Security Numbers",
            "123-45-6789, 123 45 6789",
            #"\b\d{3}[-\s]?\d{2}[-\s]?\d{4}\b"#,
            "SSN", .pii, 0.8
        ),
        (
            "Passport Number",
            "Passport and travel document numbers",
            "Passport: AB1234567, Travel Document: 123456789",
            #"(?:[Pp]assport|[Tt]ravel [Dd]ocument)[\s:#]+[A-Z]{0,2}\d{6,9}\b"#,
            "PASSPORT", .pii, 0.9
        ),
        (
            "Healthcare ID (MBI)",
            "Medicare Beneficiary Identifiers",
            "1EG4-TE5-MK72",
            #"\b\d[A-Z][A-Z0-9]\d-[A-Z][A-Z0-9]\d-[A-Z]{2}\d{2}\b"#,
            "HEALTHCARE_ID", .pii, 0.9
        ),
        (
            "Medical Record Number",
            "Medical record and patient IDs",
            "MRN: ABC123456, Patient ID: 789012",
            #"(?:MRN|Medical Record|Patient ID|Chart)[\s:]+[A-Z0-9]{6,12}\b"#,
            "HEALTHCARE_ID", .pii, 0.75
        ),

        // MARK: Financial
        (
            "Credit Card",
            "16-digit credit card numbers",
            "4111-1111-1111-1111, 5500 0000 0000 0004",
            #"\b\d{4}[-\s]?\d{4}[-\s]?\d{4}[-\s]?\d{4}\b"#,
            "CREDIT_CARD", .financial, 0.9
        ),
        (
            "IBAN",
            "International Bank Account Numbers",
            "DE89370400440532013000, GB82WEST12345698765432",
            #"\b[A-Z]{2}\d{2}[A-Z0-9]{4,30}\b"#,
            "IBAN", .financial, 0.9
        ),
        (
            "Stripe API Key",
            "Stripe payment platform API keys",
            "sk_live_abc123..., pk_test_xyz789...",
            #"\b(?:sk|pk|rk)_(?:live|test)_[a-zA-Z0-9]{24,}\b"#,
            "STRIPE_KEY", .financial, 0.9
        ),
        (
            "Crypto Seed Phrase",
            "Cryptocurrency wallet recovery phrases",
            "seed phrase: abandon ability able about above...",
            #"(?:seed\s*phrase|mnemonic|recovery\s*phrase|wallet\s*backup|backup\s*phrase)[:\s]+(?:[a-z]+\s+){11,23}[a-z]+"#,
            "CRYPTO_SEED", .financial, 0.8
        ),

        // MARK: Auth
        (
            "JWT Token",
            "JSON Web Tokens for authentication",
            "eyJhbGciOiJIUzI1NiIs...",
            #"eyJ[a-zA-Z0-9_-]+\.eyJ[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+"#,
            "JWT", .auth, 0.9
        ),
        (
            "Password (colon-space)",
            "Passwords after 'password: '",
            "password: mysecret123",
            #"(?<=password: )[^\s]+"#,
            "PASSWORD", .auth, 0.7
        ),
        (
            "Password (colon)",
            "Passwords after 'password:'",
            "password:mysecret123",
            #"(?<=password:)[^\s]+"#,
            "PASSWORD", .auth, 0.7
        ),
        (
            "Password (equals)",
            "Passwords after 'password='",
            "password=mysecret123",
            #"(?<=password=)[^\s]+"#,
            "PASSWORD", .auth, 0.7
        ),
        (
            "Passwd (colon-space)",
            "Passwords after 'passwd: '",
            "passwd: secret456",
            #"(?<=passwd: )[^\s]+"#,
            "PASSWORD", .auth, 0.7
        ),
        (
            "Passwd (colon)",
            "Passwords after 'passwd:'",
            "passwd:secret456",
            #"(?<=passwd:)[^\s]+"#,
            "PASSWORD", .auth, 0.7
        ),
        (
            "Pwd (colon-space)",
            "Passwords after 'pwd: '",
            "pwd: mypass789",
            #"(?<=pwd: )[^\s]+"#,
            "PASSWORD", .auth, 0.7
        ),
        (
            "Pwd (colon)",
            "Passwords after 'pwd:'",
            "pwd:mypass789",
            #"(?<=pwd:)[^\s]+"#,
            "PASSWORD", .auth, 0.7
        ),
        (
            "Bearer Token (JWT)",
            "Bearer authentication with JWT tokens",
            "Bearer eyJhbGciOi...",
            #"[Bb]earer\s+[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+"#,
            "BEARER_TOKEN", .auth, 0.9
        ),
        (
            "Bearer Token (Generic)",
            "Bearer authentication tokens",
            "Bearer abc123xyz789...",
            #"[Bb]earer\s+[a-zA-Z0-9_-]{20,}"#,
            "BEARER_TOKEN", .auth, 0.7
        ),
        (
            "Session Token",
            "Session identifiers and tokens",
            "session_id=abc123..., sid: xyz789...",
            #"(?:session|sess|sid)[_-]?(?:id|token)?\s*[:=]\s*[a-zA-Z0-9_-]{20,}"#,
            "SESSION_TOKEN", .auth, 0.7
        ),

        // MARK: Cloud/API
        (
            "AWS Access Key ID",
            "AWS access key identifiers",
            "AKIAIOSFODNN7EXAMPLE",
            #"\b(?:AKIA|ABIA|ACCA|ASIA)[0-9A-Z]{16}\b"#,
            "AWS_KEY", .cloudApi, 0.9
        ),
        (
            "AWS Secret Access Key",
            "AWS secret access keys (40 characters)",
            "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
            #"(?<![A-Za-z0-9/+=])[A-Za-z0-9/+=]{40}(?![A-Za-z0-9/+=])"#,
            "AWS_KEY", .cloudApi, 0.6
        ),
        (
            "Generic API Key",
            "Common API key formats",
            "api_key_abc123..., secret_live_xyz...",
            #"\b(?:sk|pk|api|key|token|secret|auth)[-_]?(?:live|test|prod)?[-_]?[a-zA-Z0-9]{20,}"#,
            "API_KEY", .cloudApi, 0.8
        ),
        (
            "OpenAI API Key",
            "OpenAI API keys",
            "sk-abcdefghijklmnopqrstuvwxyz123456789012345678",
            #"\bsk-[a-zA-Z0-9]{48}\b"#,
            "API_KEY", .cloudApi, 0.9
        ),
        (
            "GitHub Token",
            "GitHub personal access tokens",
            "ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
            #"\b(?:ghp|gho|ghu|ghs|ghr)_[a-zA-Z0-9]{36}\b"#,
            "API_KEY", .cloudApi, 0.9
        ),
        (
            "Slack Token",
            "Slack API tokens",
            "xoxb-123456789012-1234567890123-abc123...",
            #"\bxox[baprs]-[0-9]{10,13}-[0-9]{10,13}-[a-zA-Z0-9]{24}\b"#,
            "API_KEY", .cloudApi, 0.9
        ),
        (
            "SendGrid API Key",
            "SendGrid email service keys",
            "SG.abc123.xyz789...",
            #"\bSG\.[a-zA-Z0-9_-]{15,}\.[a-zA-Z0-9_-]{30,}\b"#,
            "SENDGRID_KEY", .cloudApi, 0.9
        ),
        (
            "Twilio Key",
            "Twilio communication keys",
            "ACabcdef0123456789..., SKabcdef0123456789...",
            #"\b(?:AC|SK)[a-f0-9]{32}\b"#,
            "TWILIO_KEY", .cloudApi, 0.9
        ),
        (
            "GCP API Key",
            "Google Cloud Platform keys",
            "AIzaSyABCDEFGHIJKLMNOPQRSTUVWXYZ12345",
            #"\bAIza[a-zA-Z0-9_-]{35}\b"#,
            "GCP_KEY", .cloudApi, 0.9
        ),
        (
            "GCP Service Account",
            "GCP service account private key in JSON",
            "\"private_key\": \"-----BEGIN PRIVATE KEY-----...",
            #"\"private_key\":\s*\"-----BEGIN (?:RSA )?PRIVATE KEY-----"#,
            "GCP_KEY", .cloudApi, 0.9
        ),
        (
            "Azure Storage Connection",
            "Azure storage connection strings",
            "DefaultEndpointsProtocol=https;AccountName=...",
            #"DefaultEndpointsProtocol=https?;AccountName=[^;]+;AccountKey=[a-zA-Z0-9+/=]{88}"#,
            "AZURE_KEY", .cloudApi, 0.9
        ),
        (
            "Azure SAS Token",
            "Azure Shared Access Signature tokens",
            "?sig=abc123..., &sig=xyz789...",
            #"[?&]sig=[a-zA-Z0-9%+/=]{43,}"#,
            "AZURE_KEY", .cloudApi, 0.75
        ),

        // MARK: Infrastructure
        (
            "IP Address",
            "IPv4 addresses (excludes localhost)",
            "192.168.1.100, 10.0.0.1",
            #"\b(?:25[0-5]|2[0-4]\d|1\d{2}|[1-9]?\d)(?:\.(?:25[0-5]|2[0-4]\d|1\d{2}|[1-9]?\d)){3}\b"#,
            "IP_ADDRESS", .infrastructure, 0.6
        ),
        (
            "Private Key (PEM)",
            "PEM format private keys",
            "-----BEGIN RSA PRIVATE KEY-----",
            #"-----BEGIN (?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----"#,
            "PRIVATE_KEY", .infrastructure, 0.9
        ),
        (
            "Database URL",
            "Database connection strings with credentials",
            "postgres://user:pass@host:5432/db",
            #"(?:postgres(?:ql)?|mysql|mongodb(?:\+srv)?|redis(?:s)?)://[^\s\"'<>]+"#,
            "DATABASE_URL", .infrastructure, 0.9
        ),
        (
            "Webhook URL (Generic)",
            "Webhook endpoints and callbacks",
            "https://example.com/webhook/callback",
            #"https?://[^\s\"'<>]*(?:webhook|hook|callback|notify)[^\s\"'<>]*"#,
            "WEBHOOK_URL", .infrastructure, 0.75
        ),
        (
            "Discord Webhook",
            "Discord webhook URLs",
            "https://discord.com/api/webhooks/123/abc...",
            #"https://discord(?:app)?\.com/api/webhooks/\d+/[a-zA-Z0-9_-]+"#,
            "WEBHOOK_URL", .infrastructure, 0.9
        ),
        (
            "Slack Webhook",
            "Slack incoming webhooks",
            "https://hooks.slack.com/services/T.../B.../...",
            #"https://hooks\.slack\.com/services/T[A-Z0-9]+/B[A-Z0-9]+/[a-zA-Z0-9]+"#,
            "WEBHOOK_URL", .infrastructure, 0.9
        ),
        (
            "Environment Variable",
            "Environment variables with secrets",
            "export API_KEY=abc123, DATABASE_PASSWORD=...",
            #"(?:^|\n|\s)(?:export\s+)?[A-Z][A-Z0-9_]*(?:_KEY|_SECRET|_TOKEN|_PASSWORD|_API|_CREDENTIAL)[=:][^\s\n]+"#,
            "ENV_VARIABLE", .infrastructure, 0.75
        ),
    ]
}

// MARK: - Toggle Operations

extension RegexPatternsManager {
    /// Toggles the enabled state of a single pattern
    func togglePattern(id: UUID) {
        guard let index = patterns.firstIndex(where: { $0.id == id }) else { return }
        patterns[index].isEnabled.toggle()
        patterns[index].modifiedAt = Date()
        savePatterns()
    }

    /// Toggles all patterns in a category
    func toggleCategory(_ category: PatternCategory) {
        let categoryPatterns = patterns.filter { $0.category == category }
        let allEnabled = categoryPatterns.allSatisfy { $0.isEnabled }
        let newState = !allEnabled

        for index in patterns.indices where patterns[index].category == category {
            patterns[index].isEnabled = newState
            patterns[index].modifiedAt = Date()
        }
        savePatterns()
    }
}

// MARK: - Custom Pattern CRUD

extension RegexPatternsManager {
    /// Adds a new custom pattern
    func addCustomPattern(_ config: RegexPatternConfig) {
        patterns.append(config)
        savePatterns()
    }

    /// Updates an existing pattern
    func updatePattern(_ config: RegexPatternConfig) {
        guard let index = patterns.firstIndex(where: { $0.id == config.id }) else { return }
        var updated = config
        updated.modifiedAt = Date()
        patterns[index] = updated
        savePatterns()
    }

    /// Deletes a pattern by ID (only custom patterns can be deleted)
    func deletePattern(id: UUID) {
        patterns.removeAll { $0.id == id && !$0.isBuiltIn }
        savePatterns()
    }
}

// MARK: - Query Methods

extension RegexPatternsManager {
    /// Returns all enabled patterns
    var enabledPatterns: [RegexPatternConfig] {
        patterns.filter { $0.isEnabled }
    }

    /// Returns only custom (user-created) patterns
    var customPatterns: [RegexPatternConfig] {
        patterns.filter { !$0.isBuiltIn }
    }

    /// Returns patterns for a specific category
    func patterns(for category: PatternCategory) -> [RegexPatternConfig] {
        patterns.filter { $0.category == category }
    }

    /// Checks if all patterns in a category are enabled
    func isCategoryEnabled(_ category: PatternCategory) -> Bool {
        let categoryPatterns = patterns.filter { $0.category == category }
        return !categoryPatterns.isEmpty && categoryPatterns.allSatisfy { $0.isEnabled }
    }

    /// Checks if some (but not all) patterns in a category are enabled
    func isCategoryPartiallyEnabled(_ category: PatternCategory) -> Bool {
        let categoryPatterns = patterns.filter { $0.category == category }
        let enabledCount = categoryPatterns.filter { $0.isEnabled }.count
        return enabledCount > 0 && enabledCount < categoryPatterns.count
    }

    /// Returns the count of enabled patterns in a category
    func enabledCount(for category: PatternCategory) -> Int {
        patterns.filter { $0.category == category && $0.isEnabled }.count
    }

    /// Returns the total count of patterns in a category
    func totalCount(for category: PatternCategory) -> Int {
        patterns.filter { $0.category == category }.count
    }
}

// MARK: - Persistence

extension RegexPatternsManager {
    private func loadPatterns() {
        guard let data = UserDefaults.standard.data(forKey: patternsStorageKey) else {
            patterns = []
            return
        }

        do {
            patterns = try JSONDecoder().decode([RegexPatternConfig].self, from: data)
        } catch {
            print("[RegexPatternsManager] Failed to decode patterns: \(error)")
            patterns = []
        }
    }

    private func savePatterns() {
        do {
            let data = try JSONEncoder().encode(patterns)
            UserDefaults.standard.set(data, forKey: patternsStorageKey)
        } catch {
            print("[RegexPatternsManager] Failed to encode patterns: \(error)")
        }
    }

    private func initializeBuiltInPatterns() {
        patterns = Self.builtInPatternDefinitions.map { def in
            RegexPatternConfig(
                name: def.name,
                description: def.description,
                examples: def.examples,
                pattern: def.pattern,
                sensitiveType: def.type,
                category: def.category,
                confidence: def.confidence,
                isBuiltIn: true,
                isEnabled: true
            )
        }
        savePatterns()
    }

    /// Resets all patterns to default state
    func resetToDefaults() {
        UserDefaults.standard.removeObject(forKey: hasInitializedKey)
        UserDefaults.standard.removeObject(forKey: patternsStorageKey)
        patterns = []
        initializeBuiltInPatterns()
        UserDefaults.standard.set(true, forKey: hasInitializedKey)
    }
}

// MARK: - Debug/Testing

#if DEBUG
extension RegexPatternsManager {
    /// Clears all patterns (for testing)
    func clearAllPatterns() {
        patterns = []
        savePatterns()
    }

    /// Re-initializes built-in patterns (for testing)
    func reinitializeBuiltInPatterns() {
        initializeBuiltInPatterns()
    }
}
#endif
