import Foundation
import AppKit
import Combine

/// Central coordinator for the app's core functionality
/// Manages clipboard, hotkeys, and masking workflow
@MainActor
final class AppCoordinator: ObservableObject {
    // MARK: - Shared Instance
    static var shared: AppCoordinator?

    // MARK: - UI Testing Support
    static var isUITesting: Bool {
        CommandLine.arguments.contains("--ui-testing")
    }

    // MARK: - Services
    private let clipboardService: ClipboardService
    private let hotkeyService: HotkeyService
    private let maskingEngine: MaskingEngine

    // MARK: - State
    @Published var isProcessing = false
    @Published var lastMaskedText: String?
    @Published var lastError: Error?

    private var cancellables = Set<AnyCancellable>()
    private var currentPreviewController: PreviewWindowController?  // Retain preview window

    init() {
        self.clipboardService = ClipboardService()
        self.hotkeyService = HotkeyService()
        self.maskingEngine = MaskingEngine(patternsManager: RegexPatternsManager.shared)
    }

    func start() {
        setupHotkeyHandler()
        setupPreloading()
        print("[AppCoordinator] Started - Press Cmd+Shift+V to mask and paste")
    }

    /// Setup model preloading with automatic reload on model changes
    private func setupPreloading() {
        // Configure preload manager with our masking engine
        ModelPreloadManager.shared.configure(maskingEngine: maskingEngine)

        // Start preloading with 2-second delay
        ModelPreloadManager.shared.startPreloading()

        // Re-preload when active model changes
        NotificationCenter.default.addObserver(
            forName: .activeModelChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard self != nil else { return }
            Task { @MainActor in
                ModelPreloadManager.shared.invalidate()
                ModelPreloadManager.shared.startPreloading()
            }
        }
    }

    /// Initialize LLM if a model is downloaded and active
    func initializeLLMIfAvailable() {
        // Route through PreloadManager to properly update UI state
        // Use delay: 0 for immediate loading after download
        ModelPreloadManager.shared.invalidate()
        ModelPreloadManager.shared.startPreloading(delay: 0)
    }

    /// Public method to trigger mask & paste from menu bar
    func triggerMaskPaste() {
        Task { @MainActor in
            await handleMaskPaste()
        }
    }

    private func setupHotkeyHandler() {
        hotkeyService.onMaskPasteTriggered = { [weak self] in
            Task { @MainActor in
                await self?.handleMaskPaste()
            }
        }
        hotkeyService.register()
    }

    private func handleMaskPaste() async {
        // If preview window is already open, close it to process new clipboard content
        if let existingPreview = currentPreviewController {
            existingPreview.window?.close()  // Triggers completeOnce(nil) via windowWillClose
            currentPreviewController = nil
            // Small delay for window close to complete and isProcessing to reset
            try? await Task.sleep(nanoseconds: 50_000_000)  // 50ms
        }

        guard !isProcessing else {
            print("[AppCoordinator] Already processing, skipping")
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        // 1. Get clipboard content
        guard let clipboardText = clipboardService.getText() else {
            print("[AppCoordinator] No text in clipboard")
            return
        }

        print("[AppCoordinator] Processing clipboard text (\(clipboardText.count) chars)")

        do {
            // 2. Run masking engine (LLMDetector reads rules from PromptRulesManager automatically)
            let result = try await maskingEngine.mask(text: clipboardText)

            // 4. Show preview window and wait for user decision
            // Returns the masked text with user's selections, or nil if cancelled
            let selectedMaskedText = await showPreviewWindow(
                original: clipboardText,
                masked: result.maskedText,
                detectedItems: result.detectedItems
            )

            if let maskedText = selectedMaskedText {
                // 5. Update clipboard with user-selected masked text
                clipboardService.setText(maskedText)
                lastMaskedText = maskedText

                // 6. Simulate paste (Cmd+V)
                simulatePaste()

                print("[AppCoordinator] Masked text pasted successfully")
            } else {
                print("[AppCoordinator] User cancelled masking")
            }

        } catch {
            lastError = error
            print("[AppCoordinator] Error: \(error)")
            // Show error to user with auto-selected presentation style
            ErrorPresenter.shared.presentAuto(error)
        }
    }

    private func showPreviewWindow(
        original: String,
        masked: String,
        detectedItems: [DetectedItem]
    ) async -> String? {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { [weak self] in
                let previewController = PreviewWindowController(
                    original: original,
                    masked: masked,
                    detectedItems: detectedItems
                ) { [weak self] selectedMaskedText in
                    self?.currentPreviewController = nil  // Release after completion
                    continuation.resume(returning: selectedMaskedText)
                }
                self?.currentPreviewController = previewController  // Retain while showing
                previewController.showWindow(nil)
            }
        }
    }

    private func simulatePaste() {
        // Small delay to ensure clipboard is synced before pasting
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Create and post Cmd+V key event
            let source = CGEventSource(stateID: .hidSystemState)

            // Key down
            if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) { // 0x09 = 'v'
                keyDown.flags = .maskCommand
                keyDown.post(tap: .cghidEventTap)
            }

            // Key up
            if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false) {
                keyUp.flags = .maskCommand
                keyUp.post(tap: .cghidEventTap)
            }
        }
    }

    // MARK: - UI Testing Support

    /// Shows a preview window with sample data for UI testing
    /// Call this method when --ui-testing flag is present
    func showTestPreviewWindow() {
        let sampleOriginal = """
        Contact: John Doe
        Email: john.doe@example.com
        Phone: (555) 123-4567
        API Key: sk-test1234567890abcdefghij
        """

        let sampleMasked = """
        Contact: John Doe
        Email: [EMAIL_MASKED]
        Phone: [PHONE_MASKED]
        API Key: [API_KEY_MASKED]
        """

        // Create sample detected items with valid ranges
        let emailRange = sampleOriginal.range(of: "john.doe@example.com")!
        let phoneRange = sampleOriginal.range(of: "(555) 123-4567")!
        let apiKeyRange = sampleOriginal.range(of: "sk-test1234567890abcdefghij")!

        let sampleItems = [
            DetectedItem(
                text: "john.doe@example.com",
                type: .email,
                range: emailRange,
                confidence: 1.0,
                source: .regex,
                ruleName: "Email Address"
            ),
            DetectedItem(
                text: "(555) 123-4567",
                type: .phone,
                range: phoneRange,
                confidence: 1.0,
                source: .regex,
                ruleName: "Phone Number"
            ),
            DetectedItem(
                text: "sk-test1234567890abcdefghij",
                type: .apiKey,
                range: apiKeyRange,
                confidence: 0.95,
                source: .regex,
                ruleName: "OpenAI API Key"
            )
        ]

        let previewController = PreviewWindowController(
            original: sampleOriginal,
            masked: sampleMasked,
            detectedItems: sampleItems
        ) { [weak self] _ in
            self?.currentPreviewController = nil
        }
        currentPreviewController = previewController
        previewController.showWindow(nil)
    }
}
