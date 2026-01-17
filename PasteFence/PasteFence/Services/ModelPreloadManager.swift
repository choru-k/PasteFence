import Foundation
import Combine

// MARK: - Model Preload Manager

/// Manages background model preloading for reduced first-use latency
/// Preloads LLM model 2 seconds after app launch for instant masking
@MainActor
public final class ModelPreloadManager: ObservableObject {

    // MARK: - Shared Instance

    public static let shared = ModelPreloadManager()

    // MARK: - Preload State

    public enum PreloadState: Equatable {
        case idle
        case waiting       // Waiting for delay before preload
        case preloading
        case ready
        case failed(String)

        public static func == (lhs: PreloadState, rhs: PreloadState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.waiting, .waiting), (.preloading, .preloading), (.ready, .ready):
                return true
            case (.failed(let a), .failed(let b)):
                return a == b
            default:
                return false
            }
        }
    }

    // MARK: - Published State

    @Published public private(set) var state: PreloadState = .idle
    @Published public private(set) var progress: Double = 0.0

    // MARK: - Private Properties

    private var preloadTask: Task<Void, Never>?
    private var memoryPressureSource: DispatchSourceMemoryPressure?
    private weak var maskingEngine: MaskingEngine?

    // MARK: - Initialization

    private init() {
        setupMemoryPressureHandler()
    }

    deinit {
        memoryPressureSource?.cancel()
    }

    // MARK: - Configuration

    /// Set the masking engine to receive preloaded LLM
    func configure(maskingEngine: MaskingEngine) {
        self.maskingEngine = maskingEngine
    }

    // MARK: - Preloading

    /// Start preloading the model after a delay
    /// - Parameter delay: Delay in seconds before starting (default: 2.0)
    public func startPreloading(delay: TimeInterval = 2.0) {
        // Cancel any existing preload
        preloadTask?.cancel()

        // Check if model is available
        guard let activeModel = ModelManager.shared.activeModel,
              ModelManager.shared.isDownloaded(activeModel) else {
            logInfo("No model available for preloading", category: .llm)
            state = .idle
            return
        }

        state = .waiting
        progress = 0.0

        preloadTask = Task { [weak self] in
            // Wait for delay
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

            guard !Task.isCancelled else { return }

            await self?.performPreload()
        }
    }

    /// Invalidate current preload (e.g., when model changes)
    public func invalidate() {
        preloadTask?.cancel()
        preloadTask = nil

        // Tell masking engine to release its LLM
        if let engine = maskingEngine {
            Task {
                await engine.releaseLLM()
            }
        }

        state = .idle
        progress = 0.0

        logInfo("Preload invalidated", category: .llm)
    }

    // MARK: - Private Methods

    private func performPreload() async {
        guard let activeModel = ModelManager.shared.activeModel else {
            state = .idle
            return
        }

        state = .preloading
        progress = 0.1

        let modelPath = ModelManager.shared.modelPath(for: activeModel)

        logInfo("Starting model preload: \(activeModel.name)", category: .llm)

        do {
            // Initialize LLM in masking engine
            guard let engine = maskingEngine else {
                logWarning("No masking engine configured for preload", category: .llm)
                state = .failed("No masking engine")
                return
            }

            // Progress updates during load
            progress = 0.3

            try await engine.initializeLLM(modelPath: modelPath)

            progress = 1.0
            state = .ready

            logInfo("Model preloaded successfully: \(activeModel.name)", category: .llm)

        } catch {
            let errorMessage = error.localizedDescription
            state = .failed(errorMessage)
            logError(error)
        }
    }

    // MARK: - Memory Pressure Handling

    private func setupMemoryPressureHandler() {
        memoryPressureSource = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: .main
        )

        memoryPressureSource?.setEventHandler { [weak self] in
            Task { @MainActor in
                self?.handleMemoryPressure()
            }
        }

        memoryPressureSource?.resume()
    }

    private func handleMemoryPressure() {
        guard state == .ready else { return }

        logWarning("Memory pressure detected - releasing preloaded model", category: .llm)

        // Release the preloaded model
        if let engine = maskingEngine {
            Task {
                await engine.releaseLLM()
            }
        }

        state = .idle
        progress = 0.0
    }

    // MARK: - Status Helpers

    /// Human-readable status text
    public var statusText: String {
        switch state {
        case .idle:
            return "Model not loaded"
        case .waiting:
            return "Preparing to load..."
        case .preloading:
            return "Loading model... \(Int(progress * 100))%"
        case .ready:
            return "Model ready"
        case .failed(let error):
            return "Load failed: \(error)"
        }
    }

    /// SF Symbol name for current state
    public var statusSymbol: String {
        switch state {
        case .idle:
            return "circle"
        case .waiting, .preloading:
            return "arrow.clockwise"
        case .ready:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.circle.fill"
        }
    }

    /// Whether model is ready to use
    public var isReady: Bool {
        state == .ready
    }
}
