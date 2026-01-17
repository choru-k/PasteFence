import SwiftUI
import AppKit

/// Controller for the preview window
class PreviewWindowController: NSWindowController {
    private var completionHandler: ((String?) -> Void)?
    private var hasCompleted = false  // Prevents double-completion (continuation leak)

    /// Completes with the given result, ensuring completion is called exactly once.
    /// This prevents the continuation leak where both button callbacks AND windowWillClose
    /// would both try to call completion, causing either double-resume or leaked continuation.
    private func completeOnce(with result: String?) {
        guard !hasCompleted else { return }
        hasCompleted = true
        // Restore accessory policy (no dock icon) before completing
        NSApp.setActivationPolicy(.accessory)
        completionHandler?(result)
    }

    convenience init(
        original: String,
        masked: String,
        detectedItems: [DetectedItem],
        completion: @escaping (String?) -> Void
    ) {
        // We need to create the window first, then set up the view with callbacks
        // that reference self. This is a two-phase initialization.
        let placeholderWindow = NSWindow()
        self.init(window: placeholderWindow)
        self.completionHandler = completion

        // Now create the content view with callbacks that use self
        let contentView = PreviewView(
            original: original,
            masked: masked,
            detectedItems: detectedItems,
            onApprove: { [weak self] selectedMaskedText in
                self?.completeOnce(with: selectedMaskedText)
            },
            onCancel: { [weak self] in
                self?.completeOnce(with: nil)
            }
        )

        let hostingController = NSHostingController(rootView: contentView)

        let actualWindow = NSWindow(contentViewController: hostingController)
        actualWindow.title = "PasteFence - Preview"
        actualWindow.identifier = NSUserInterfaceItemIdentifier("previewWindow")
        actualWindow.styleMask = [.titled, .closable, .resizable]
        actualWindow.setContentSize(NSSize(width: 600, height: 500))
        actualWindow.center()
        actualWindow.level = .floating
        actualWindow.isReleasedWhenClosed = false

        // Replace placeholder window with actual window
        self.window = actualWindow

        // Handle window close
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillClose),
            name: NSWindow.willCloseNotification,
            object: actualWindow
        )
    }

    override func showWindow(_ sender: Any?) {
        // Temporarily become a regular app to properly activate
        // (accessory apps don't show in menu bar as active app)
        NSApp.setActivationPolicy(.regular)
        super.showWindow(sender)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    @objc private func windowWillClose(_ notification: Notification) {
        completeOnce(with: nil)  // nil indicates window was closed (cancelled)
    }
}

// MARK: - SwiftUI Preview View

struct PreviewView: View {
    let original: String
    let masked: String
    let detectedItems: [DetectedItem]
    let onApprove: (String) -> Void  // Now passes the user-selected masked text
    let onCancel: () -> Void

    @State private var selectedTab = 0
    @State private var excludedItems: Set<UUID> = []

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Content
            HSplitView {
                // Left: Original/Masked text
                textComparisonView
                    .frame(minWidth: 300)

                // Right: Detected items list
                detectedItemsView
                    .frame(minWidth: 200, maxWidth: 250)
            }

            Divider()

            // Footer with actions
            footerView
        }
        .frame(minWidth: 600, minHeight: 400)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Image(systemName: "shield.lefthalf.filled")
                .font(.title2)
                .foregroundColor(.accentColor)

            VStack(alignment: .leading) {
                Text("Review Masked Content")
                    .font(.headline)
                Text("\(detectedItems.count) sensitive items detected")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Text Comparison

    private var textComparisonView: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                Text("Masked").tag(0)
                Text("Original").tag(1)
                Text("Diff").tag(2)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("viewTabs")
            .padding()

            ScrollView {
                Group {
                    switch selectedTab {
                    case 0:
                        maskedTextView
                    case 1:
                        originalTextView
                    case 2:
                        diffView
                    default:
                        maskedTextView
                    }
                }
                .padding()
            }
            .background(Color(NSColor.textBackgroundColor))
        }
    }

    private var maskedTextView: some View {
        Text(computedMaskedText)
            .font(.system(.body, design: .monospaced))
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("maskedText")
    }

    private var originalTextView: some View {
        highlightedOriginalText
            .font(.system(.body, design: .monospaced))
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("originalText")
    }

    private var highlightedOriginalText: some View {
        var result = Text("")
        var currentIndex = original.startIndex

        let sortedItems = detectedItems
            .filter { !excludedItems.contains($0.id) }
            .sorted { $0.range.lowerBound < $1.range.lowerBound }

        for item in sortedItems {
            // Add text before this item
            if currentIndex < item.range.lowerBound {
                let beforeText = String(original[currentIndex..<item.range.lowerBound])
                result = result + Text(beforeText)
            }

            // Add highlighted item
            let itemText = String(original[item.range])
            result = result + Text(itemText)
                .foregroundColor(.red)
                .bold()
                .underline()

            currentIndex = item.range.upperBound
        }

        // Add remaining text
        if currentIndex < original.endIndex {
            let remainingText = String(original[currentIndex...])
            result = result + Text(remainingText)
        }

        return result
    }

    private var diffView: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(detectedItems.filter { !excludedItems.contains($0.id) }) { item in
                HStack {
                    Text(item.text)
                        .strikethrough()
                        .foregroundColor(.red)
                    Text("→")
                        .foregroundColor(.secondary)
                    Text(item.type.maskLabel)
                        .foregroundColor(.green)
                }
                .font(.system(.body, design: .monospaced))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("diffView")
    }

    // MARK: - Detected Items List

    private var detectedItemsView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Detected Items")
                .font(.headline)
                .padding()

            Divider()

            // Bulk actions and count
            bulkActionsView

            Divider()

            List {
                ForEach(detectedItems) { item in
                    DetectedItemRow(
                        item: item,
                        isExcluded: excludedItems.contains(item.id),
                        onToggle: {
                            if excludedItems.contains(item.id) {
                                excludedItems.remove(item.id)
                            } else {
                                excludedItems.insert(item.id)
                            }
                        }
                    )
                }
            }
            .listStyle(.plain)
            .accessibilityIdentifier("detectedItemsList")
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Bulk Actions

    private var bulkActionsView: some View {
        HStack {
            Button("Select All") {
                excludedItems.removeAll()
            }
            .disabled(excludedItems.isEmpty)
            .buttonStyle(.borderless)
            .accessibilityIdentifier("selectAllButton")

            Button("Deselect All") {
                excludedItems = Set(detectedItems.map(\.id))
            }
            .disabled(excludedItems.count == detectedItems.count)
            .buttonStyle(.borderless)
            .accessibilityIdentifier("deselectAllButton")

            Spacer()

            Text("\(detectedItems.count - excludedItems.count) of \(detectedItems.count) selected")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack {
            Button("Cancel") {
                onCancel()
                NSApp.keyWindow?.close()
            }
            .keyboardShortcut(.cancelAction)
            .accessibilityIdentifier("cancelButton")

            Spacer()

            Text("Press ⌘↩ to paste")
                .font(.caption)
                .foregroundColor(.secondary)

            Button("Paste Masked") {
                onApprove(computedMaskedText)
                NSApp.keyWindow?.close()
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("pasteMaskedButton")
        }
        .padding()
    }

    // MARK: - Computed Properties

    private var computedMaskedText: String {
        let itemsToMask = detectedItems.filter { !excludedItems.contains($0.id) }
        guard !itemsToMask.isEmpty else { return original }

        var result = original
        for item in itemsToMask.sorted(by: { $0.range.lowerBound > $1.range.lowerBound }) {
            result.replaceSubrange(item.range, with: item.type.maskLabel)
        }
        return result
    }
}

// MARK: - Detected Item Row

struct DetectedItemRow: View {
    let item: DetectedItem
    let isExcluded: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack {
            Toggle("", isOn: Binding(
                get: { !isExcluded },
                set: { _ in onToggle() }
            ))
            .toggleStyle(.checkbox)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.text)
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .strikethrough(isExcluded)
                    .foregroundColor(isExcluded ? .secondary : .primary)

                HStack(spacing: 4) {
                    Text(item.type.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(typeColor.opacity(0.2))
                        .foregroundColor(typeColor)
                        .cornerRadius(3)

                    // Source attribution: show rule name for regex, "LLM" for LLM
                    if item.source == .llm {
                        HStack(spacing: 2) {
                            Image(systemName: "brain")
                                .font(.caption2)
                            Text("LLM")
                                .font(.caption2)
                        }
                        .foregroundColor(.purple)
                    } else {
                        HStack(spacing: 2) {
                            Image(systemName: "textformat.abc")
                                .font(.caption2)
                            if let ruleName = item.ruleName, !ruleName.isEmpty {
                                Text(ruleName)
                                    .font(.caption2)
                                    .lineLimit(1)
                            }
                        }
                        .foregroundColor(.gray)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var typeColor: Color {
        switch item.type {
        case .email: return .blue
        case .phone: return .green
        case .creditCard: return .orange
        case .apiKey, .awsKey: return .red
        case .jwt, .privateKey: return .purple
        case .password, .genericSecret: return .pink
        case .ipAddress: return .cyan
        // Phase 1: Financial & Communication Services
        case .ssn: return .orange
        case .stripeKey, .sendGridKey, .twilioKey: return .red
        case .databaseUrl: return .purple
        case .bearerToken: return .red
        // Phase 2: Infrastructure & Cloud
        case .webhookUrl: return .indigo
        case .envVariable: return .brown
        case .sessionToken: return .pink
        case .gcpKey, .azureKey: return .red
        // Phase 3: Specialized Patterns
        case .iban: return .orange
        case .healthcareId: return .pink
        case .passportNumber: return .indigo
        case .cryptoSeedPhrase: return .yellow
        // Custom user-defined types
        case .custom: return .teal
        }
    }
}

// MARK: - Preview

#Preview {
    PreviewView(
        original: """
        Error connecting to database:
        Connection string: postgres://admin:secret123@192.168.1.100:5432/mydb
        API Key: sk-1234567890abcdef1234567890abcdef
        Contact: john.doe@company.com
        """,
        masked: """
        Error connecting to database:
        Connection string: postgres://admin:[PASSWORD_MASKED]@[IP_ADDRESS_MASKED]:5432/mydb
        API Key: [API_KEY_MASKED]
        Contact: [EMAIL_MASKED]
        """,
        detectedItems: [
            DetectedItem(
                text: "secret123",
                type: .password,
                range: "".startIndex..<"".endIndex,
                confidence: 0.85,
                source: .llm,
                ruleName: nil
            ),
            DetectedItem(
                text: "sk-1234567890abcdef1234567890abcdef",
                type: .apiKey,
                range: "".startIndex..<"".endIndex,
                confidence: 1.0,
                source: .regex,
                ruleName: "OpenAI API Key"
            ),
        ],
        onApprove: { _ in },
        onCancel: {}
    )
    .frame(width: 600, height: 500)
}
