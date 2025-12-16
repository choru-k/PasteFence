import XCTest
@testable import PasteFence

/// Integration tests for real-world document formats with embedded PII
@MainActor
final class RealWorldDataTests: XCTestCase {
    var detector: RegexDetector!

    override func setUp() {
        super.setUp()
        detector = RegexDetector()
    }

    // MARK: - Email Format Tests

    func testEmailThreadWithSignatures() {
        let text = IntegrationTestHelpers.emailThread
        let results = detector.detect(in: text)

        // Should detect multiple emails
        let emails = results.filter { $0.type == .email }
        XCTAssertGreaterThanOrEqual(emails.count, 4, "Should find at least 4 emails in thread")

        // Check specific emails
        XCTAssertTrue(emails.contains { $0.text.contains("john.smith@acme-corp.com") })
        XCTAssertTrue(emails.contains { $0.text.contains("jane.doe@partner.org") })
        XCTAssertTrue(emails.contains { $0.text.contains("support@acme-corp.com") })

        // Should detect phone numbers
        let phones = results.filter { $0.type == .phone }
        XCTAssertGreaterThanOrEqual(phones.count, 3, "Should find at least 3 phone numbers")
    }

    func testForwardedEmailChain() {
        let text = """
            From: Alice <alice@company.com>
            To: Bob <bob@partner.org>
            Subject: FW: Important Update

            --- Forwarded Message ---
            From: Charlie <charlie@external.com>
            To: Alice <alice@company.com>
            Date: Dec 14, 2024

            Please call me at 555-111-2222 or 555-333-4444.

            Credit Card for payment: 4111-1111-1111-1111

            Charlie
            ---
            """

        let results = detector.detect(in: text)

        // Emails in forwarded chain
        let emails = results.filter { $0.type == .email }
        XCTAssertGreaterThanOrEqual(emails.count, 4)

        // Phone numbers
        let phones = results.filter { $0.type == .phone }
        XCTAssertGreaterThanOrEqual(phones.count, 2)

        // Credit card
        let cards = results.filter { $0.type == .creditCard }
        XCTAssertEqual(cards.count, 1)
    }

    // MARK: - Log Format Tests

    func testApacheAccessLog() {
        let text = IntegrationTestHelpers.apacheAccessLog
        let results = detector.detect(in: text)

        // Should detect IP addresses (excluding localhost ranges already filtered)
        let ips = results.filter { $0.type == .ipAddress }
        XCTAssertGreaterThanOrEqual(ips.count, 2, "Should find at least 2 IP addresses")

        // Should detect emails embedded in log
        let emails = results.filter { $0.type == .email }
        XCTAssertGreaterThanOrEqual(emails.count, 2)
    }

    func testNginxErrorLog() {
        let text = """
            2024/12/15 10:15:32 [error] 1234#1234: *5678 open() "/var/www/html/.env" failed (2: No such file)
            2024/12/15 10:15:33 [error] 1234#1234: *5679 connect() to 192.168.1.50:8080 failed
            2024/12/15 10:15:34 [warn] 1234#1234: *5680 client 10.0.0.100 closed keepalive connection
            2024/12/15 10:15:35 [error] 1234#1234: SSL_do_handshake() failed with 172.16.0.200
            """

        let results = detector.detect(in: text)

        let ips = results.filter { $0.type == .ipAddress }
        XCTAssertGreaterThanOrEqual(ips.count, 2, "Should find IP addresses in nginx log")
    }

    func testApplicationLogWithSecrets() {
        let text = IntegrationTestHelpers.appErrorLog
        let results = detector.detect(in: text)

        // Should find database URL with credentials
        let dbUrls = results.filter { $0.type == .databaseUrl }
        XCTAssertGreaterThanOrEqual(dbUrls.count, 1, "Should find database URL")

        // Should find API key
        let apiKeys = results.filter { $0.type == .apiKey }
        XCTAssertGreaterThanOrEqual(apiKeys.count, 1, "Should find API key")

        // Should find JWT
        let jwts = results.filter { $0.type == .jwt }
        XCTAssertGreaterThanOrEqual(jwts.count, 1, "Should find JWT token")

        // Should find IP address
        let ips = results.filter { $0.type == .ipAddress }
        XCTAssertGreaterThanOrEqual(ips.count, 1, "Should find IP address")
    }

    // MARK: - Configuration File Tests

    func testEnvFileWithAllSecrets() {
        let text = IntegrationTestHelpers.envFile
        let results = detector.detect(in: text)

        // Database URL - exactly 2 (postgresql and redis)
        let dbUrls = results.filter { $0.type == .databaseUrl }
        XCTAssertEqual(dbUrls.count, 2, "Should find exactly 2 database URLs")

        // API Keys (OpenAI + GitHub token)
        let apiKeys = results.filter { $0.type == .apiKey }
        XCTAssertGreaterThanOrEqual(apiKeys.count, 2, "Should find at least 2 API keys")

        // Stripe key - exactly 1
        let stripeKeys = results.filter { $0.type == .stripeKey }
        XCTAssertEqual(stripeKeys.count, 1, "Should find exactly 1 Stripe key")

        // GitHub token
        XCTAssertTrue(results.contains { $0.type == .apiKey && $0.text.contains("ghp_") }, "Should find GitHub token")

        // AWS keys - exactly 1
        let awsKeys = results.filter { $0.type == .awsKey }
        XCTAssertEqual(awsKeys.count, 1, "Should find exactly 1 AWS key")

        // Webhook URL - exactly 1
        let webhooks = results.filter { $0.type == .webhookUrl }
        XCTAssertEqual(webhooks.count, 1, "Should find exactly 1 Slack webhook")

        // Total should be substantial
        XCTAssertGreaterThanOrEqual(results.count, 6, "Should find multiple secrets in .env file")
    }

    func testDockerComposeWithSecrets() {
        let text = IntegrationTestHelpers.dockerCompose
        let results = detector.detect(in: text)

        // Should find database URL
        let dbUrls = results.filter { $0.type == .databaseUrl }
        XCTAssertGreaterThanOrEqual(dbUrls.count, 1, "Should find database URL in docker-compose")

        // Should find API key
        let apiKeys = results.filter { $0.type == .apiKey }
        XCTAssertGreaterThanOrEqual(apiKeys.count, 1, "Should find API key")
    }

    func testKubernetesSecretYAML() {
        let text = """
            apiVersion: v1
            kind: Secret
            metadata:
              name: app-secrets
            type: Opaque
            data:
              database-url: cG9zdGdyZXNxbDovL2FkbWluOnBhc3NAZGIuZXhhbXBsZS5jb206NTQzMi9teWRi
              api-key: c2stMTIzNDU2Nzg5MGFiY2RlZjEyMzQ1Njc4OTBhYmNkZWYxMjM0NTY3ODkwYWJjZGVm
            stringData:
              admin-password: SuperSecretPassword123!
              stripe-key: sk_test_51N0example123456789012
            """

        let results = detector.detect(in: text)

        // Should find Stripe key in stringData
        XCTAssertTrue(results.contains { $0.type == .stripeKey }, "Should find Stripe key in K8s secret")
    }

    // MARK: - Code File Tests

    func testPythonScriptWithSecrets() {
        let text = IntegrationTestHelpers.pythonCode
        let results = detector.detect(in: text)

        // API key
        XCTAssertTrue(results.contains { $0.type == .apiKey }, "Should find API key in Python code")

        // Database URL
        XCTAssertTrue(results.contains { $0.type == .databaseUrl }, "Should find database URL")

        // Webhook URL
        XCTAssertTrue(results.contains { $0.type == .webhookUrl }, "Should find webhook URL")

        // AWS keys
        XCTAssertTrue(results.contains { $0.type == .awsKey }, "Should find AWS key")
    }

    func testJavaScriptConfigWithTokens() {
        let text = IntegrationTestHelpers.jsConfig
        let results = detector.detect(in: text)

        // OpenAI key
        let apiKeys = results.filter { $0.type == .apiKey }
        XCTAssertGreaterThanOrEqual(apiKeys.count, 2, "Should find API keys in JS config")

        // Stripe key
        XCTAssertTrue(results.contains { $0.type == .stripeKey }, "Should find Stripe key")

        // Database URL
        XCTAssertTrue(results.contains { $0.type == .databaseUrl }, "Should find database URL")

        // Email
        XCTAssertTrue(results.contains { $0.type == .email }, "Should find email")

        // Phone
        XCTAssertTrue(results.contains { $0.type == .phone }, "Should find phone")
    }

    func testSwiftCodeWithAPIKeys() {
        // Test mode keys - GitHub won't flag these
        let text = """
            import Foundation

            struct Config {
                static let openAIKey = "sk-proj-example1234567890abcdefghijklmnopqrst"
                static let awsAccessKey = "AKIAEXAMPLEEXAMPLE1"
                static let stripeKey = "sk_test_51N0example123456789012"

                static let adminEmail = "admin@myapp.com"
                static let supportPhone = "555-123-4567"
            }

            let databaseURL = "postgresql://admin:pass123@db.example.com:5432/production"
            """

        let results = detector.detect(in: text)

        // Should find exactly the expected counts
        let apiKeys = results.filter { $0.type == .apiKey }
        XCTAssertEqual(apiKeys.count, 1, "Should find exactly 1 OpenAI API key")

        let awsKeys = results.filter { $0.type == .awsKey }
        XCTAssertEqual(awsKeys.count, 1, "Should find exactly 1 AWS key")

        let stripeKeys = results.filter { $0.type == .stripeKey }
        XCTAssertEqual(stripeKeys.count, 1, "Should find exactly 1 Stripe key")

        let emails = results.filter { $0.type == .email }
        XCTAssertEqual(emails.count, 1, "Should find exactly 1 email")

        let phones = results.filter { $0.type == .phone }
        XCTAssertEqual(phones.count, 1, "Should find exactly 1 phone")

        let dbUrls = results.filter { $0.type == .databaseUrl }
        XCTAssertEqual(dbUrls.count, 1, "Should find exactly 1 database URL")
    }

    // MARK: - Mixed Format Tests

    func testGitDiffWithLeakedSecrets() {
        let text = """
            diff --git a/config.py b/config.py
            index 1234567..abcdefg 100644
            --- a/config.py
            +++ b/config.py
            @@ -1,5 +1,5 @@
            -API_KEY = "old_key"
            +API_KEY = "sk-1234567890abcdef1234567890abcdef1234567890abcdef"

            -DATABASE_URL = "localhost"
            +DATABASE_URL = "postgresql://admin:secret@prod.db.com:5432/app"
            """

        let results = detector.detect(in: text)

        XCTAssertTrue(results.contains { $0.type == .apiKey }, "Should find API key in git diff")
        XCTAssertTrue(results.contains { $0.type == .databaseUrl }, "Should find database URL in git diff")
    }

    func testSlackMessageExport() {
        let text = IntegrationTestHelpers.slackExport
        let results = detector.detect(in: text)

        // Email - exactly 1
        let emails = results.filter { $0.type == .email }
        XCTAssertEqual(emails.count, 1, "Should find exactly 1 email in Slack export")

        // Webhook URL - exactly 1
        let webhooks = results.filter { $0.type == .webhookUrl }
        XCTAssertEqual(webhooks.count, 1, "Should find exactly 1 webhook URL")

        // Phone - at least 1 (regex may match timestamp-like patterns as false positives)
        let phones = results.filter { $0.type == .phone }
        XCTAssertGreaterThanOrEqual(phones.count, 1, "Should find at least 1 phone number")
        XCTAssertTrue(phones.contains { $0.text.contains("555-123-4567") }, "Should find the actual phone number")
    }

    func testGitHubActionsWorkflow() {
        let text = IntegrationTestHelpers.githubActions
        let results = detector.detect(in: text)

        // AWS key
        XCTAssertTrue(results.contains { $0.type == .awsKey }, "Should find AWS key in GitHub Actions")

        // Stripe key
        XCTAssertTrue(results.contains { $0.type == .stripeKey }, "Should find Stripe key")

        // Database URL pattern
        XCTAssertTrue(results.contains { $0.type == .databaseUrl }, "Should find database URL")
    }

    // MARK: - Complex Real-World Scenarios

    func testMixedPIIInCustomerSupportTicket() {
        let text = """
            Ticket #12345
            Customer: John Smith
            Email: john.smith@customer.com
            Phone: +1 (555) 234-5678

            Issue Description:
            I'm having trouble with my payment. My card ending in 4111-1111-1111-1111
            keeps getting declined. My previous card 5500-0000-0000-0004 worked fine.

            Account ID: user_12345
            SSN on file: 123-45-6789

            Please contact me at john.smith@personal.com or 555-987-6543.
            """

        let results = detector.detect(in: text)

        // Multiple emails
        let emails = results.filter { $0.type == .email }
        XCTAssertGreaterThanOrEqual(emails.count, 2)

        // Multiple phones
        let phones = results.filter { $0.type == .phone }
        XCTAssertGreaterThanOrEqual(phones.count, 2)

        // Credit cards
        let cards = results.filter { $0.type == .creditCard }
        XCTAssertGreaterThanOrEqual(cards.count, 2)

        // SSN
        let ssns = results.filter { $0.type == .ssn }
        XCTAssertGreaterThanOrEqual(ssns.count, 1)
    }

    func testIncidentReportWithAllPIITypes() {
        let text = """
            SECURITY INCIDENT REPORT
            Date: December 15, 2024
            Reported by: security@company.com

            Summary:
            Unauthorized access detected from IP 192.168.100.50.
            Attacker used compromised credentials:
            - API Key: sk-1234567890abcdef1234567890abcdef1234567890abcdef
            - AWS Access Key: AKIAIOSFODNN7EXAMPLE
            - Database: postgresql://admin:leaked_pass@db.internal:5432/users

            Affected users:
            - alice@company.com (SSN: 111-22-3333)
            - bob@company.com (Card: 4111-1111-1111-1111)

            Attacker contact found: hacker@darkweb.onion
            Callback URL: https://evil.com/webhook

            JWT token found in logs:
            eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dozjgNryP4J3jVmNHl0w5N_XgL0n3I9PlFUP0THsR8U
            """

        let results = detector.detect(in: text)

        // Should find many different types
        XCTAssertTrue(results.contains { $0.type == .email })
        XCTAssertTrue(results.contains { $0.type == .ipAddress })
        XCTAssertTrue(results.contains { $0.type == .apiKey })
        XCTAssertTrue(results.contains { $0.type == .awsKey })
        XCTAssertTrue(results.contains { $0.type == .databaseUrl })
        XCTAssertTrue(results.contains { $0.type == .ssn })
        XCTAssertTrue(results.contains { $0.type == .creditCard })
        XCTAssertTrue(results.contains { $0.type == .jwt })

        // Total should be high
        XCTAssertGreaterThanOrEqual(results.count, 10, "Should find many PII items in incident report")
    }
}
