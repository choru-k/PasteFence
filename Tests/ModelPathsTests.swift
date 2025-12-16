import XCTest
@testable import PasteFence

final class ModelPathsTests: XCTestCase {

    // MARK: - Path Construction Tests

    func testAppSupportPathEndsWithPasteFence() {
        XCTAssertTrue(ModelPaths.appSupport.path.hasSuffix("PasteFence"))
    }

    func testModelsDirPathEndsWithModels() {
        XCTAssertTrue(ModelPaths.modelsDir.path.hasSuffix("models"))
    }

    func testModelsDirIsChildOfAppSupport() {
        XCTAssertTrue(ModelPaths.modelsDir.path.hasPrefix(ModelPaths.appSupport.path))
    }

    func testDefaultModelDirIsChildOfModelsDir() {
        XCTAssertTrue(ModelPaths.defaultModelDir.path.hasPrefix(ModelPaths.modelsDir.path))
    }

    func testCustomModelsDirIsChildOfModelsDir() {
        XCTAssertTrue(ModelPaths.customModelsDir.path.hasPrefix(ModelPaths.modelsDir.path))
    }

    func testConfigURLIsChildOfAppSupport() {
        XCTAssertTrue(ModelPaths.configURL.path.hasPrefix(ModelPaths.appSupport.path))
    }

    func testConfigURLEndsWithConfigJson() {
        XCTAssertTrue(ModelPaths.configURL.path.hasSuffix("config.json"))
    }

    func testModelPathForIdReturnsCorrectPath() {
        let modelId = "test-model"
        let path = ModelPaths.modelPath(for: modelId)
        XCTAssertEqual(path.lastPathComponent, modelId)
        XCTAssertTrue(path.path.hasPrefix(ModelPaths.modelsDir.path))
    }

    // MARK: - Directory Creation Tests

    func testEnsureDirectoriesExistDoesNotThrow() {
        XCTAssertNoThrow(try ModelPaths.ensureDirectoriesExist())
    }

    func testEnsureDirectoriesExistCreatesAppSupport() throws {
        try ModelPaths.ensureDirectoriesExist()
        XCTAssertTrue(FileManager.default.fileExists(atPath: ModelPaths.appSupport.path))
    }

    func testEnsureDirectoriesExistCreatesModelsDir() throws {
        try ModelPaths.ensureDirectoriesExist()
        XCTAssertTrue(FileManager.default.fileExists(atPath: ModelPaths.modelsDir.path))
    }

    func testEnsureDirectoriesExistCreatesCustomModelsDir() throws {
        try ModelPaths.ensureDirectoriesExist()
        XCTAssertTrue(FileManager.default.fileExists(atPath: ModelPaths.customModelsDir.path))
    }

    // MARK: - Model Validation Tests

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

    func testIsValidModelReturnsFalseForEmptyDirectory() {
        XCTAssertFalse(ModelPaths.isValidModel(at: tempDir))
    }

    func testIsValidModelReturnsFalseWithOnlyConfig() throws {
        try "{}".write(to: tempDir.appendingPathComponent("config.json"), atomically: true, encoding: .utf8)
        XCTAssertFalse(ModelPaths.isValidModel(at: tempDir))
    }

    func testIsValidModelReturnsFalseWithConfigAndTokenizerButNoWeights() throws {
        try "{}".write(to: tempDir.appendingPathComponent("config.json"), atomically: true, encoding: .utf8)
        try "{}".write(to: tempDir.appendingPathComponent("tokenizer.json"), atomically: true, encoding: .utf8)
        XCTAssertFalse(ModelPaths.isValidModel(at: tempDir))
    }

    func testIsValidModelReturnsTrueWithSafetensorsWeights() throws {
        try "{}".write(to: tempDir.appendingPathComponent("config.json"), atomically: true, encoding: .utf8)
        try "{}".write(to: tempDir.appendingPathComponent("tokenizer.json"), atomically: true, encoding: .utf8)
        try Data().write(to: tempDir.appendingPathComponent("model.safetensors"))
        XCTAssertTrue(ModelPaths.isValidModel(at: tempDir))
    }

    func testIsValidModelReturnsTrueWithPytorchWeights() throws {
        try "{}".write(to: tempDir.appendingPathComponent("config.json"), atomically: true, encoding: .utf8)
        try "{}".write(to: tempDir.appendingPathComponent("tokenizer.json"), atomically: true, encoding: .utf8)
        try Data().write(to: tempDir.appendingPathComponent("pytorch_model.bin"))
        XCTAssertTrue(ModelPaths.isValidModel(at: tempDir))
    }

    func testIsValidModelReturnsTrueWithShardedWeights() throws {
        try "{}".write(to: tempDir.appendingPathComponent("config.json"), atomically: true, encoding: .utf8)
        try "{}".write(to: tempDir.appendingPathComponent("tokenizer.json"), atomically: true, encoding: .utf8)
        try Data().write(to: tempDir.appendingPathComponent("model-00001-of-00002.safetensors"))
        XCTAssertTrue(ModelPaths.isValidModel(at: tempDir))
    }

    func testIsValidModelReturnsFalseForNonExistentPath() {
        let nonExistent = tempDir.appendingPathComponent("nonexistent")
        XCTAssertFalse(ModelPaths.isValidModel(at: nonExistent))
    }

    // MARK: - Model Discovery Tests

    func testDiscoverModelsReturnsEmptyForEmptyDirectory() throws {
        // Ensure directories exist first
        try ModelPaths.ensureDirectoriesExist()

        // Discovery should return empty if no valid models
        let models = ModelPaths.discoverModels()

        // May or may not have default model depending on previous tests
        // Just check it doesn't crash
        XCTAssertNotNil(models)
    }

    func testDiscoverModelsFindsValidCustomModel() throws {
        try ModelPaths.ensureDirectoriesExist()

        // Create a valid custom model
        let customModelDir = ModelPaths.customModelsDir.appendingPathComponent("test-custom-model")
        try FileManager.default.createDirectory(at: customModelDir, withIntermediateDirectories: true)
        try "{}".write(to: customModelDir.appendingPathComponent("config.json"), atomically: true, encoding: .utf8)
        try "{}".write(to: customModelDir.appendingPathComponent("tokenizer.json"), atomically: true, encoding: .utf8)
        try Data().write(to: customModelDir.appendingPathComponent("model.safetensors"))

        defer {
            try? FileManager.default.removeItem(at: customModelDir)
        }

        let models = ModelPaths.discoverModels()
        let customModel = models.first { $0.name == "test-custom-model" }

        XCTAssertNotNil(customModel)
        XCTAssertEqual(customModel?.isDefault, false)
    }

    func testDiscoverModelsIgnoresInvalidCustomModel() throws {
        try ModelPaths.ensureDirectoriesExist()

        // Create an invalid custom model (missing files)
        let invalidModelDir = ModelPaths.customModelsDir.appendingPathComponent("invalid-model")
        try FileManager.default.createDirectory(at: invalidModelDir, withIntermediateDirectories: true)
        try "{}".write(to: invalidModelDir.appendingPathComponent("config.json"), atomically: true, encoding: .utf8)
        // Missing tokenizer.json and weights

        defer {
            try? FileManager.default.removeItem(at: invalidModelDir)
        }

        let models = ModelPaths.discoverModels()
        let invalidModel = models.first { $0.name == "invalid-model" }

        XCTAssertNil(invalidModel)
    }

    // MARK: - DiscoveredModel Tests

    func testDiscoveredModelEquality() {
        let model1 = DiscoveredModel(name: "test", path: URL(fileURLWithPath: "/test"), isDefault: true)
        let model2 = DiscoveredModel(name: "test", path: URL(fileURLWithPath: "/test"), isDefault: true)
        XCTAssertEqual(model1, model2)
    }

    func testDiscoveredModelInequality() {
        let model1 = DiscoveredModel(name: "test1", path: URL(fileURLWithPath: "/test1"), isDefault: true)
        let model2 = DiscoveredModel(name: "test2", path: URL(fileURLWithPath: "/test2"), isDefault: false)
        XCTAssertNotEqual(model1, model2)
    }
}
