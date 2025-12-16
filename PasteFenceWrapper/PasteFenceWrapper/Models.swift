import Foundation

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
