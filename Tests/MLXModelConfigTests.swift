import XCTest
@testable import PasteFence

final class MLXModelConfigTests: XCTestCase {

    // MARK: - Test Fixtures

    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - Happy Path Tests

    func testLoadsValidQwen3Config() throws {
        let configJSON = """
        {
            "model_type": "qwen3",
            "vocab_size": 151936,
            "hidden_size": 1024,
            "num_hidden_layers": 28,
            "num_attention_heads": 16,
            "num_key_value_heads": 4,
            "intermediate_size": 3072,
            "max_position_embeddings": 40960,
            "rms_norm_eps": 1e-6,
            "rope_theta": 1000000.0,
            "tie_word_embeddings": true
        }
        """
        try writeConfig(configJSON)

        let config = try MLXModelConfigLoader.load(from: tempDir.path)

        XCTAssertEqual(config.modelType, "qwen3")
        XCTAssertEqual(config.vocabSize, 151936)
        XCTAssertEqual(config.hiddenSize, 1024)
        XCTAssertEqual(config.numHiddenLayers, 28)
        XCTAssertEqual(config.numAttentionHeads, 16)
        XCTAssertEqual(config.numKeyValueHeads, 4)
        XCTAssertEqual(config.intermediateSize, 3072)
        XCTAssertEqual(config.maxPositionEmbeddings, 40960)
        XCTAssertEqual(config.rmsNormEps, 1e-6)
        XCTAssertEqual(config.ropeTheta, 1000000.0)
        XCTAssertTrue(config.tieWordEmbeddings)
    }

    func testLoadsConfigWithDefaults() throws {
        let configJSON = """
        {
            "model_type": "qwen3",
            "vocab_size": 151936,
            "hidden_size": 1024,
            "num_hidden_layers": 28,
            "num_attention_heads": 16,
            "num_key_value_heads": 4,
            "intermediate_size": 3072,
            "max_position_embeddings": 40960
        }
        """
        try writeConfig(configJSON)

        let config = try MLXModelConfigLoader.load(from: tempDir.path)

        // Verify defaults are applied
        XCTAssertEqual(config.rmsNormEps, 1e-6)
        XCTAssertEqual(config.ropeTheta, 10000.0)
        XCTAssertFalse(config.tieWordEmbeddings)
    }

    func testConfigIsSupported() {
        let config = MLXModelConfig(
            modelType: "qwen3",
            vocabSize: 151936,
            hiddenSize: 1024,
            numHiddenLayers: 28,
            numAttentionHeads: 16,
            numKeyValueHeads: 4,
            intermediateSize: 3072,
            maxPositionEmbeddings: 40960
        )

        XCTAssertTrue(config.isSupported)
    }

    // MARK: - Error Case Tests

    func testThrowsConfigNotFound() {
        XCTAssertThrowsError(try MLXModelConfigLoader.load(from: tempDir.path)) { error in
            guard case LLMError.configNotFound = error else {
                XCTFail("Expected configNotFound, got \(error)")
                return
            }
        }
    }

    func testThrowsInvalidJSON() throws {
        try writeConfig("{ invalid json }")

        XCTAssertThrowsError(try MLXModelConfigLoader.load(from: tempDir.path)) { error in
            guard case LLMError.configInvalidJSON = error else {
                XCTFail("Expected configInvalidJSON, got \(error)")
                return
            }
        }
    }

    func testThrowsMissingRequiredField() throws {
        let configJSON = """
        {
            "model_type": "qwen3",
            "vocab_size": 151936
        }
        """
        try writeConfig(configJSON)

        XCTAssertThrowsError(try MLXModelConfigLoader.load(from: tempDir.path)) { error in
            guard case LLMError.configMissingField = error else {
                XCTFail("Expected configMissingField, got \(error)")
                return
            }
        }
    }

    func testThrowsUnsupportedModelType() throws {
        let configJSON = """
        {
            "model_type": "llama",
            "vocab_size": 32000,
            "hidden_size": 4096,
            "num_hidden_layers": 32,
            "num_attention_heads": 32,
            "num_key_value_heads": 8,
            "intermediate_size": 11008,
            "max_position_embeddings": 4096
        }
        """
        try writeConfig(configJSON)

        XCTAssertThrowsError(try MLXModelConfigLoader.load(from: tempDir.path)) { error in
            guard case LLMError.configUnsupportedModelType(let type, _) = error else {
                XCTFail("Expected configUnsupportedModelType, got \(error)")
                return
            }
            XCTAssertEqual(type, "llama")
        }
    }

    func testThrowsInvalidVocabSize() throws {
        let configJSON = """
        {
            "model_type": "qwen3",
            "vocab_size": -100,
            "hidden_size": 1024,
            "num_hidden_layers": 28,
            "num_attention_heads": 16,
            "num_key_value_heads": 4,
            "intermediate_size": 3072,
            "max_position_embeddings": 40960
        }
        """
        try writeConfig(configJSON)

        XCTAssertThrowsError(try MLXModelConfigLoader.load(from: tempDir.path)) { error in
            guard case LLMError.configInvalidValue(let field, _) = error else {
                XCTFail("Expected configInvalidValue, got \(error)")
                return
            }
            XCTAssertEqual(field, "vocab_size")
        }
    }

    func testThrowsInvalidKVHeads() throws {
        let configJSON = """
        {
            "model_type": "qwen3",
            "vocab_size": 151936,
            "hidden_size": 1024,
            "num_hidden_layers": 28,
            "num_attention_heads": 16,
            "num_key_value_heads": 32,
            "intermediate_size": 3072,
            "max_position_embeddings": 40960
        }
        """
        try writeConfig(configJSON)

        XCTAssertThrowsError(try MLXModelConfigLoader.load(from: tempDir.path)) { error in
            guard case LLMError.configInvalidValue(let field, _) = error else {
                XCTFail("Expected configInvalidValue, got \(error)")
                return
            }
            XCTAssertEqual(field, "num_key_value_heads")
        }
    }

    func testThrowsZeroKVHeads() throws {
        let configJSON = """
        {
            "model_type": "qwen3",
            "vocab_size": 151936,
            "hidden_size": 1024,
            "num_hidden_layers": 28,
            "num_attention_heads": 16,
            "num_key_value_heads": 0,
            "intermediate_size": 3072,
            "max_position_embeddings": 40960
        }
        """
        try writeConfig(configJSON)

        XCTAssertThrowsError(try MLXModelConfigLoader.load(from: tempDir.path)) { error in
            guard case LLMError.configInvalidValue(let field, _) = error else {
                XCTFail("Expected configInvalidValue, got \(error)")
                return
            }
            XCTAssertEqual(field, "num_key_value_heads")
        }
    }

    // MARK: - Error Description Tests

    func testErrorDescriptions() {
        let errors: [(LLMError, String)] = [
            (.configNotFound(path: "/path/to/config.json"), "Model config.json not found at: /path/to/config.json"),
            (.configMissingField(field: "vocab_size"), "Missing required field in config.json: vocab_size"),
            (.configUnsupportedModelType(type: "llama", supported: ["qwen3"]), "Unsupported model type 'llama'. Supported: qwen3"),
            (.configInvalidValue(field: "hidden_size", reason: "must be positive"), "Invalid value for 'hidden_size': must be positive")
        ]

        for (error, expectedDescription) in errors {
            XCTAssertEqual(error.errorDescription, expectedDescription)
        }
    }

    // MARK: - Helpers

    private func writeConfig(_ content: String) throws {
        let configURL = tempDir.appendingPathComponent("config.json")
        try content.write(to: configURL, atomically: true, encoding: .utf8)
    }
}
