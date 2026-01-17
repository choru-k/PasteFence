import Foundation

/// Result of masking operation
struct MaskingResult {
    let originalText: String
    let maskedText: String
    let detectedItems: [DetectedItem]
    let processingTime: TimeInterval
}

/// Represents a detected sensitive item
struct DetectedItem: Identifiable, Hashable {
    let id = UUID()
    let text: String
    let type: SensitiveType
    let range: Range<String.Index>
    let confidence: Double
    let source: DetectionSource
    let ruleName: String?  // Rule name for regex detections, nil for LLM

    enum DetectionSource {
        case regex
        case llm
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: DetectedItem, rhs: DetectedItem) -> Bool {
        lhs.id == rhs.id
    }
}

/// Types of sensitive information
enum SensitiveType: Codable, Equatable, Hashable {
    case email
    case phone
    case creditCard
    case apiKey
    case jwt
    case ipAddress
    case password
    case privateKey
    case awsKey
    case genericSecret

    // Phase 1: Financial & Communication Services
    case ssn
    case stripeKey
    case sendGridKey
    case twilioKey
    case databaseUrl
    case bearerToken

    // Phase 2: Infrastructure & Cloud
    case webhookUrl
    case envVariable
    case sessionToken
    case gcpKey
    case azureKey

    // Phase 3: Specialized Patterns
    case iban
    case healthcareId
    case passportNumber
    case cryptoSeedPhrase

    // Custom user-defined types
    case custom(String)

    // MARK: - Raw Value Support

    var rawValue: String {
        switch self {
        case .email: return "EMAIL"
        case .phone: return "PHONE"
        case .creditCard: return "CREDIT_CARD"
        case .apiKey: return "API_KEY"
        case .jwt: return "JWT"
        case .ipAddress: return "IP_ADDRESS"
        case .password: return "PASSWORD"
        case .privateKey: return "PRIVATE_KEY"
        case .awsKey: return "AWS_KEY"
        case .genericSecret: return "SECRET"
        case .ssn: return "SSN"
        case .stripeKey: return "STRIPE_KEY"
        case .sendGridKey: return "SENDGRID_KEY"
        case .twilioKey: return "TWILIO_KEY"
        case .databaseUrl: return "DATABASE_URL"
        case .bearerToken: return "BEARER_TOKEN"
        case .webhookUrl: return "WEBHOOK_URL"
        case .envVariable: return "ENV_VARIABLE"
        case .sessionToken: return "SESSION_TOKEN"
        case .gcpKey: return "GCP_KEY"
        case .azureKey: return "AZURE_KEY"
        case .iban: return "IBAN"
        case .healthcareId: return "HEALTHCARE_ID"
        case .passportNumber: return "PASSPORT"
        case .cryptoSeedPhrase: return "CRYPTO_SEED_PHRASE"
        case .custom(let type): return type
        }
    }

    init?(rawValue: String) {
        switch rawValue.uppercased() {
        case "EMAIL": self = .email
        case "PHONE": self = .phone
        case "CREDIT_CARD": self = .creditCard
        case "API_KEY": self = .apiKey
        case "JWT": self = .jwt
        case "IP_ADDRESS": self = .ipAddress
        case "PASSWORD": self = .password
        case "PRIVATE_KEY": self = .privateKey
        case "AWS_KEY": self = .awsKey
        case "SECRET": self = .genericSecret
        case "SSN": self = .ssn
        case "STRIPE_KEY": self = .stripeKey
        case "SENDGRID_KEY": self = .sendGridKey
        case "TWILIO_KEY": self = .twilioKey
        case "DATABASE_URL": self = .databaseUrl
        case "BEARER_TOKEN": self = .bearerToken
        case "WEBHOOK_URL": self = .webhookUrl
        case "ENV_VARIABLE": self = .envVariable
        case "SESSION_TOKEN": self = .sessionToken
        case "GCP_KEY": self = .gcpKey
        case "AZURE_KEY": self = .azureKey
        case "IBAN": self = .iban
        case "HEALTHCARE_ID": self = .healthcareId
        case "PASSPORT": self = .passportNumber
        case "CRYPTO_SEED_PHRASE": self = .cryptoSeedPhrase
        default:
            // Accept custom types with CUSTOM_ prefix
            if rawValue.uppercased().hasPrefix("CUSTOM_") {
                self = .custom(rawValue.uppercased())
            } else {
                return nil
            }
        }
    }

    // MARK: - Display & Masking

    var displayName: String {
        switch self {
        case .email: return "Email"
        case .phone: return "Phone"
        case .creditCard: return "Credit Card"
        case .apiKey: return "API Key"
        case .jwt: return "JWT Token"
        case .ipAddress: return "IP Address"
        case .password: return "Password"
        case .privateKey: return "Private Key"
        case .awsKey: return "AWS Key"
        case .genericSecret: return "Secret"
        case .ssn: return "SSN"
        case .stripeKey: return "Stripe Key"
        case .sendGridKey: return "SendGrid Key"
        case .twilioKey: return "Twilio Key"
        case .databaseUrl: return "Database URL"
        case .bearerToken: return "Bearer Token"
        case .webhookUrl: return "Webhook URL"
        case .envVariable: return "Env Variable"
        case .sessionToken: return "Session Token"
        case .gcpKey: return "GCP Key"
        case .azureKey: return "Azure Key"
        case .iban: return "IBAN"
        case .healthcareId: return "Healthcare ID"
        case .passportNumber: return "Passport"
        case .cryptoSeedPhrase: return "Crypto Seed Phrase"
        case .custom(let type):
            // CUSTOM_PROJECT → "Project"
            return type.replacingOccurrences(of: "CUSTOM_", with: "")
                .split(separator: "_")
                .map { $0.capitalized }
                .joined(separator: " ")
        }
    }

    var maskLabel: String {
        "[\(rawValue)_MASKED]"
    }

    // MARK: - CaseIterable (built-in types only)

    static var allBuiltInCases: [SensitiveType] {
        [
            .email, .phone, .creditCard, .apiKey, .jwt, .ipAddress,
            .password, .privateKey, .awsKey, .genericSecret,
            .ssn, .stripeKey, .sendGridKey, .twilioKey, .databaseUrl, .bearerToken,
            .webhookUrl, .envVariable, .sessionToken, .gcpKey, .azureKey,
            .iban, .healthcareId, .passportNumber, .cryptoSeedPhrase
        ]
    }

    // MARK: - Codable

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)

        if let type = SensitiveType(rawValue: value) {
            self = type
        } else {
            // Unknown types default to genericSecret
            self = .genericSecret
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// Engine that combines regex and LLM detection for masking sensitive data
actor MaskingEngine {
    private let regexDetector: RegexDetector
    private var llmDetector: LLMDetector?

    /// Initialize with optional regex patterns manager
    /// - Parameter patternsManager: Manager providing dynamic enabled patterns (nil uses hardcoded fallback)
    /// - Note: Must be called on MainActor because RegexDetector caches patterns from the manager
    @MainActor
    init(patternsManager: RegexPatternsManager? = nil) {
        self.regexDetector = RegexDetector(patternsManager: patternsManager)
        // LLM detector will be initialized lazily when model is loaded
    }

    /// Initialize LLM detector with specified model
    func initializeLLM(modelPath: String) async throws {
        self.llmDetector = try await LLMDetector(modelPath: modelPath)
    }

    /// Release the LLM detector (for memory pressure or model change)
    func releaseLLM() {
        self.llmDetector = nil
    }

    /// Check if LLM detector is initialized and ready
    var isLLMReady: Bool {
        llmDetector != nil
    }

    /// Mask sensitive information in the given text
    func mask(text: String) async throws -> MaskingResult {
        let startTime = Date()

        // Stage 1: Regex detection (fast, deterministic)
        var detectedItems = regexDetector.detect(in: text)
        print("[MaskingEngine] Regex detected \(detectedItems.count) items")

        // Stage 2: LLM detection (if available)
        if let llmDetector = llmDetector {
            do {
                let llmItems = try await llmDetector.detect(in: text)
                // Merge LLM results, avoiding duplicates
                let merged = mergeDetections(regex: detectedItems, llm: llmItems)
                detectedItems = merged
                print("[MaskingEngine] LLM detected \(llmItems.count) additional items")
            } catch {
                print("[MaskingEngine] LLM detection failed: \(error), using regex only")
            }
        }

        // Apply masking
        let maskedText = applyMasking(to: text, items: detectedItems)

        let processingTime = Date().timeIntervalSince(startTime)
        print("[MaskingEngine] Processed in \(String(format: "%.2f", processingTime * 1000))ms")

        return MaskingResult(
            originalText: text,
            maskedText: maskedText,
            detectedItems: detectedItems,
            processingTime: processingTime
        )
    }

    private func mergeDetections(regex: [DetectedItem], llm: [DetectedItem]) -> [DetectedItem] {
        var result = regex

        for llmItem in llm {
            // Check if this range overlaps with any regex detection
            let overlaps = regex.contains { regexItem in
                regexItem.range.overlaps(llmItem.range)
            }

            if !overlaps {
                result.append(llmItem)
            }
        }

        // Sort by position for consistent masking
        return result.sorted { $0.range.lowerBound < $1.range.lowerBound }
    }

    private func applyMasking(to text: String, items: [DetectedItem]) -> String {
        guard !items.isEmpty else { return text }

        var result = text
        // Apply in reverse order to preserve indices
        for item in items.reversed() {
            result.replaceSubrange(item.range, with: item.type.maskLabel)
        }

        return result
    }
}
