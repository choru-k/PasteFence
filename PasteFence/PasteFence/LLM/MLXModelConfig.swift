import Foundation

// MARK: - MLX Model Configuration

/// Configuration for MLX-compatible models (Qwen3 family)
/// Loaded from config.json in the model directory
struct MLXModelConfig: Codable, Equatable {
    // MARK: - Required Fields

    /// Model architecture type (e.g., "qwen3")
    let modelType: String

    /// Vocabulary size for tokenization
    let vocabSize: Int

    /// Hidden layer dimension
    let hiddenSize: Int

    /// Number of transformer layers
    let numHiddenLayers: Int

    /// Number of attention heads
    let numAttentionHeads: Int

    /// Number of key-value heads (for GQA)
    let numKeyValueHeads: Int

    /// Intermediate (FFN) layer size
    let intermediateSize: Int

    /// Maximum sequence length
    let maxPositionEmbeddings: Int

    // MARK: - Optional Fields with Defaults

    /// RMS normalization epsilon
    let rmsNormEps: Double

    /// RoPE theta for positional encoding
    let ropeTheta: Double

    /// Whether to tie input/output embeddings
    let tieWordEmbeddings: Bool

    // MARK: - CodingKeys for snake_case JSON

    enum CodingKeys: String, CodingKey {
        case modelType = "model_type"
        case vocabSize = "vocab_size"
        case hiddenSize = "hidden_size"
        case numHiddenLayers = "num_hidden_layers"
        case numAttentionHeads = "num_attention_heads"
        case numKeyValueHeads = "num_key_value_heads"
        case intermediateSize = "intermediate_size"
        case maxPositionEmbeddings = "max_position_embeddings"
        case rmsNormEps = "rms_norm_eps"
        case ropeTheta = "rope_theta"
        case tieWordEmbeddings = "tie_word_embeddings"
    }

    // MARK: - Custom Decoder with Defaults

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Required fields - throw if missing
        modelType = try container.decode(String.self, forKey: .modelType)
        vocabSize = try container.decode(Int.self, forKey: .vocabSize)
        hiddenSize = try container.decode(Int.self, forKey: .hiddenSize)
        numHiddenLayers = try container.decode(Int.self, forKey: .numHiddenLayers)
        numAttentionHeads = try container.decode(Int.self, forKey: .numAttentionHeads)
        numKeyValueHeads = try container.decode(Int.self, forKey: .numKeyValueHeads)
        intermediateSize = try container.decode(Int.self, forKey: .intermediateSize)
        maxPositionEmbeddings = try container.decode(Int.self, forKey: .maxPositionEmbeddings)

        // Optional fields with sensible defaults
        rmsNormEps = try container.decodeIfPresent(Double.self, forKey: .rmsNormEps) ?? 1e-6
        ropeTheta = try container.decodeIfPresent(Double.self, forKey: .ropeTheta) ?? 10000.0
        tieWordEmbeddings = try container.decodeIfPresent(Bool.self, forKey: .tieWordEmbeddings) ?? false
    }

    // MARK: - Memberwise Init (for testing)

    init(
        modelType: String,
        vocabSize: Int,
        hiddenSize: Int,
        numHiddenLayers: Int,
        numAttentionHeads: Int,
        numKeyValueHeads: Int,
        intermediateSize: Int,
        maxPositionEmbeddings: Int,
        rmsNormEps: Double = 1e-6,
        ropeTheta: Double = 10000.0,
        tieWordEmbeddings: Bool = false
    ) {
        self.modelType = modelType
        self.vocabSize = vocabSize
        self.hiddenSize = hiddenSize
        self.numHiddenLayers = numHiddenLayers
        self.numAttentionHeads = numAttentionHeads
        self.numKeyValueHeads = numKeyValueHeads
        self.intermediateSize = intermediateSize
        self.maxPositionEmbeddings = maxPositionEmbeddings
        self.rmsNormEps = rmsNormEps
        self.ropeTheta = ropeTheta
        self.tieWordEmbeddings = tieWordEmbeddings
    }
}

// MARK: - Supported Model Types

extension MLXModelConfig {
    /// Model types currently supported by the engine
    static let supportedModelTypes: Set<String> = ["qwen3"]

    /// Check if this config's model type is supported
    var isSupported: Bool {
        Self.supportedModelTypes.contains(modelType)
    }
}

// MARK: - Config Loader

enum MLXModelConfigLoader {

    /// Load and validate model configuration from a model directory
    /// - Parameter modelPath: Path to the model directory containing config.json
    /// - Returns: Validated MLXModelConfig
    /// - Throws: LLMError for various failure modes
    static func load(from modelPath: String) throws -> MLXModelConfig {
        let modelURL = URL(fileURLWithPath: modelPath)
        let configURL = modelURL.appendingPathComponent("config.json")

        // Step 1: Check file exists
        guard FileManager.default.fileExists(atPath: configURL.path) else {
            throw LLMError.configNotFound(path: configURL.path)
        }

        // Step 2: Read file data
        let data: Data
        do {
            data = try Data(contentsOf: configURL)
        } catch {
            throw LLMError.configInvalidJSON(underlyingError: error)
        }

        // Step 3: Decode JSON
        let config: MLXModelConfig
        do {
            config = try JSONDecoder().decode(MLXModelConfig.self, from: data)
        } catch let error as DecodingError {
            throw mapDecodingError(error)
        } catch {
            throw LLMError.configInvalidJSON(underlyingError: error)
        }

        // Step 4: Validate config
        try validate(config)

        return config
    }

    // MARK: - Private Helpers

    /// Map DecodingError to specific LLMError cases
    private static func mapDecodingError(_ error: DecodingError) -> LLMError {
        switch error {
        case .keyNotFound(let key, _):
            return .configMissingField(field: key.stringValue)
        case .typeMismatch(_, let context):
            let field = context.codingPath.map(\.stringValue).joined(separator: ".")
            return .configInvalidValue(field: field, reason: "type mismatch")
        case .valueNotFound(_, let context):
            let field = context.codingPath.map(\.stringValue).joined(separator: ".")
            return .configMissingField(field: field)
        case .dataCorrupted(let context):
            return .configInvalidJSON(underlyingError: NSError(
                domain: "MLXModelConfigLoader",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: context.debugDescription]
            ))
        @unknown default:
            return .configInvalidJSON(underlyingError: error)
        }
    }

    /// Validate config values for semantic correctness
    private static func validate(_ config: MLXModelConfig) throws {
        // Validate model type
        guard config.isSupported else {
            throw LLMError.configUnsupportedModelType(
                type: config.modelType,
                supported: Array(MLXModelConfig.supportedModelTypes).sorted()
            )
        }

        // Validate numeric ranges
        if config.vocabSize <= 0 {
            throw LLMError.configInvalidValue(
                field: "vocab_size",
                reason: "must be positive, got \(config.vocabSize)"
            )
        }

        if config.hiddenSize <= 0 {
            throw LLMError.configInvalidValue(
                field: "hidden_size",
                reason: "must be positive, got \(config.hiddenSize)"
            )
        }

        if config.numHiddenLayers <= 0 {
            throw LLMError.configInvalidValue(
                field: "num_hidden_layers",
                reason: "must be positive, got \(config.numHiddenLayers)"
            )
        }

        if config.numAttentionHeads <= 0 {
            throw LLMError.configInvalidValue(
                field: "num_attention_heads",
                reason: "must be positive, got \(config.numAttentionHeads)"
            )
        }

        if config.numKeyValueHeads <= 0 || config.numKeyValueHeads > config.numAttentionHeads {
            throw LLMError.configInvalidValue(
                field: "num_key_value_heads",
                reason: "must be between 1 and num_attention_heads (\(config.numAttentionHeads)), got \(config.numKeyValueHeads)"
            )
        }

        if config.intermediateSize <= 0 {
            throw LLMError.configInvalidValue(
                field: "intermediate_size",
                reason: "must be positive, got \(config.intermediateSize)"
            )
        }

        if config.maxPositionEmbeddings <= 0 {
            throw LLMError.configInvalidValue(
                field: "max_position_embeddings",
                reason: "must be positive, got \(config.maxPositionEmbeddings)"
            )
        }

        if config.rmsNormEps <= 0 {
            throw LLMError.configInvalidValue(
                field: "rms_norm_eps",
                reason: "must be positive, got \(config.rmsNormEps)"
            )
        }

        if config.ropeTheta <= 0 {
            throw LLMError.configInvalidValue(
                field: "rope_theta",
                reason: "must be positive, got \(config.ropeTheta)"
            )
        }
    }
}
