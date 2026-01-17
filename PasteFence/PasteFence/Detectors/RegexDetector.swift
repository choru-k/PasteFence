import Foundation

/// Regex-based detector for common PII patterns
/// Fast (~1ms) and deterministic detection
final class RegexDetector {

    // MARK: - Regex Patterns

    private struct Pattern {
        let regex: NSRegularExpression
        let type: SensitiveType
        let confidence: Double
        let name: String  // Rule name for display in preview

        init(_ pattern: String, type: SensitiveType, confidence: Double = 1.0, name: String = "") {
            // Force try is safe here as patterns are compile-time constants
            self.regex = try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            self.type = type
            self.confidence = confidence
            self.name = name
        }

        /// Initialize from a RegexPatternConfig (for dynamic patterns)
        init?(config: RegexPatternConfig) {
            guard let regex = config.compiledRegex() else { return nil }
            self.regex = regex
            self.type = SensitiveType(rawValue: config.sensitiveType) ?? .genericSecret
            self.confidence = config.confidence
            self.name = config.name  // Get name from config
        }
    }

    // MARK: - Properties

    /// Cached patterns for detection (snapshot at init time)
    private let cachedPatterns: [Pattern]?

    // MARK: - Initialization

    /// Initialize with optional patterns manager
    /// - Parameter patternsManager: Manager providing dynamic enabled patterns (nil uses hardcoded fallback)
    /// - Note: Patterns are snapshot at init time. Create a new RegexDetector to pick up pattern changes.
    @MainActor
    init(patternsManager: RegexPatternsManager? = nil) {
        if let manager = patternsManager {
            self.cachedPatterns = manager.enabledPatterns.compactMap { Pattern(config: $0) }
        } else {
            self.cachedPatterns = nil
        }
    }

    // MARK: - Active Patterns

    /// Returns patterns to use for detection
    /// Uses cached patterns from manager if available, otherwise falls back to hardcoded patterns
    private var activePatterns: [Pattern] {
        cachedPatterns ?? fallbackPatterns
    }

    // MARK: - Fallback Patterns (Hardcoded)

    private let fallbackPatterns: [Pattern] = [
        // Email - RFC 5322 simplified
        Pattern(
            #"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"#,
            type: .email
        ),

        // Credit card numbers (with optional separators) - MUST be before phone
        Pattern(
            #"\b\d{4}[-\s]?\d{4}[-\s]?\d{4}[-\s]?\d{4}\b"#,
            type: .creditCard
        ),

        // Phone numbers (International)
        // Word boundaries prevent matching digits inside API keys/tokens
        Pattern(
            #"\b(?:\+\d{1,3}[-.\s]?)?\(?\d{2,4}\)?[-.\s]?\d{3,4}[-.\s]?\d{4}\b"#,
            type: .phone
        ),

        // JWT tokens
        Pattern(
            #"eyJ[a-zA-Z0-9_-]+\.eyJ[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+"#,
            type: .jwt
        ),

        // IPv4 addresses
        Pattern(
            #"\b(?:25[0-5]|2[0-4]\d|1\d{2}|[1-9]?\d)(?:\.(?:25[0-5]|2[0-4]\d|1\d{2}|[1-9]?\d)){3}\b"#,
            type: .ipAddress
        ),

        // AWS Access Key ID
        Pattern(
            #"\b(?:AKIA|ABIA|ACCA|ASIA)[0-9A-Z]{16}\b"#,
            type: .awsKey
        ),

        // AWS Secret Access Key (40 character base64)
        Pattern(
            #"(?<![A-Za-z0-9/+=])[A-Za-z0-9/+=]{40}(?![A-Za-z0-9/+=])"#,
            type: .awsKey,
            confidence: 0.7  // Lower confidence as it may have false positives
        ),

        // Generic API Keys (common patterns)
        Pattern(
            #"\b(?:sk|pk|api|key|token|secret|auth)[-_]?(?:live|test|prod)?[-_]?[a-zA-Z0-9]{20,}"#,
            type: .apiKey,
            confidence: 0.9
        ),

        // OpenAI API Key
        Pattern(
            #"\bsk-[a-zA-Z0-9]{48}\b"#,
            type: .apiKey
        ),

        // GitHub tokens
        Pattern(
            #"\b(?:ghp|gho|ghu|ghs|ghr)_[a-zA-Z0-9]{36}\b"#,
            type: .apiKey
        ),

        // Slack tokens
        Pattern(
            #"\bxox[baprs]-[0-9]{10,13}-[0-9]{10,13}-[a-zA-Z0-9]{24}\b"#,
            type: .apiKey
        ),

        // Private keys (PEM format)
        Pattern(
            #"-----BEGIN (?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----"#,
            type: .privateKey
        ),

        // Password in common formats
        // Uses fixed-length lookbehind (NSRegularExpression doesn't support variable-length)
        // Covers: "password: value", "password:value", "password=value", "password= value"
        Pattern(
            #"(?<=password: )[^\s]+"#,
            type: .password,
            confidence: 0.8
        ),
        Pattern(
            #"(?<=password:)[^\s]+"#,
            type: .password,
            confidence: 0.8
        ),
        Pattern(
            #"(?<=password=)[^\s]+"#,
            type: .password,
            confidence: 0.8
        ),
        Pattern(
            #"(?<=passwd: )[^\s]+"#,
            type: .password,
            confidence: 0.8
        ),
        Pattern(
            #"(?<=passwd:)[^\s]+"#,
            type: .password,
            confidence: 0.8
        ),
        Pattern(
            #"(?<=pwd: )[^\s]+"#,
            type: .password,
            confidence: 0.8
        ),
        Pattern(
            #"(?<=pwd:)[^\s]+"#,
            type: .password,
            confidence: 0.8
        ),

        // MARK: - Phase 1: Financial & Communication Services

        // US Social Security Number (SSN)
        Pattern(
            #"\b\d{3}[-\s]?\d{2}[-\s]?\d{4}\b"#,
            type: .ssn,
            confidence: 0.9
        ),

        // Stripe API Keys (sk_live_, sk_test_, pk_live_, pk_test_, rk_live_, rk_test_)
        Pattern(
            #"\b(?:sk|pk|rk)_(?:live|test)_[a-zA-Z0-9]{24,}\b"#,
            type: .stripeKey
        ),

        // SendGrid API Key (SG.xxxx - variable length segments, typically ~22 and ~43 chars)
        Pattern(
            #"\bSG\.[a-zA-Z0-9_-]{15,}\.[a-zA-Z0-9_-]{30,}\b"#,
            type: .sendGridKey
        ),

        // Twilio Account SID and Auth Token
        Pattern(
            #"\b(?:AC|SK)[a-f0-9]{32}\b"#,
            type: .twilioKey
        ),

        // Database Connection Strings (PostgreSQL, MySQL, MongoDB, Redis)
        // High confidence - database URLs are distinctive and should take precedence
        Pattern(
            #"(?:postgres(?:ql)?|mysql|mongodb(?:\+srv)?|redis(?:s)?)://[^\s\"'<>]+"#,
            type: .databaseUrl,
            confidence: 1.0
        ),

        // Bearer Token in Authorization headers
        Pattern(
            #"[Bb]earer\s+[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+"#,
            type: .bearerToken
        ),

        // Generic Bearer token (without JWT structure)
        Pattern(
            #"[Bb]earer\s+[a-zA-Z0-9_-]{20,}"#,
            type: .bearerToken,
            confidence: 0.8
        ),

        // MARK: - Phase 2: Infrastructure & Cloud

        // Webhook URLs (common patterns)
        Pattern(
            #"https?://[^\s\"'<>]*(?:webhook|hook|callback|notify)[^\s\"'<>]*"#,
            type: .webhookUrl,
            confidence: 0.85
        ),

        // Discord Webhook
        Pattern(
            #"https://discord(?:app)?\.com/api/webhooks/\d+/[a-zA-Z0-9_-]+"#,
            type: .webhookUrl
        ),

        // Slack Webhook
        Pattern(
            #"https://hooks\.slack\.com/services/T[A-Z0-9]+/B[A-Z0-9]+/[a-zA-Z0-9]+"#,
            type: .webhookUrl
        ),

        // Environment variable assignments (KEY=value format in shell/env files)
        Pattern(
            #"(?:^|\n|\s)(?:export\s+)?[A-Z][A-Z0-9_]*(?:_KEY|_SECRET|_TOKEN|_PASSWORD|_API|_CREDENTIAL)[=:][^\s\n]+"#,
            type: .envVariable,
            confidence: 0.85
        ),

        // Session tokens (common patterns - key=value or key: value format)
        Pattern(
            #"(?:session|sess|sid)[_-]?(?:id|token)?\s*[:=]\s*[a-zA-Z0-9_-]{20,}"#,
            type: .sessionToken,
            confidence: 0.8
        ),

        // Google Cloud Platform API Key
        Pattern(
            #"\bAIza[a-zA-Z0-9_-]{35}\b"#,
            type: .gcpKey
        ),

        // Google Cloud Service Account (JSON key file pattern)
        Pattern(
            #"\"private_key\":\s*\"-----BEGIN (?:RSA )?PRIVATE KEY-----"#,
            type: .gcpKey
        ),

        // Azure Storage Connection String
        Pattern(
            #"DefaultEndpointsProtocol=https?;AccountName=[^;]+;AccountKey=[a-zA-Z0-9+/=]{88}"#,
            type: .azureKey
        ),

        // Azure SAS Token
        Pattern(
            #"[?&]sig=[a-zA-Z0-9%+/=]{43,}"#,
            type: .azureKey,
            confidence: 0.85
        ),

        // MARK: - Phase 3: Specialized Patterns

        // IBAN (International Bank Account Number)
        // Format: 2 letter country code + 2 check digits + up to 30 alphanumeric BBAN
        // High confidence - very specific pattern, should win over phone numbers
        Pattern(
            #"\b[A-Z]{2}\d{2}[A-Z0-9]{4,30}\b"#,
            type: .iban,
            confidence: 1.0
        ),

        // Healthcare IDs - Medicare Beneficiary Identifier (MBI) format
        // Format: 1[A-Z]C-[A-Z]C-[A-Z]{2}CC where C is digit
        Pattern(
            #"\b\d[A-Z][A-Z0-9]\d-[A-Z][A-Z0-9]\d-[A-Z]{2}\d{2}\b"#,
            type: .healthcareId
        ),

        // Healthcare IDs - Medical Record Number (MRN) with context
        Pattern(
            #"(?:MRN|Medical Record|Patient ID|Chart)[\s:]+[A-Z0-9]{6,12}\b"#,
            type: .healthcareId,
            confidence: 0.85
        ),

        // Passport numbers with context (reduces false positives)
        // US passports: 9 digits, UK: 9 digits, EU: varies but often letter(s) + digits
        // High confidence since context is required - should win over IBAN for overlaps
        Pattern(
            #"(?:[Pp]assport|[Tt]ravel [Dd]ocument)[\s:#]+[A-Z]{0,2}\d{6,9}\b"#,
            type: .passportNumber,
            confidence: 1.0
        ),

        // BIP39 Crypto Seed Phrases (context-required to minimize false positives)
        // Only matches when preceded by keywords like "seed phrase", "mnemonic", etc.
        // Matches 12-24 space-separated lowercase words after context
        Pattern(
            #"(?:seed\s*phrase|mnemonic|recovery\s*phrase|wallet\s*backup|backup\s*phrase)[:\s]+(?:[a-z]+\s+){11,23}[a-z]+"#,
            type: .cryptoSeedPhrase,
            confidence: 0.9
        ),
    ]

    // MARK: - Detection

    func detect(in text: String) -> [DetectedItem] {
        var results: [DetectedItem] = []
        let nsRange = NSRange(text.startIndex..., in: text)

        for pattern in activePatterns {
            let matches = pattern.regex.matches(in: text, options: [], range: nsRange)

            for match in matches {
                guard let range = Range(match.range, in: text) else { continue }

                let matchedText = String(text[range])

                // Skip if it looks like a false positive
                if shouldSkip(matchedText, type: pattern.type) {
                    continue
                }

                let item = DetectedItem(
                    text: matchedText,
                    type: pattern.type,
                    range: range,
                    confidence: pattern.confidence,
                    source: .regex,
                    ruleName: pattern.name
                )
                results.append(item)
            }
        }

        // Remove overlapping detections, prefer higher confidence
        return removeOverlaps(results)
    }

    // MARK: - Helpers

    private func shouldSkip(_ text: String, type: SensitiveType) -> Bool {
        switch type {
        case .phone:
            // Skip if it's too short or looks like a version number
            if text.filter({ $0.isNumber }).count < 10 {
                return true
            }
            if text.contains(".") && !text.contains("-") {
                return true  // Likely version number like 1.2.3.4
            }

        case .ipAddress:
            // Skip localhost and common private ranges that might be intentional
            let commonIPs = ["127.0.0.1", "0.0.0.0", "255.255.255.255"]
            if commonIPs.contains(text) {
                return true
            }
            // Skip version numbers (all octets are small numbers like 1.2.3.4)
            let octets = text.split(separator: ".").compactMap { Int($0) }
            if octets.count == 4 && octets.allSatisfy({ $0 < 20 }) {
                return true
            }

        case .awsKey:
            // Skip if it's in a common code pattern context
            if text.count != 40 && !text.hasPrefix("AKIA") {
                return true
            }

        case .ssn:
            // Skip invalid SSN formats (first 3 digits cannot be 000, 666, or 900-999)
            let digits = text.filter { $0.isNumber }
            if digits.count == 9 {
                let areaNumber = Int(digits.prefix(3)) ?? 0
                if areaNumber == 0 || areaNumber == 666 || areaNumber >= 900 {
                    return true
                }
                // Skip if middle group is 00 or last group is 0000
                let groupNumber = Int(digits.dropFirst(3).prefix(2)) ?? 0
                let serialNumber = Int(digits.suffix(4)) ?? 0
                if groupNumber == 0 || serialNumber == 0 {
                    return true
                }
            }

        case .envVariable:
            // Skip if it looks like a shell comment or commonly safe patterns
            if text.trimmingCharacters(in: .whitespaces).hasPrefix("#") {
                return true
            }

        default:
            break
        }

        return false
    }

    private func removeOverlaps(_ items: [DetectedItem]) -> [DetectedItem] {
        guard items.count > 1 else { return items }

        let sorted = items.sorted { $0.range.lowerBound < $1.range.lowerBound }
        var result: [DetectedItem] = []

        for item in sorted {
            if let last = result.last, last.range.overlaps(item.range) {
                // Prefer higher confidence, or longer match if equal confidence
                let lastLength = last.text.count
                let itemLength = item.text.count

                if item.confidence > last.confidence ||
                   (item.confidence == last.confidence && itemLength > lastLength) {
                    result.removeLast()
                    result.append(item)
                }
            } else {
                result.append(item)
            }
        }

        return result
    }
}
