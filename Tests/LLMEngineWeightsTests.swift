import XCTest
@testable import PasteFence

final class LLMEngineWeightsTests: XCTestCase {

    // MARK: - HuggingFace ID Derivation Tests

    func testDerivesQwen3HuggingFaceId() {
        // Test that local model ID maps to correct HuggingFace ID
        let testCases: [(localPath: String, expectedId: String)] = [
            ("/path/to/models/qwen3-0.6b-mlx-8bit", "Qwen/Qwen3-0.6B-MLX-8bit"),
            ("/models/qwen2.5-1.5b-mlx-4bit", "mlx-community/Qwen2.5-1.5B-Instruct-4bit"),
            ("/unknown/path/some-model", "mlx-community/Qwen3-4B-4bit"),  // Default fallback
            ("", "mlx-community/Qwen3-4B-4bit"),  // Empty path fallback
        ]

        for (localPath, expectedId) in testCases {
            let derivedId = deriveHuggingFaceId(from: localPath)
            XCTAssertEqual(derivedId, expectedId, "Failed for path: \(localPath)")
        }
    }

    // MARK: - Error Cases Tests

    func testModelNotLoadedError() {
        let error = LLMError.modelNotLoaded
        XCTAssertEqual(error.errorDescription, "No model is currently loaded")
    }

    func testModelLoadFailedError() {
        let underlyingError = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Network error"])
        let error = LLMError.modelLoadFailed(underlyingError: underlyingError)
        XCTAssertTrue(error.errorDescription?.contains("Failed to load model") ?? false)
        XCTAssertTrue(error.errorDescription?.contains("Network error") ?? false)
    }

    func testGenerationFailedError() {
        let underlyingError = NSError(domain: "test", code: 2, userInfo: [NSLocalizedDescriptionKey: "Out of memory"])
        let error = LLMError.generationFailed(underlyingError: underlyingError)
        XCTAssertTrue(error.errorDescription?.contains("Text generation failed") ?? false)
        XCTAssertTrue(error.errorDescription?.contains("Out of memory") ?? false)
    }

    // MARK: - ModelManager Error Tests

    func testModelManagerDownloadFailedError() {
        let underlyingError = NSError(domain: "test", code: 3, userInfo: [NSLocalizedDescriptionKey: "Connection timeout"])
        let error = ModelManagerError.downloadFailed(model: "Qwen3", underlying: underlyingError)
        XCTAssertTrue(error.errorDescription?.contains("Failed to download Qwen3") ?? false)
        XCTAssertTrue(error.errorDescription?.contains("Connection timeout") ?? false)
    }

    func testModelManagerModelNotFoundError() {
        let error = ModelManagerError.modelNotFound(id: "unknown-model")
        XCTAssertEqual(error.errorDescription, "Model not found: unknown-model")
    }

    // MARK: - ModelInfo Tests

    func testModelInfoEquality() {
        let model1 = ModelInfo(
            id: "qwen3-0.6b",
            name: "Qwen3 0.6B",
            description: "Test model",
            size: "~400MB",
            huggingFaceId: "Qwen/Qwen3-0.6B-MLX-8bit",
            isDefault: true,
            contextLength: 32768
        )

        let model2 = ModelInfo(
            id: "qwen3-0.6b",
            name: "Qwen3 0.6B",
            description: "Test model",
            size: "~400MB",
            huggingFaceId: "Qwen/Qwen3-0.6B-MLX-8bit",
            isDefault: true,
            contextLength: 32768
        )

        let model3 = ModelInfo(
            id: "qwen2.5-1.5b",
            name: "Qwen2.5 1.5B",
            description: "Different model",
            size: "~900MB",
            huggingFaceId: "mlx-community/Qwen2.5-1.5B-Instruct-4bit",
            isDefault: false,
            contextLength: 32768
        )

        XCTAssertEqual(model1, model2)
        XCTAssertNotEqual(model1, model3)
    }

    func testModelInfoCodable() throws {
        let model = ModelInfo(
            id: "qwen3-0.6b",
            name: "Qwen3 0.6B",
            description: "Test model",
            size: "~400MB",
            huggingFaceId: "Qwen/Qwen3-0.6B-MLX-8bit",
            isDefault: true,
            contextLength: 32768
        )

        let encoded = try JSONEncoder().encode(model)
        let decoded = try JSONDecoder().decode(ModelInfo.self, from: encoded)

        XCTAssertEqual(model, decoded)
    }

    // MARK: - Helpers

    private func deriveHuggingFaceId(from modelPath: String) -> String {
        let pathComponents = modelPath.split(separator: "/")
        if let lastComponent = pathComponents.last {
            let modelId = String(lastComponent)
            switch modelId {
            case "qwen3-0.6b-mlx-8bit":
                return "Qwen/Qwen3-0.6B-MLX-8bit"
            case "qwen2.5-1.5b-mlx-4bit":
                return "mlx-community/Qwen2.5-1.5B-Instruct-4bit"
            default:
                return "mlx-community/Qwen3-4B-4bit"
            }
        }
        return "mlx-community/Qwen3-4B-4bit"
    }
}
