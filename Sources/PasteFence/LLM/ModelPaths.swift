import Foundation

/// Discovered model information from filesystem scanning
struct DiscoveredModel: Equatable {
    let name: String
    let path: URL
    let isDefault: Bool
}

/// Centralized model storage path management
/// All paths follow macOS Application Support conventions
enum ModelPaths {
    // MARK: - Base Paths

    /// Application Support directory for PasteFence
    static var appSupport: URL {
        let fm = FileManager.default
        // swiftlint:disable:next force_unwrapping
        let appSupportDir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupportDir.appendingPathComponent("PasteFence", isDirectory: true)
    }

    /// Root models directory
    static var modelsDir: URL {
        appSupport.appendingPathComponent("models", isDirectory: true)
    }

    /// Config file for app settings
    static var configURL: URL {
        appSupport.appendingPathComponent("config.json")
    }

    // MARK: - Model Directories

    /// Default model directory (Qwen3-0.6B-MLX-8bit)
    static var defaultModelDir: URL {
        modelsDir.appendingPathComponent("qwen3-0.6b-mlx-8bit", isDirectory: true)
    }

    /// Custom models directory for user-provided models
    static var customModelsDir: URL {
        modelsDir.appendingPathComponent("custom", isDirectory: true)
    }

    // MARK: - Directory Management

    /// Ensure all required directories exist
    /// Creates directories with intermediate directories if needed
    /// - Throws: FileManager errors if directory creation fails
    static func ensureDirectoriesExist() throws {
        let fm = FileManager.default
        let directories = [appSupport, modelsDir, customModelsDir]

        for dir in directories {
            if !fm.fileExists(atPath: dir.path) {
                try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            }
        }
    }

    // MARK: - Model Validation

    /// Required files for a valid MLX model
    private static let requiredFiles = ["config.json", "tokenizer.json"]

    /// Possible weight file names (at least one must exist)
    private static let weightFilePatterns = ["model.safetensors", "pytorch_model.bin"]

    /// Check if a directory contains a valid MLX model
    /// - Parameter path: URL to the model directory
    /// - Returns: true if the directory contains all required model files
    static func isValidModel(at path: URL) -> Bool {
        let fm = FileManager.default

        // Check required files exist
        for file in requiredFiles {
            let filePath = path.appendingPathComponent(file).path
            if !fm.fileExists(atPath: filePath) {
                return false
            }
        }

        // Check for weight files (at least one must exist)
        let hasStandardWeights = weightFilePatterns.contains { pattern in
            fm.fileExists(atPath: path.appendingPathComponent(pattern).path)
        }

        // Also check for sharded safetensors (e.g., model-00001-of-00002.safetensors)
        let hasShardedWeights: Bool
        if let contents = try? fm.contentsOfDirectory(atPath: path.path) {
            hasShardedWeights = contents.contains { $0.hasSuffix(".safetensors") }
        } else {
            hasShardedWeights = false
        }

        return hasStandardWeights || hasShardedWeights
    }

    // MARK: - Model Discovery

    /// Discover all valid models in the models directory
    /// Scans both the default model location and custom models directory
    /// - Returns: Array of discovered models with their metadata
    static func discoverModels() -> [DiscoveredModel] {
        let fm = FileManager.default
        var models: [DiscoveredModel] = []

        // Check default model
        if isValidModel(at: defaultModelDir) {
            models.append(DiscoveredModel(
                name: "Qwen3-0.6B-MLX-8bit",
                path: defaultModelDir,
                isDefault: true
            ))
        }

        // Scan custom models directory
        if let contents = try? fm.contentsOfDirectory(
            at: customModelsDir,
            includingPropertiesForKeys: [.isDirectoryKey]
        ) {
            for url in contents {
                // Check if it's a directory
                var isDirectory: ObjCBool = false
                guard fm.fileExists(atPath: url.path, isDirectory: &isDirectory),
                      isDirectory.boolValue else {
                    continue
                }

                // Validate and add if valid
                if isValidModel(at: url) {
                    models.append(DiscoveredModel(
                        name: url.lastPathComponent,
                        path: url,
                        isDefault: false
                    ))
                }
            }
        }

        // Also check for predefined models in modelsDir (non-custom)
        if let contents = try? fm.contentsOfDirectory(
            at: modelsDir,
            includingPropertiesForKeys: [.isDirectoryKey]
        ) {
            for url in contents {
                // Skip custom directory and already-added default model
                if url.lastPathComponent == "custom" ||
                   url.lastPathComponent == "qwen3-0.6b-mlx-8bit" {
                    continue
                }

                var isDirectory: ObjCBool = false
                guard fm.fileExists(atPath: url.path, isDirectory: &isDirectory),
                      isDirectory.boolValue else {
                    continue
                }

                if isValidModel(at: url) {
                    models.append(DiscoveredModel(
                        name: url.lastPathComponent,
                        path: url,
                        isDefault: false
                    ))
                }
            }
        }

        return models
    }

    /// Get path for a model by ID
    /// - Parameter modelId: The model identifier (e.g., "qwen3-0.6b-mlx-8bit")
    /// - Returns: URL to the model directory
    static func modelPath(for modelId: String) -> URL {
        modelsDir.appendingPathComponent(modelId, isDirectory: true)
    }
}
