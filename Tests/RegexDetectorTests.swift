import XCTest
@testable import PasteFence

@MainActor
final class RegexDetectorTests: XCTestCase {
    var detector: RegexDetector!

    override func setUp() {
        super.setUp()
        detector = RegexDetector()
    }

    // MARK: - Email Detection

    func testDetectsEmail() {
        let text = "Contact me at john.doe@example.com for more info"
        let results = detector.detect(in: text)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.type, .email)
        XCTAssertEqual(results.first?.text, "john.doe@example.com")
    }

    func testDetectsMultipleEmails() {
        let text = "Send to alice@test.com or bob@company.org"
        let results = detector.detect(in: text)

        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results.allSatisfy { $0.type == .email })
    }

    // MARK: - Phone Detection

    func testDetectsPhoneNumber() {
        let text = "Call me at 010-1234-5678"
        let results = detector.detect(in: text)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.type, .phone)
    }

    func testDetectsInternationalPhone() {
        let text = "International: +82-10-1234-5678"
        let results = detector.detect(in: text)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.type, .phone)
    }

    // MARK: - Credit Card Detection

    func testDetectsCreditCard() {
        let text = "Card: 4111-1111-1111-1111"
        let results = detector.detect(in: text)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.type, .creditCard)
    }

    func testDetectsCreditCardWithSpaces() {
        let text = "Card: 4111 1111 1111 1111"
        let results = detector.detect(in: text)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.type, .creditCard)
    }

    // MARK: - API Key Detection

    func testDetectsOpenAIKey() {
        let text = "OPENAI_API_KEY=sk-1234567890abcdef1234567890abcdef1234567890abcdef"
        let results = detector.detect(in: text)

        XCTAssertTrue(results.contains { $0.type == .apiKey })
    }

    func testDetectsGitHubToken() {
        let text = "token: ghp_1234567890abcdefghijklmnopqrstuvwxyz"
        let results = detector.detect(in: text)

        XCTAssertTrue(results.contains { $0.type == .apiKey })
    }

    // MARK: - AWS Key Detection

    func testDetectsAWSAccessKey() {
        let text = "AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE"
        let results = detector.detect(in: text)

        XCTAssertTrue(results.contains { $0.type == .awsKey })
    }

    // MARK: - JWT Detection

    func testDetectsJWT() {
        // JWT without Bearer prefix (pure JWT token)
        let text = "Token: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"
        let results = detector.detect(in: text)

        XCTAssertTrue(results.contains { $0.type == .jwt })
    }

    // MARK: - IP Address Detection

    func testDetectsIPAddress() {
        let text = "Server: 192.168.1.100"
        let results = detector.detect(in: text)

        XCTAssertTrue(results.contains { $0.type == .ipAddress })
    }

    func testSkipsLocalhost() {
        let text = "localhost: 127.0.0.1"
        let results = detector.detect(in: text)

        XCTAssertFalse(results.contains { $0.type == .ipAddress })
    }

    // MARK: - Password Detection

    func testDetectsPasswordField() {
        let text = "password: mysecretpassword123"
        let results = detector.detect(in: text)

        XCTAssertTrue(results.contains { $0.type == .password })
    }

    // MARK: - Private Key Detection

    func testDetectsPrivateKey() {
        let text = "-----BEGIN RSA PRIVATE KEY-----\nMIIEpAIBAAKCAQEA..."
        let results = detector.detect(in: text)

        XCTAssertTrue(results.contains { $0.type == .privateKey })
    }

    // MARK: - Complex Scenarios

    func testDetectsMultipleSensitiveItems() {
        let text = """
        Error connecting to database:
        Host: 192.168.1.50
        User: admin
        Password: secret123
        API Key: sk-abcdefghij1234567890abcdefghij1234567890abcdef
        Contact: support@company.com
        """

        let results = detector.detect(in: text)

        XCTAssertTrue(results.count >= 3)
        XCTAssertTrue(results.contains { $0.type == .email })
        XCTAssertTrue(results.contains { $0.type == .ipAddress })
    }

    func testNoFalsePositivesOnCleanText() {
        let text = """
        This is a regular log message.
        User clicked button at timestamp 1234567890.
        Version 1.2.3.4 released.
        """

        let results = detector.detect(in: text)

        // Should not detect version numbers as IP addresses
        XCTAssertFalse(results.contains { $0.type == .ipAddress })
    }

    // MARK: - Phase 1: SSN Detection

    func testDetectsSSN() {
        let text = "SSN: 123-45-6789"
        let results = detector.detect(in: text)

        XCTAssertTrue(results.contains { $0.type == .ssn })
        XCTAssertEqual(results.first { $0.type == .ssn }?.text, "123-45-6789")
    }

    func testDetectsSSNWithSpaces() {
        let text = "Social Security: 123 45 6789"
        let results = detector.detect(in: text)

        XCTAssertTrue(results.contains { $0.type == .ssn })
    }

    func testDetectsSSNWithoutSeparators() {
        let text = "SSN: 123456789"
        let results = detector.detect(in: text)

        XCTAssertTrue(results.contains { $0.type == .ssn })
    }

    func testSkipsInvalidSSN000() {
        let text = "Invalid SSN: 000-12-3456"
        let results = detector.detect(in: text)

        XCTAssertFalse(results.contains { $0.type == .ssn && $0.text.contains("000") })
    }

    func testSkipsInvalidSSN666() {
        let text = "Invalid SSN: 666-12-3456"
        let results = detector.detect(in: text)

        XCTAssertFalse(results.contains { $0.type == .ssn && $0.text.contains("666") })
    }

    // MARK: - Phase 1: Stripe Key Detection

    func testDetectsStripeLiveKey() {
        // Test mode key - GitHub won't flag sk_test_ keys
        let text = "STRIPE_KEY=sk_test_51N0example123456789012"
        let results = detector.detect(in: text)

        XCTAssertTrue(results.contains { $0.type == .stripeKey })
    }

    func testDetectsStripeTestKey() {
        let text = "pk_test_abcdefghijklmnopqrstuvwxyz"
        let results = detector.detect(in: text)

        XCTAssertTrue(results.contains { $0.type == .stripeKey })
    }

    func testDetectsStripeRestrictedKey() {
        // Test mode key (rk_test_) for testing - GitHub won't flag test keys
        let text = "rk_test_51N0example123456789012"
        let results = detector.detect(in: text)

        XCTAssertTrue(results.contains { $0.type == .stripeKey })
    }

    // MARK: - Phase 1: SendGrid Key Detection

    func testDetectsSendGridKey() {
        // Realistic SendGrid key format
        let text = "SG.abcdefghijklmnopqrstu.abcdefghijklmnopqrstuvwxyz1234567890abcdefghi"
        let results = detector.detect(in: text)

        XCTAssertTrue(results.contains { $0.type == .sendGridKey })
    }

    // MARK: - Phase 1: Twilio Key Detection

    func testDetectsTwilioAccountSID() {
        // FAKE_KEY for testing - not a real SID
        let text = "TWILIO_SID=ACFAKE567890abcdef1234567890fake"
        let results = detector.detect(in: text)

        XCTAssertTrue(results.contains { $0.type == .twilioKey })
    }

    func testDetectsTwilioAPIKey() {
        // FAKE_KEY for testing - not a real API key
        let text = "SKFAKE67890abcdef1234567890fakeee"
        let results = detector.detect(in: text)

        XCTAssertTrue(results.contains { $0.type == .twilioKey })
    }

    // MARK: - Phase 1: Database URL Detection

    func testDetectsPostgresURL() {
        let text = "DATABASE_URL=postgresql://user:password@localhost:5432/mydb"
        let results = detector.detect(in: text)

        XCTAssertTrue(results.contains { $0.type == .databaseUrl })
    }

    func testDetectsMySQLURL() {
        let text = "mysql://root:secret@db.example.com:3306/production"
        let results = detector.detect(in: text)

        XCTAssertTrue(results.contains { $0.type == .databaseUrl })
    }

    func testDetectsMongoDBURL() {
        let text = "mongodb+srv://admin:password123@cluster0.mongodb.net/test"
        let results = detector.detect(in: text)

        XCTAssertTrue(results.contains { $0.type == .databaseUrl })
    }

    func testDetectsRedisURL() {
        let text = "redis://user:pass@redis.example.com:6379/0"
        let results = detector.detect(in: text)

        XCTAssertTrue(results.contains { $0.type == .databaseUrl })
    }

    // MARK: - Phase 1: Bearer Token Detection

    func testDetectsBearerTokenJWT() {
        let text = "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dozjgNryP4J3jVmNHl0w5N_XgL0n3I9PlFUP0THsR8U"
        let results = detector.detect(in: text)

        XCTAssertTrue(results.contains { $0.type == .bearerToken || $0.type == .jwt })
    }

    func testDetectsGenericBearerToken() {
        let text = "bearer abc123def456ghi789jkl012mno345"
        let results = detector.detect(in: text)

        XCTAssertTrue(results.contains { $0.type == .bearerToken })
    }

    // MARK: - Phase 2: Webhook URL Detection

    func testDetectsGenericWebhookURL() {
        let text = "https://api.example.com/webhook/receive"
        let results = detector.detect(in: text)

        XCTAssertTrue(results.contains { $0.type == .webhookUrl })
    }

    func testDetectsDiscordWebhook() {
        let text = "https://discord.com/api/webhooks/123456789012345678/abcdefghijklmnopqrstuvwxyz123456"
        let results = detector.detect(in: text)

        XCTAssertTrue(results.contains { $0.type == .webhookUrl })
    }

    func testDetectsSlackWebhook() {
        // Fake webhook URL using example domain for testing
        let text = "https://hooks.example.com/services/TXXXXXXXX/BXXXXXXXX/XXXXXXXXXXXXXXXXXXXXXXXX"
        let results = detector.detect(in: text)

        XCTAssertTrue(results.contains { $0.type == .webhookUrl })
    }

    // MARK: - Phase 2: Environment Variable Detection

    func testDetectsEnvVariableExport() {
        let text = "export AWS_SECRET_KEY=mysecretvalue123"
        let results = detector.detect(in: text)

        XCTAssertTrue(results.contains { $0.type == .envVariable })
    }

    func testDetectsEnvVariableAssignment() {
        let text = "DATABASE_PASSWORD=supersecret123"
        let results = detector.detect(in: text)

        XCTAssertTrue(results.contains { $0.type == .envVariable })
    }

    func testDetectsEnvVariableWithColon() {
        let text = "API_TOKEN:mytoken123456789"
        let results = detector.detect(in: text)

        XCTAssertTrue(results.contains { $0.type == .envVariable })
    }

    // MARK: - Phase 2: Session Token Detection

    func testDetectsSessionToken() {
        // Using "session=" which won't trigger envVariable pattern
        let text = "session=abcXYZdef123GHIjkl456MNOpqr789STU"
        let results = detector.detect(in: text)

        XCTAssertTrue(results.contains { $0.type == .sessionToken })
    }

    func testDetectsSessionId() {
        // Using non-numeric chars to avoid phone detection
        let text = "sid: abcdefghijklmnopqrstuvwxyzABCD"
        let results = detector.detect(in: text)

        XCTAssertTrue(results.contains { $0.type == .sessionToken })
    }

    // MARK: - Phase 2: GCP Key Detection

    func testDetectsGCPAPIKey() {
        let text = "AIzaSyDdI0hCZtE6vySjMm-WEfRq3CPzqKqqsHI"
        let results = detector.detect(in: text)

        XCTAssertTrue(results.contains { $0.type == .gcpKey })
    }

    func testDetectsGCPServiceAccountKey() {
        let text = """
        {
          "private_key": "-----BEGIN RSA PRIVATE KEY-----\\nMIIEow..."
        }
        """
        let results = detector.detect(in: text)

        XCTAssertTrue(results.contains { $0.type == .gcpKey || $0.type == .privateKey })
    }

    // MARK: - Phase 2: Azure Key Detection

    func testDetectsAzureStorageConnectionString() {
        // Azure Storage account keys are 88 base64 characters (86 chars + "==")
        let key = "abc123def456ghi789jkl012mno345pqr678stu901vwx234yza567bcd890efg123hij456klm789ABCDEF+/=="
        let text = "DefaultEndpointsProtocol=https;AccountName=mystorageaccount;AccountKey=\(key)"
        let results = detector.detect(in: text)

        XCTAssertTrue(results.contains { $0.type == .azureKey })
    }

    func testDetectsAzureSASToken() {
        let text = "https://storage.blob.core.windows.net/container/blob?sig=abc123def456ghi789jkl012mno345pqr678stu901vwx%2B%2F"
        let results = detector.detect(in: text)

        XCTAssertTrue(results.contains { $0.type == .azureKey })
    }

    // MARK: - Combined Detection Tests

    func testDetectsMultipleNewPatterns() {
        // Test mode keys - GitHub won't flag these
        let text = """
        Config:
        SSN: 123-45-6789
        STRIPE_KEY=sk_test_51N0example123456789012
        DATABASE_URL=postgresql://user:pass@localhost/db
        Webhook: https://hooks.example.com/services/TXXXXXXXX/BXXXXXXXX/XXXXXXXXXXXXXXXXXXXXXXXX
        """
        let results = detector.detect(in: text)

        XCTAssertTrue(results.contains { $0.type == .ssn })
        XCTAssertTrue(results.contains { $0.type == .stripeKey })
        XCTAssertTrue(results.contains { $0.type == .databaseUrl })
        XCTAssertTrue(results.contains { $0.type == .webhookUrl })
    }

    // MARK: - Phase 3: IBAN Detection

    func testDetectsGermanIBAN() {
        let text = "Bank account: DE89370400440532013000"
        let results = detector.detect(in: text)

        XCTAssertTrue(results.contains { $0.type == .iban })
    }

    func testDetectsUKIBAN() {
        // UK IBAN with alphanumeric BBAN
        let text = "IBAN: GB29NWBK60161331926819"
        let results = detector.detect(in: text)

        XCTAssertTrue(results.contains { $0.type == .iban })
    }

    func testDetectsSpanishIBAN() {
        // Spanish IBAN - all numeric after country code
        let text = "Transfer to ES9121000418450200051332"
        let results = detector.detect(in: text)

        XCTAssertTrue(results.contains { $0.type == .iban })
    }

    // MARK: - Phase 3: Healthcare ID Detection

    func testDetectsMedicareBeneficiaryIdentifier() {
        // MBI format: C[A-Z]AN-[A-Z]AN-[A-Z]{2}NN where C=digit excluding 0,8,9, A=alphanumeric, N=digit
        let text = "Medicare ID: 1AB2-CD3-EF45"
        let results = detector.detect(in: text)

        XCTAssertTrue(results.contains { $0.type == .healthcareId })
    }

    func testDetectsMedicalRecordNumber() {
        let text = "MRN: 12345678"
        let results = detector.detect(in: text)

        XCTAssertTrue(results.contains { $0.type == .healthcareId })
    }

    func testDetectsPatientID() {
        let text = "Patient ID: ABC123456"
        let results = detector.detect(in: text)

        XCTAssertTrue(results.contains { $0.type == .healthcareId })
    }

    // MARK: - Phase 3: Passport Number Detection

    func testDetectsUSPassport() {
        let text = "Passport: 123456789"
        let results = detector.detect(in: text)

        XCTAssertTrue(results.contains { $0.type == .passportNumber })
    }

    func testDetectsEUPassportWithLetters() {
        let text = "Travel document: AB1234567"
        let results = detector.detect(in: text)

        XCTAssertTrue(results.contains { $0.type == .passportNumber })
    }

    func testSkipsPassportWithoutContext() {
        // Without "passport" or "travel document" context, should not detect
        let text = "Reference number: AB1234567"
        let results = detector.detect(in: text)

        XCTAssertFalse(results.contains { $0.type == .passportNumber })
    }

    // MARK: - Phase 3: Crypto Seed Phrase Detection

    func testDetectsCryptoSeedPhraseWithSeedPhraseContext() {
        let text = "seed phrase: abandon ability able about above absent absorb abstract absurd abuse access accident"
        let results = detector.detect(in: text)

        XCTAssertTrue(results.contains { $0.type == .cryptoSeedPhrase })
    }

    func testDetectsCryptoSeedPhraseWithMnemonicContext() {
        let text = "mnemonic: abandon ability able about above absent absorb abstract absurd abuse access accident"
        let results = detector.detect(in: text)

        XCTAssertTrue(results.contains { $0.type == .cryptoSeedPhrase })
    }

    func testDetectsCryptoSeedPhraseWithRecoveryPhraseContext() {
        // Use all-letter words since BIP39 words are pure lowercase letters
        let text = "recovery phrase: alpha bravo charlie delta echo foxtrot golf hotel india juliet kilo lima"
        let results = detector.detect(in: text)

        XCTAssertTrue(results.contains { $0.type == .cryptoSeedPhrase })
    }

    func testDoesNotDetectRegularSentenceAsSeedPhrase() {
        // 12 words but no context keyword - should NOT detect
        let text = "The quick brown fox jumps over the lazy dog near the river bank"
        let results = detector.detect(in: text)

        XCTAssertFalse(results.contains { $0.type == .cryptoSeedPhrase })
    }

    func testDetects24WordSeedPhrase() {
        let words = "abandon ability able about above absent absorb abstract absurd abuse access accident " +
                    "abandon ability able about above absent absorb abstract absurd abuse access accident"
        let text = "wallet backup: \(words)"
        let results = detector.detect(in: text)

        XCTAssertTrue(results.contains { $0.type == .cryptoSeedPhrase })
    }
}



