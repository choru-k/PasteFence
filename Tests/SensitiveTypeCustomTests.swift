import XCTest
@testable import PasteFence

// MARK: - SensitiveType Custom Type Tests

final class SensitiveTypeCustomTests: XCTestCase {

    // MARK: - Custom Type Creation Tests

    func testCustomTypeFromRawValue() {
        let type = SensitiveType(rawValue: "CUSTOM_PROJECT")
        XCTAssertEqual(type, .custom("CUSTOM_PROJECT"))
    }

    func testCustomTypeLowercaseInput() {
        let type = SensitiveType(rawValue: "custom_project")
        XCTAssertEqual(type, .custom("CUSTOM_PROJECT"))
    }

    func testCustomTypeMixedCaseInput() {
        let type = SensitiveType(rawValue: "Custom_Employee_Id")
        XCTAssertEqual(type, .custom("CUSTOM_EMPLOYEE_ID"))
    }

    func testNonCustomUnknownTypeReturnsNil() {
        let type = SensitiveType(rawValue: "UNKNOWN_TYPE")
        XCTAssertNil(type)
    }

    func testBuiltInTypeStillWorks() {
        XCTAssertEqual(SensitiveType(rawValue: "EMAIL"), .email)
        XCTAssertEqual(SensitiveType(rawValue: "PASSWORD"), .password)
        XCTAssertEqual(SensitiveType(rawValue: "API_KEY"), .apiKey)
        XCTAssertEqual(SensitiveType(rawValue: "PRIVATE_KEY"), .privateKey)
    }

    // MARK: - Raw Value Tests

    func testCustomTypeRawValue() {
        let type = SensitiveType.custom("CUSTOM_PROJECT")
        XCTAssertEqual(type.rawValue, "CUSTOM_PROJECT")
    }

    func testBuiltInTypeRawValues() {
        XCTAssertEqual(SensitiveType.email.rawValue, "EMAIL")
        XCTAssertEqual(SensitiveType.password.rawValue, "PASSWORD")
        XCTAssertEqual(SensitiveType.genericSecret.rawValue, "SECRET")
    }

    // MARK: - Display Name Tests

    func testCustomTypeDisplayNameSimple() {
        let type = SensitiveType.custom("CUSTOM_PROJECT")
        XCTAssertEqual(type.displayName, "Project")
    }

    func testCustomTypeDisplayNameMultiWord() {
        let type = SensitiveType.custom("CUSTOM_EMPLOYEE_ID")
        XCTAssertEqual(type.displayName, "Employee Id")
    }

    func testCustomTypeDisplayNameComplex() {
        let type = SensitiveType.custom("CUSTOM_INTERNAL_PROJECT_CODENAME")
        XCTAssertEqual(type.displayName, "Internal Project Codename")
    }

    func testBuiltInTypeDisplayNames() {
        XCTAssertEqual(SensitiveType.email.displayName, "Email")
        XCTAssertEqual(SensitiveType.creditCard.displayName, "Credit Card")
        XCTAssertEqual(SensitiveType.privateKey.displayName, "Private Key")
    }

    // MARK: - Mask Label Tests

    func testCustomTypeMaskLabel() {
        let type = SensitiveType.custom("CUSTOM_PROJECT")
        XCTAssertEqual(type.maskLabel, "[CUSTOM_PROJECT_MASKED]")
    }

    func testBuiltInTypeMaskLabel() {
        XCTAssertEqual(SensitiveType.email.maskLabel, "[EMAIL_MASKED]")
        XCTAssertEqual(SensitiveType.password.maskLabel, "[PASSWORD_MASKED]")
    }

    // MARK: - Codable Tests

    func testCustomTypeCodableRoundTrip() throws {
        let original = SensitiveType.custom("CUSTOM_PROJECT")
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SensitiveType.self, from: encoded)
        XCTAssertEqual(original, decoded)
    }

    func testBuiltInTypeCodableRoundTrip() throws {
        let original = SensitiveType.email
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SensitiveType.self, from: encoded)
        XCTAssertEqual(original, decoded)
    }

    func testCustomTypeEncodesAsString() throws {
        let type = SensitiveType.custom("CUSTOM_PROJECT")
        let encoded = try JSONEncoder().encode(type)
        let jsonString = String(data: encoded, encoding: .utf8)!
        XCTAssertEqual(jsonString, "\"CUSTOM_PROJECT\"")
    }

    func testDecodingUnknownTypeDefaultsToGenericSecret() throws {
        let json = "\"COMPLETELY_UNKNOWN_TYPE\""
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(SensitiveType.self, from: data)
        XCTAssertEqual(decoded, .genericSecret)
    }

    func testDecodingCustomTypeFromJSON() throws {
        let json = "\"CUSTOM_EMPLOYEE_ID\""
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(SensitiveType.self, from: data)
        XCTAssertEqual(decoded, .custom("CUSTOM_EMPLOYEE_ID"))
    }

    // MARK: - Equatable Tests

    func testCustomTypesEqual() {
        let type1 = SensitiveType.custom("CUSTOM_PROJECT")
        let type2 = SensitiveType.custom("CUSTOM_PROJECT")
        XCTAssertEqual(type1, type2)
    }

    func testCustomTypesNotEqual() {
        let type1 = SensitiveType.custom("CUSTOM_PROJECT")
        let type2 = SensitiveType.custom("CUSTOM_EMPLOYEE_ID")
        XCTAssertNotEqual(type1, type2)
    }

    func testCustomTypeNotEqualToBuiltIn() {
        let custom = SensitiveType.custom("CUSTOM_SECRET")
        let builtIn = SensitiveType.genericSecret
        XCTAssertNotEqual(custom, builtIn)
    }

    // MARK: - Hashable Tests

    func testCustomTypeHashable() {
        let type1 = SensitiveType.custom("CUSTOM_PROJECT")
        let type2 = SensitiveType.custom("CUSTOM_PROJECT")

        var set = Set<SensitiveType>()
        set.insert(type1)
        set.insert(type2)

        XCTAssertEqual(set.count, 1)
    }

    func testDifferentCustomTypesInSet() {
        var set = Set<SensitiveType>()
        set.insert(.custom("CUSTOM_PROJECT"))
        set.insert(.custom("CUSTOM_EMPLOYEE_ID"))
        set.insert(.email)

        XCTAssertEqual(set.count, 3)
    }

    // MARK: - All Built-In Cases Tests

    func testAllBuiltInCasesCount() {
        // Should have 25 built-in cases (10 core + 6 Phase 1 + 5 Phase 2 + 4 Phase 3)
        XCTAssertEqual(SensitiveType.allBuiltInCases.count, 25)
    }

    func testAllBuiltInCasesDoesNotIncludeCustom() {
        for type in SensitiveType.allBuiltInCases {
            if case .custom = type {
                XCTFail("allBuiltInCases should not include custom types")
            }
        }
    }

    func testAllBuiltInCasesIncludesExpectedTypes() {
        let cases = SensitiveType.allBuiltInCases
        XCTAssertTrue(cases.contains(.email))
        XCTAssertTrue(cases.contains(.phone))
        XCTAssertTrue(cases.contains(.creditCard))
        XCTAssertTrue(cases.contains(.password))
        XCTAssertTrue(cases.contains(.apiKey))
        XCTAssertTrue(cases.contains(.jwt))
        XCTAssertTrue(cases.contains(.privateKey))
        XCTAssertTrue(cases.contains(.awsKey))
        XCTAssertTrue(cases.contains(.genericSecret))
    }
}
