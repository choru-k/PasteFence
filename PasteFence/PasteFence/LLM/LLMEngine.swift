import Foundation
import MLX
import MLXNN
import MLXRandom
import MLXLLM
import MLXLMCommon

// MARK: - Memory Types

/// GPU memory statistics from MLX
struct MemoryStats {
    let activeMemory: Int
    let peakMemory: Int
    let cacheMemory: Int
    let memoryLimit: Int

    var usageRatio: Double {
        guard memoryLimit > 0 else { return 0 }
        return Double(activeMemory) / Double(memoryLimit)
    }

    var formattedActive: String {
        formatBytes(activeMemory)
    }

    var formattedPeak: String {
        formatBytes(peakMemory)
    }

    var formattedCache: String {
        formatBytes(cacheMemory)
    }

    private func formatBytes(_ bytes: Int) -> String {
        let mb = Double(bytes) / (1024 * 1024)
        return String(format: "%.1f MB", mb)
    }
}

/// Memory pressure levels based on GPU memory usage
enum MemoryPressure {
    case normal      // < 50% of memory limit
    case warning     // 50-75%
    case critical    // > 75%
}

// MARK: - LLM Engine

/// Engine for running local LLM inference using MLX via mlx-swift-lm
actor LLMEngine {
    private let huggingFaceId: String
    private var isLoaded = false
    private var modelContainer: ModelContainer?
    private var modelConfig: MLXModelConfig?

    /// Model's maximum context length in tokens (default: 32768 for Qwen3 models)
    let contextLength: Int

    // Memory management
    private var lastUsed: Date = Date()
    private let idleTimeout: TimeInterval = 300  // 5 minutes
    private var idleTimerTask: Task<Void, Never>?

    /// Initialize with a HuggingFace model ID (e.g., "mlx-community/Qwen3-4B-4bit")
    init(huggingFaceId: String, contextLength: Int = 32768) async throws {
        self.huggingFaceId = huggingFaceId
        self.contextLength = contextLength
        try await loadModel()
    }

    /// Initialize with a local model path (backward compatibility)
    /// Extracts HuggingFace ID from ModelManager or uses default
    init(modelPath: String) async throws {
        // Try to find the HuggingFace ID from ModelManager
        // For now, derive from path or use default
        let modelId = Self.deriveHuggingFaceId(from: modelPath)
        self.huggingFaceId = modelId
        self.contextLength = Self.deriveContextLength(from: modelPath)
        try await loadModel()
    }

    /// Derive HuggingFace ID from local model path
    private static func deriveHuggingFaceId(from modelPath: String) -> String {
        // Check if path ends with a known model ID pattern
        let pathComponents = modelPath.split(separator: "/")
        if let lastComponent = pathComponents.last {
            let modelId = String(lastComponent)

            // Map local IDs to HuggingFace IDs
            switch modelId {
            case "qwen3-0.6b-mlx-8bit":
                return "Qwen/Qwen3-0.6B-MLX-8bit"
            case "qwen3-1.7b-mlx-4bit":
                return "Qwen/Qwen3-1.7B-MLX-4bit"
            case "qwen3-4b-mlx-4bit":
                return "Qwen/Qwen3-4B-MLX-4bit"
            default:
                // Fall back to smallest model
                return "Qwen/Qwen3-0.6B-MLX-8bit"
            }
        }

        // Default model
        return "Qwen/Qwen3-0.6B-MLX-8bit"
    }

    /// Derive context length from local model path
    /// All Qwen3 models have 32768 native context length
    private static func deriveContextLength(from modelPath: String) -> Int {
        // All current Qwen3 models share the same context length
        // Could be extended to support different models with different limits
        return 32768
    }

    private func loadModel() async throws {
        print("[LLMEngine] Loading model: \(huggingFaceId)")

        do {
            // Create model configuration from HuggingFace ID
            let config = ModelConfiguration(id: huggingFaceId)

            // Load model container (downloads if needed, uses cache otherwise)
            self.modelContainer = try await LLMModelFactory.shared.loadContainer(
                configuration: config,
                progressHandler: { progress in
                    print("[LLMEngine] Loading: \(Int(progress.fractionCompleted * 100))%")
                }
            )

            self.isLoaded = true
            print("[LLMEngine] Model loaded successfully")

        } catch {
            throw LLMError.modelLoadFailed(underlyingError: error)
        }
    }

    /// Generate text completion using the loaded model
    /// - Parameters:
    ///   - prompt: The input prompt to complete
    ///   - maxTokens: Maximum number of tokens to generate (default: 512)
    ///   - temperature: Sampling temperature (0.0-1.0, default: 0.7). Lower = more deterministic
    ///   - topP: Nucleus sampling threshold (0.0-1.0, default: 0.9). Lower = more focused
    func generate(
        prompt: String,
        maxTokens: Int = 512,
        temperature: Float = 0.7,
        topP: Float = 0.9
    ) async throws -> String {
        guard let container = modelContainer else {
            throw LLMError.modelNotLoaded
        }

        // Update last used timestamp for idle timeout tracking
        lastUsed = Date()

        print("[LLMEngine] Generating response (max \(maxTokens) tokens, temp=\(temperature), topP=\(topP))")
        let startTime = Date()

        do {
            let output = try await container.perform { context in
                let input = UserInput(prompt: prompt)
                let lmInput = try await context.processor.prepare(input: input)

                let result = try MLXLMCommon.generate(
                    input: lmInput,
                    parameters: GenerateParameters(
                        maxTokens: maxTokens,
                        temperature: temperature,
                        topP: topP
                    ),
                    context: context
                ) { tokens in
                    tokens.count >= maxTokens ? .stop : .more
                }

                return result.output
            }

            let elapsed = Date().timeIntervalSince(startTime)
            print("[LLMEngine] Generation completed in \(String(format: "%.2f", elapsed))s")

            return output

        } catch {
            throw LLMError.generationFailed(underlyingError: error)
        }
    }

    /// Check if model is loaded
    var loaded: Bool {
        isLoaded
    }

    // MARK: - Memory Management

    /// Get current GPU memory usage statistics
    func getMemoryUsage() -> MemoryStats {
        let snapshot = GPU.snapshot()
        return MemoryStats(
            activeMemory: snapshot.activeMemory,
            peakMemory: snapshot.peakMemory,
            cacheMemory: snapshot.cacheMemory,
            memoryLimit: GPU.memoryLimit
        )
    }

    /// Check current memory pressure level
    func checkMemoryPressure() -> MemoryPressure {
        let stats = getMemoryUsage()
        switch stats.usageRatio {
        case ..<0.5:
            return .normal
        case 0.5..<0.75:
            return .warning
        default:
            return .critical
        }
    }

    /// Handle memory pressure by adjusting cache or unloading model
    func handleMemoryPressure() {
        let pressure = checkMemoryPressure()
        switch pressure {
        case .normal:
            break
        case .warning:
            print("[LLMEngine] Warning: High memory usage - reducing cache limit")
            GPU.set(cacheLimit: 128 * 1024 * 1024)  // 128MB
        case .critical:
            print("[LLMEngine] Critical memory pressure - unloading model")
            unload()
        }
    }

    /// Start idle timer to automatically unload model after inactivity
    func startIdleTimer() {
        idleTimerTask?.cancel()
        idleTimerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))

                guard let self = self else { break }

                let lastUsedTime = await self.lastUsed
                let timeout = self.idleTimeout  // No await needed - it's a constant
                let isModelLoaded = await self.modelContainer != nil
                let timeSinceLastUse = Date().timeIntervalSince(lastUsedTime)

                if timeSinceLastUse > timeout && isModelLoaded {
                    print("[LLMEngine] Unloading idle model (inactive for \(Int(timeSinceLastUse))s)")
                    await self.unload()
                    break
                }
            }
        }
    }

    /// Stop the idle timer
    func stopIdleTimer() {
        idleTimerTask?.cancel()
        idleTimerTask = nil
    }

    /// Unload model to free memory
    func unload() {
        // Cancel idle timer
        idleTimerTask?.cancel()
        idleTimerTask = nil

        // Release model container
        modelContainer = nil
        isLoaded = false

        // Force GPU cache eviction by setting limit to 0, then restore
        GPU.set(cacheLimit: 0)
        GPU.set(cacheLimit: 256 * 1024 * 1024)  // Restore to 256MB default

        let stats = getMemoryUsage()
        print("[LLMEngine] Model unloaded (GPU memory: \(stats.formattedActive))")
    }
}

// MARK: - Errors
// Note: LLMError is now defined in Sources/PasteFence/Errors/LLMError.swift
// The type alias LLMEngineError → LLMError is provided for backward compatibility
