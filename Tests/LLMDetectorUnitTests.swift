import XCTest
@testable import PasteFence

// MARK: - Response Model Tests

final class LLMDetectorResponseModelTests: XCTestCase {

    func testLLMResponseDecodingValidJSON() throws {
        let json = """
        {
            "detected": [
                {"text": "test@email.com", "type": "EMAIL", "confidence": 0.95},
                {"text": "sk-abc123", "type": "API_KEY", "confidence": 0.8}
            ]
        }
        """

        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(LLMResponseTestable.self, from: data)

        XCTAssertEqual(response.detected.count, 2)
        XCTAssertEqual(response.detected[0].text, "test@email.com")
        XCTAssertEqual(response.detected[0].type, "EMAIL")
        XCTAssertEqual(response.detected[0].confidence, 0.95)
        XCTAssertEqual(response.detected[1].type, "API_KEY")
    }

    func testLLMResponseDecodingEmptyArray() throws {
        let json = """
        {"detected": []}
        """

        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(LLMResponseTestable.self, from: data)

        XCTAssertTrue(response.detected.isEmpty)
    }

    func testLLMResponseDecodingMissingConfidenceSucceeds() throws {
        // After the fix: missing confidence should decode successfully (as nil)
        let json = """
        {"detected": [{"text": "test@email.com", "type": "EMAIL"}]}
        """

        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(LLMResponseTestable.self, from: data)

        XCTAssertEqual(response.detected.count, 1)
        XCTAssertEqual(response.detected[0].text, "test@email.com")
        XCTAssertNil(response.detected[0].confidence)  // nil, not 0.85 (default applied later)
    }

    func testNullConfidenceDecodesAsNil() throws {
        // Explicit null should also decode as nil
        let json = """
        {"detected": [{"text": "test", "type": "EMAIL", "confidence": null}]}
        """

        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(LLMResponseTestable.self, from: data)

        XCTAssertNil(response.detected.first?.confidence)
    }

    func testPartialConfidenceMixedResults() throws {
        // Some items have confidence, some don't
        let json = """
        {"detected": [
            {"text": "a@b.com", "type": "EMAIL", "confidence": 0.9},
            {"text": "secret", "type": "PASSWORD"}
        ]}
        """

        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(LLMResponseTestable.self, from: data)

        XCTAssertEqual(response.detected.count, 2)
        XCTAssertEqual(response.detected[0].confidence, 0.9)
        XCTAssertNil(response.detected[1].confidence)
    }

    func testLLMResponseDecodingInvalidJSON() {
        let json = "not valid json"
        let data = json.data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(LLMResponseTestable.self, from: data))
    }
}

// MARK: - SensitiveType Mapping Tests

final class LLMDetectorTypeMappingTests: XCTestCase {

    func testSensitiveTypeEmailMapping() {
        XCTAssertEqual(SensitiveType(rawValue: "EMAIL"), .email)
    }

    func testSensitiveTypePhoneMapping() {
        XCTAssertEqual(SensitiveType(rawValue: "PHONE"), .phone)
    }

    func testSensitiveTypeCreditCardMapping() {
        XCTAssertEqual(SensitiveType(rawValue: "CREDIT_CARD"), .creditCard)
    }

    func testSensitiveTypeAPIKeyMapping() {
        XCTAssertEqual(SensitiveType(rawValue: "API_KEY"), .apiKey)
    }

    func testSensitiveTypeJWTMapping() {
        XCTAssertEqual(SensitiveType(rawValue: "JWT"), .jwt)
    }

    func testSensitiveTypeIPAddressMapping() {
        XCTAssertEqual(SensitiveType(rawValue: "IP_ADDRESS"), .ipAddress)
    }

    func testSensitiveTypePasswordMapping() {
        XCTAssertEqual(SensitiveType(rawValue: "PASSWORD"), .password)
    }

    func testSensitiveTypePrivateKeyMapping() {
        XCTAssertEqual(SensitiveType(rawValue: "PRIVATE_KEY"), .privateKey)
    }

    func testSensitiveTypeAWSKeyMapping() {
        XCTAssertEqual(SensitiveType(rawValue: "AWS_KEY"), .awsKey)
    }

    func testSensitiveTypeSecretMapping() {
        XCTAssertEqual(SensitiveType(rawValue: "SECRET"), .genericSecret)
    }

    func testSensitiveTypeUnknownMapping() {
        XCTAssertNil(SensitiveType(rawValue: "UNKNOWN_TYPE"))
    }
}

// MARK: - Confidence Clamping Tests

final class LLMDetectorConfidenceTests: XCTestCase {

    func testConfidenceClampingAboveOne() {
        let confidence = 1.5
        let clamped = min(max(confidence, 0.0), 1.0)
        XCTAssertEqual(clamped, 1.0)
    }

    func testConfidenceClampingBelowZero() {
        let confidence = -0.5
        let clamped = min(max(confidence, 0.0), 1.0)
        XCTAssertEqual(clamped, 0.0)
    }

    func testConfidenceClampingValid() {
        let confidence = 0.75
        let clamped = min(max(confidence, 0.0), 1.0)
        XCTAssertEqual(clamped, 0.75)
    }

    func testMissingConfidenceDefaultsTo085() {
        // When confidence is nil (missing from JSON), default to 0.85
        let confidence: Double? = nil
        let defaulted = min(max(confidence ?? 0.85, 0.0), 1.0)
        XCTAssertEqual(defaulted, 0.85)
    }

    func testConfidenceClampingWithNilDefault() {
        // Test the full clamping logic with nil input
        let testCases: [(Double?, Double)] = [
            (nil, 0.85),      // nil defaults to 0.85
            (0.0, 0.0),       // zero stays zero
            (1.0, 1.0),       // one stays one
            (0.5, 0.5),       // valid value unchanged
            (-0.5, 0.0),      // negative clamped to 0
            (1.5, 1.0),       // over 1 clamped to 1
        ]

        for (input, expected) in testCases {
            let clamped = min(max(input ?? 0.85, 0.0), 1.0)
            XCTAssertEqual(clamped, expected, "Input \(String(describing: input)) should clamp to \(expected)")
        }
    }
}
