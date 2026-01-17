import Combine
import Foundation
import MLXLLM
import MLXLMCommon

// MARK: - Notifications

extension Notification.Name {
    /// Posted when the active model changes
    static let activeModelChanged = Notification.Name("com.pastefence.activeModelChanged")
}

/// Manages local LLM model downloads and lifecycle
@MainActor
final class ModelManager: ObservableObject {
    static let shared = ModelManager()

    // MARK: - Published State
    @Published var availableModels: [ModelInfo] = []
    @Published var downloadedModels: [ModelInfo] = []
    @Published var activeModel: ModelInfo?
    @Published var downloadProgress: Double = 0
    @Published var isDownloading = false
    @Published var downloadingModelId: String?  // Track which specific model is downloading
    @Published var downloadError: Error?

    // MARK: - Predefined Models
    private let predefinedModels: [ModelInfo] = [
        ModelInfo(
            id: "qwen3-0.6b-mlx-8bit",
            name: "Qwen3 0.6B (Lightweight)",
            description: "Fastest model, good for basic PII detection",
            size: "~400MB",
            huggingFaceId: "Qwen/Qwen3-0.6B-MLX-8bit",
            isDefault: true,
            contextLength: 32768
        ),
        ModelInfo(
            id: "qwen3-1.7b-mlx-4bit",
            name: "Qwen3 1.7B (Balanced)",
            description: "Better accuracy with moderate resource usage",
            size: "~1GB",
            huggingFaceId: "Qwen/Qwen3-1.7B-MLX-4bit",
            isDefault: false,
            contextLength: 32768
        ),
        ModelInfo(
            id: "qwen3-4b-mlx-4bit",
            name: "Qwen3 4B (Best Quality)",
            description: "Highest accuracy for complex PII detection",
            size: "~2.3GB",
            huggingFaceId: "Qwen/Qwen3-4B-MLX-4bit",
            isDefault: false,
            contextLength: 32768  // Native; supports 131072 with YaRN
        ),
    ]

    private init() {
        // Ensure directories exist using centralized path management
        try? ModelPaths.ensureDirectoriesExist()

        loadConfig()
        availableModels = predefinedModels
        scanDownloadedModels()
    }

    // MARK: - Directory Management

    private func scanDownloadedModels() {
        downloadedModels = predefinedModels.filter { model in
            let modelDir = ModelPaths.modelPath(for: model.id)
            // Use proper validation instead of just checking existence
            return ModelPaths.isValidModel(at: modelDir)
        }
    }

    // MARK: - Config Management

    private func loadConfig() {
        guard let data = try? Data(contentsOf: ModelPaths.configURL),
              let config = try? JSONDecoder().decode(AppConfig.self, from: data) else {
            return
        }

        if let activeModelId = config.activeModelId,
           let model = predefinedModels.first(where: { $0.id == activeModelId }) {
            activeModel = model
        }
    }

    private func saveConfig() {
        let config = AppConfig(activeModelId: activeModel?.id)
        guard let data = try? JSONEncoder().encode(config) else { return }
        try? data.write(to: ModelPaths.configURL)
    }

    // MARK: - Model Operations

    /// Get path to model directory
    func modelPath(for model: ModelInfo) -> String {
        ModelPaths.modelPath(for: model.id).path
    }

    /// Check if model is downloaded
    func isDownloaded(_ model: ModelInfo) -> Bool {
        downloadedModels.contains { $0.id == model.id }
    }

    /// Check if a specific model is currently downloading
    func isDownloading(_ model: ModelInfo) -> Bool {
        downloadingModelId == model.id
    }

    /// Download a model from HuggingFace
    func downloadModel(_ model: ModelInfo) async throws {
        isDownloading = true
        downloadingModelId = model.id
        downloadProgress = 0
        downloadError = nil

        defer {
            isDownloading = false
            downloadingModelId = nil
        }

        let modelDir = ModelPaths.modelPath(for: model.id)

        do {
            // Create model directory
            try FileManager.default.createDirectory(at: modelDir, withIntermediateDirectories: true)

            // Download using huggingface-cli or direct HTTP
            try await downloadFromHuggingFace(model: model, to: modelDir)

            // Update state
            downloadedModels.append(model)

            // Set as active if first model
            if activeModel == nil {
                setActiveModel(model)
            }

            print("[ModelManager] Downloaded model: \(model.name)")

            // Initialize LLM in AppCoordinator now that model is available
            AppCoordinator.shared?.initializeLLMIfAvailable()

        } catch {
            // Cleanup on failure
            try? FileManager.default.removeItem(at: modelDir)
            downloadError = error
            throw error
        }
    }

    private func downloadFromHuggingFace(model: ModelInfo, to directory: URL) async throws {
        print("[ModelManager] Downloading \(model.huggingFaceId) via MLXLLM...")

        // Use MLXLLM's built-in download mechanism
        // LLMModelFactory.loadContainer() downloads if needed and caches to ~/.cache/huggingface/hub/
        let config = ModelConfiguration(id: model.huggingFaceId)

        do {
            // Loading the model container triggers download if not cached
            // We don't need to keep the container - just verify download works
            _ = try await LLMModelFactory.shared.loadContainer(
                configuration: config,
                progressHandler: { [weak self] progress in
                    Task { @MainActor in
                        self?.downloadProgress = progress.fractionCompleted
                    }
                }
            )

            // Create a marker file indicating successful download
            let markerURL = directory.appendingPathComponent(".downloaded")
            try model.huggingFaceId.write(to: markerURL, atomically: true, encoding: .utf8)

            print("[ModelManager] Download complete for \(model.huggingFaceId)")

        } catch {
            print("[ModelManager] Download failed: \(error.localizedDescription)")
            throw ModelManagerError.downloadFailed(model: model.name, underlying: error)
        }
    }

    /// Set the active model
    func setActiveModel(_ model: ModelInfo) {
        activeModel = model
        saveConfig()

        // Notify observers that active model changed
        NotificationCenter.default.post(name: .activeModelChanged, object: model)
    }

    /// Delete a downloaded model
    func deleteModel(_ model: ModelInfo) throws {
        let modelDir = ModelPaths.modelPath(for: model.id)
        try FileManager.default.removeItem(at: modelDir)
        downloadedModels.removeAll { $0.id == model.id }

        if activeModel?.id == model.id {
            activeModel = downloadedModels.first
            saveConfig()
        }
    }

    /// Get default model
    var defaultModel: ModelInfo? {
        predefinedModels.first { $0.isDefault }
    }
}

// MARK: - Models

struct ModelInfo: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let description: String
    let size: String
    let huggingFaceId: String
    let isDefault: Bool
    let contextLength: Int  // Max tokens (e.g., 32768)
}

private struct AppConfig: Codable {
    let activeModelId: String?
}

// MARK: - Errors

enum ModelManagerError: LocalizedError {
    case downloadFailed(model: String, underlying: Error)
    case modelNotFound(id: String)

    var errorDescription: String? {
        switch self {
        case .downloadFailed(let model, let underlying):
            return "Failed to download \(model): \(underlying.localizedDescription)"
        case .modelNotFound(let id):
            return "Model not found: \(id)"
        }
    }
}
