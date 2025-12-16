import XCTest
@testable import PasteFence

// MARK: - Integration Test Helpers

/// Shared utilities for integration tests
struct IntegrationTestHelpers {

    // MARK: - PII Generators

    /// Generate a valid email address
    static func randomEmail(index: Int = 0) -> String {
        "user\(index)@domain\(index).com"
    }

    /// Generate a valid US phone number
    static func randomPhone(index: Int = 0) -> String {
        let area = 200 + (index % 800)
        let exchange = 200 + (index % 800)
        let subscriber = 1000 + (index % 9000)
        return "\(area)-\(exchange)-\(subscriber)"
    }

    /// Generate a valid Korean phone number
    static func randomKoreanPhone(index: Int = 0) -> String {
        let middle = 1000 + (index % 9000)
        let last = 1000 + (index % 9000)
        return "010-\(middle)-\(last)"
    }

    /// Generate a valid credit card number (Visa test number)
    static func randomCreditCard(index: Int = 0) -> String {
        "4111-1111-1111-\(1111 + (index % 8888))"
    }

    /// Generate a valid Amex card number (15 digits)
    static func randomAmexCard(index: Int = 0) -> String {
        "3782-822463-1000\(index % 9)"
    }

    /// Generate a valid Mastercard number
    static func randomMasterCard(index: Int = 0) -> String {
        "5500-0000-0000-\(String(format: "%04d", index % 10000))"
    }

    /// Generate a valid UK phone number
    static func randomUKPhone(index: Int = 0) -> String {
        let middle = 7946 + (index % 100)
        let last = 1000 + (index % 9000)
        return "+44-20-\(middle)-\(last)"
    }

    /// Generate a valid international phone number (E.164 format)
    static func randomInternationalPhone(index: Int = 0) -> String {
        let countryCodes = ["+1", "+44", "+49", "+33", "+81"]
        let code = countryCodes[index % countryCodes.count]
        let number = 1000000000 + (index * 1234567) % 9000000000
        return "\(code)-\(number)"
    }

    /// Generate a valid SSN
    static func randomSSN(index: Int = 0) -> String {
        let area = 100 + (index % 565)  // Valid range, excluding 000, 666
        let group = 10 + (index % 89)
        let serial = 1000 + (index % 8999)
        return "\(area)-\(group)-\(serial)"
    }

    /// Generate an OpenAI-style API key
    static func randomAPIKey(index: Int = 0) -> String {
        let suffix = String(format: "%048d", index).suffix(48)
        return "sk-\(suffix)"
    }

    /// Generate an AWS access key
    static func randomAWSKey(index: Int = 0) -> String {
        let suffix = String(format: "%016d", index).suffix(16)
        return "AKIA\(suffix)"
    }

    /// Generate a GitHub token
    static func randomGitHubToken(index: Int = 0) -> String {
        let chars = "0123456789abcdefghijklmnopqrstuvwxyz"
        let suffix = (0..<36).map { _ in chars.randomElement()! }
        return "ghp_\(String(suffix))"
    }

    /// Generate a valid JWT token
    static func randomJWT(index: Int = 0) -> String {
        let header = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
        let payload = "eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IlVzZXIgXChpbmRleCkiLCJpYXQiOjE1MTYyMzkwMjJ9"
        let signature = "SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"
        return "\(header).\(payload).\(signature)"
    }

    /// Generate a valid IP address (non-localhost)
    static func randomIPAddress(index: Int = 0) -> String {
        let octet1 = 10 + (index % 200)  // Avoid 127.x.x.x and other special ranges
        let octet2 = (index / 200) % 256
        let octet3 = (index / 50000) % 256
        let octet4 = 1 + (index % 254)
        return "\(octet1).\(octet2).\(octet3).\(octet4)"
    }

    /// Generate a password pattern
    static func randomPassword(index: Int = 0) -> String {
        "password=SecretPass\(index)!"
    }

    /// Generate a Stripe test key
    static func randomStripeKey(index: Int = 0) -> String {
        let suffix = String(repeating: "x", count: 20)
        return "sk_test_51N0\(suffix)\(index)"
    }

    /// Generate a webhook URL (using example domain)
    static func randomWebhookURL(index: Int = 0) -> String {
        "https://hooks.example.com/services/TXXXX\(index)/BXXXX\(index)/XXXXXXXX"
    }

    /// Generate a database URL
    static func randomDatabaseURL(index: Int = 0) -> String {
        "postgresql://user\(index):pass\(index)@db.example.com:5432/database\(index)"
    }

    // MARK: - Text Generators

    /// Generate text with many PII items of mixed types
    static func generateTextWithManyPII(count: Int, types: [SensitiveType] = [.email, .phone, .creditCard, .apiKey, .ipAddress]) -> String {
        var lines: [String] = []
        for i in 0..<count {
            let type = types[i % types.count]
            let line = generatePIILine(for: type, index: i)
            lines.append(line)
        }
        return lines.joined(separator: "\n")
    }

    /// Generate a single line with PII
    private static func generatePIILine(for type: SensitiveType, index: Int) -> String {
        switch type {
        case .email:
            return "Contact \(index): Email is \(randomEmail(index: index))"
        case .phone:
            return "Contact \(index): Phone is \(randomPhone(index: index))"
        case .creditCard:
            return "Payment \(index): Card \(randomCreditCard(index: index))"
        case .ssn:
            return "Record \(index): SSN \(randomSSN(index: index))"
        case .apiKey:
            return "Config \(index): API_KEY=\(randomAPIKey(index: index))"
        case .awsKey:
            return "Config \(index): AWS_KEY=\(randomAWSKey(index: index))"
        case .jwt:
            return "Token \(index): \(randomJWT(index: index))"
        case .ipAddress:
            return "Server \(index): IP \(randomIPAddress(index: index))"
        case .password:
            return "Login \(index): \(randomPassword(index: index))"
        default:
            return "Data \(index): secret_value_\(index)"
        }
    }

    /// Generate long text with PII at specific density
    /// - Parameters:
    ///   - length: Target length in characters
    ///   - piiDensity: Number of PII items per 1000 characters
    /// - Returns: Text with embedded PII
    static func generateLongText(length: Int, piiDensity: Double = 1.0) -> String {
        let piiCount = max(1, Int(Double(length) / 1000.0 * piiDensity))
        let piiInterval = length / piiCount

        var result = ""
        var piiIndex = 0

        while result.count < length {
            // Add filler text
            let fillerNeeded = min(piiInterval - 100, length - result.count)
            if fillerNeeded > 0 {
                result += String(repeating: "Lorem ipsum dolor sit amet. ", count: max(1, fillerNeeded / 30))
            }

            // Add PII if we haven't exceeded target length
            if result.count < length {
                let types: [SensitiveType] = [.email, .phone, .creditCard, .apiKey, .ipAddress]
                result += "\n" + generatePIILine(for: types[piiIndex % types.count], index: piiIndex) + "\n"
                piiIndex += 1
            }
        }

        // Trim to exact length
        if result.count > length {
            result = String(result.prefix(length))
        }

        return result
    }

    /// Generate text with PII at specific offset (for chunk boundary testing)
    static func generateChunkBoundaryText(piiAtOffset: Int, piiType: SensitiveType = .email) -> String {
        let chunkSize = LLMDetectorTestHelper.chunkSize
        let overlap = LLMDetectorTestHelper.chunkOverlap

        // Create text with PII at the specified offset
        let preText = String(repeating: "x", count: piiAtOffset)
        let pii: String

        switch piiType {
        case .email:
            pii = "boundary@test.com"
        case .phone:
            pii = "555-123-4567"
        case .creditCard:
            pii = "4111-1111-1111-1111"
        case .jwt:
            pii = randomJWT(index: 0)
        default:
            pii = "test@example.com"
        }

        // Add enough text after PII to trigger chunking
        let postText = String(repeating: "y", count: chunkSize)

        return preText + pii + postText
    }

    // MARK: - Assertion Helpers

    /// Assert that results contain a specific PII type
    static func assertContains(results: [DetectedItem], type: SensitiveType, message: String = "") {
        XCTAssertTrue(
            results.contains { $0.type == type },
            "Expected to find \(type) in results. \(message)"
        )
    }

    /// Assert that results do NOT contain a specific PII type
    static func assertNotContains(results: [DetectedItem], type: SensitiveType, message: String = "") {
        XCTAssertFalse(
            results.contains { $0.type == type },
            "Expected NOT to find \(type) in results. \(message)"
        )
    }

    /// Assert detection count for a specific type
    static func assertCount(results: [DetectedItem], type: SensitiveType, expected: Int, message: String = "") {
        let count = results.filter { $0.type == type }.count
        XCTAssertEqual(
            count, expected,
            "Expected \(expected) \(type) detections, got \(count). \(message)"
        )
    }
}

// MARK: - Real-World Document Templates

extension IntegrationTestHelpers {

    /// Corporate email thread with signatures
    static let emailThread = """
        From: John Smith <john.smith@acme-corp.com>
        To: Jane Doe <jane.doe@partner.org>
        CC: support@acme-corp.com
        Subject: Q4 Budget Review
        Date: December 15, 2024

        Hi Jane,

        Please find attached the Q4 budget proposal. Let me know if you have questions.

        Best regards,
        John Smith
        Senior Manager, Finance
        ACME Corporation
        Phone: +1 (555) 234-5678
        Mobile: 555-987-6543
        Email: john.smith@acme-corp.com

        ---

        > On Dec 14, 2024, Jane Doe <jane.doe@partner.org> wrote:
        > Hi John,
        > Could you send over the Q4 numbers?
        >
        > Thanks,
        > Jane
        > Phone: (555) 111-2222
        """

    /// Apache access log entries
    static let apacheAccessLog = """
        192.168.1.105 - - [15/Dec/2024:10:15:32 +0000] "GET /api/users HTTP/1.1" 200 1234
        10.0.0.45 - user@example.com [15/Dec/2024:10:15:33 +0000] "POST /login HTTP/1.1" 302 0
        172.16.0.100 - - [15/Dec/2024:10:15:34 +0000] "GET /static/logo.png HTTP/1.1" 200 5678
        192.168.1.200 - admin@company.org [15/Dec/2024:10:15:35 +0000] "DELETE /api/users/123 HTTP/1.1" 204 0
        10.255.255.1 - - [15/Dec/2024:10:15:36 +0000] "GET /health HTTP/1.1" 200 2
        """

    /// Application error log with secrets
    static let appErrorLog = """
        2024-12-15 10:15:32 [ERROR] Database connection failed
        2024-12-15 10:15:32 [DEBUG] Connection string: postgresql://admin:secretpass123@db.example.com:5432/production
        2024-12-15 10:15:33 [ERROR] API call failed to external service
        2024-12-15 10:15:33 [DEBUG] Using API key: sk-1234567890abcdef1234567890abcdef1234567890abcdef
        2024-12-15 10:15:34 [WARN] JWT token expired
        2024-12-15 10:15:34 [DEBUG] Token: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c
        2024-12-15 10:15:35 [INFO] Server started on 192.168.1.10:8080
        """

    /// .env file with secrets
    static let envFile = """
        # Database
        DATABASE_URL=postgresql://admin:secretpass123@db.example.com:5432/production
        REDIS_URL=redis://:password@cache.example.com:6379

        # API Keys (test mode keys for CI)
        OPENAI_API_KEY=sk-proj-example1234567890abcdefghijklmnopqrst
        STRIPE_SECRET_KEY=sk_test_51N0example123456789012
        GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

        # AWS (example keys from AWS docs)
        AWS_ACCESS_KEY_ID=AKIAEXAMPLEEXAMPLE1
        AWS_SECRET_ACCESS_KEY=exampleXUtnFEMI/K7MDENG/bPxRfiCYexampleKEY

        # Slack (example webhook)
        SLACK_WEBHOOK_URL=https://hooks.example.com/services/TXXXXXXXX/BXXXXXXXX/XXXXXXXXXXXXXXXXXXXXXXXX

        # Admin
        ADMIN_PASSWORD=SuperSecret123!
        """

    /// Docker Compose with secrets
    static let dockerCompose = """
        version: '3.8'
        services:
          app:
            image: myapp:latest
            environment:
              - DATABASE_URL=postgresql://admin:secretpass123@db:5432/app
              - API_KEY=sk-1234567890abcdef1234567890abcdef1234567890abcdef
              - JWT_SECRET=my-super-secret-jwt-key-123
          db:
            image: postgres:14
            environment:
              - POSTGRES_PASSWORD=secretpass123
              - POSTGRES_USER=admin
        """

    /// Python code with embedded secrets
    static let pythonCode = """
        import requests

        # Configuration
        API_KEY = "sk-1234567890abcdef1234567890abcdef1234567890abcdef"
        DATABASE_URL = "postgresql://admin:password123@localhost:5432/mydb"

        def send_notification(email):
            slack_webhook = "https://hooks.example.com/services/TXXXXXXXX/BXXXXXXXX/XXXXXXXX"
            requests.post(slack_webhook, json={"text": f"New user: {email}"})

        # Test with: admin@example.com
        AWS_ACCESS_KEY = "AKIAIOSFODNN7EXAMPLE"
        AWS_SECRET_KEY = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
        """

    /// JavaScript config with tokens (test mode keys)
    static let jsConfig = """
        const config = {
            api: {
                openaiKey: "sk-proj-example1234567890abcdefghijklmnopqrst",
                stripeKey: "sk_test_51N0example123456789012",
                githubToken: "ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
            },
            database: {
                url: "postgresql://user:pass@db.example.com:5432/mydb"
            },
            admin: {
                email: "admin@company.com",
                phone: "555-123-4567"
            }
        };
        """

    /// Mixed language text (Korean/English)
    static let mixedLanguageText = """
        안녕하세요, 저는 김철수입니다.
        연락처: support@company.com
        전화번호: 010-1234-5678

        こんにちは、田中です。
        メール: tanaka@example.jp
        電話: +81-90-1234-5678

        Contact: john@company.com
        Phone: +1-555-123-4567

        信用卡号码: 4111-1111-1111-1111
        """

    /// GitHub Actions workflow
    static let githubActions = """
        name: Deploy
        on: push

        env:
          API_KEY: ${{ secrets.OPENAI_API_KEY }}
          DATABASE_URL: postgresql://user:${{ secrets.DB_PASSWORD }}@db.example.com:5432/prod

        jobs:
          deploy:
            runs-on: ubuntu-latest
            steps:
              - uses: actions/checkout@v3
              - name: Deploy
                env:
                  AWS_ACCESS_KEY_ID: AKIAIOSFODNN7EXAMPLE
                  STRIPE_KEY: sk_test_51N0example123456789012
                run: ./deploy.sh
        """

    /// Slack message export JSON
    static let slackExport = """
        {
            "messages": [
                {
                    "user": "U12345",
                    "text": "Hey team, contact me at john@company.com",
                    "ts": "1702641600.000100"
                },
                {
                    "user": "U67890",
                    "text": "Webhook URL: https://hooks.example.com/services/TXXXXXXXX/BXXXXXXXX/XXXXXXXX",
                    "ts": "1702641700.000200"
                },
                {
                    "user": "U12345",
                    "text": "My number is 555-123-4567",
                    "ts": "1702641800.000300"
                }
            ]
        }
        """
}
