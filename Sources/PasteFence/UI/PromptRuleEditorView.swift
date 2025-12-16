import SwiftUI

// MARK: - Editor Mode

enum PromptRuleEditorMode: Identifiable {
    case add
    case edit(PromptRule)

    var id: String {
        switch self {
        case .add: return "add"
        case .edit(let rule): return rule.id.uuidString
        }
    }

    var title: String {
        switch self {
        case .add: return "Add Custom Rule"
        case .edit: return "Edit Custom Rule"
        }
    }

    var saveButtonTitle: String {
        switch self {
        case .add: return "Save Rule"
        case .edit: return "Update Rule"
        }
    }
}

// MARK: - Prompt Rule Editor View

struct PromptRuleEditorView: View {
    @ObservedObject var rulesManager: PromptRulesManager
    let mode: PromptRuleEditorMode

    @Environment(\.dismiss) private var dismiss

    // Form fields
    @State private var name: String = ""
    @State private var description: String = ""
    @State private var examples: [String] = []
    @State private var maskLabel: String = ""
    @State private var newExample: String = ""

    // Validation
    @State private var showValidationError = false
    @State private var validationMessage = ""

    // Test section state
    @State private var testText: String = ""
    @State private var testResults: [PromptTestResult] = []
    @State private var isTesting: Bool = false
    @State private var testError: String?

    init(rulesManager: PromptRulesManager, mode: PromptRuleEditorMode) {
        self.rulesManager = rulesManager
        self.mode = mode

        // Pre-populate for edit mode
        if case .edit(let rule) = mode {
            _name = State(initialValue: rule.name)
            _description = State(initialValue: rule.description)
            _examples = State(initialValue: rule.examples)
            _maskLabel = State(initialValue: rule.maskLabel)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Form Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    nameField
                    descriptionField
                    examplesSection
                    maskLabelField

                    Divider()
                        .padding(.vertical, 4)

                    testSection
                }
                .padding()
            }

            Divider()

            // Footer with buttons
            footerView
        }
        .frame(width: 500, height: 650)
        .accessibilityIdentifier("promptRuleEditorView")
        .alert("Validation Error", isPresented: $showValidationError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(validationMessage)
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Text(mode.title)
                .font(.headline)

            Spacer()

            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
            .accessibilityIdentifier("closeEditorButton")
        }
        .padding()
    }

    // MARK: - Name Field

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Name")
                .font(.subheadline)
                .fontWeight(.medium)

            TextField("e.g., Project Codenames", text: $name)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("ruleNameField")
        }
    }

    // MARK: - Description Field

    private var descriptionField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Description")
                .font(.subheadline)
                .fontWeight(.medium)

            Text("Explain what to detect. This is sent to the LLM.")
                .font(.caption)
                .foregroundColor(.secondary)

            TextEditor(text: $description)
                .frame(height: 80)
                .font(.body)
                .padding(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .accessibilityIdentifier("ruleDescriptionField")
        }
    }

    // MARK: - Examples Section

    private var examplesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Examples")
                .font(.subheadline)
                .fontWeight(.medium)

            Text("Add example values to improve detection accuracy.")
                .font(.caption)
                .foregroundColor(.secondary)

            // Example tags
            PromptFlowLayout(spacing: 8) {
                ForEach(examples, id: \.self) { example in
                    PromptExampleTag(text: example) {
                        examples.removeAll { $0 == example }
                    }
                }
            }

            // Add example input
            HStack {
                TextField("Add example...", text: $newExample)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        addExample()
                    }
                    .accessibilityIdentifier("newExampleField")

                Button(action: addExample) {
                    Image(systemName: "plus.circle.fill")
                }
                .disabled(newExample.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityIdentifier("addExampleButton")
            }
        }
    }

    private func addExample() {
        let trimmed = newExample.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !examples.contains(trimmed) else { return }
        examples.append(trimmed)
        newExample = ""
    }

    // MARK: - Mask Label Field

    private var maskLabelField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Mask Label")
                .font(.subheadline)
                .fontWeight(.medium)

            Text("Label used when masking detected items.")
                .font(.caption)
                .foregroundColor(.secondary)

            TextField("e.g., PROJECT", text: $maskLabel)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("maskLabelField")

            // Preview
            if !maskLabel.isEmpty {
                HStack(spacing: 4) {
                    Text("Preview:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("[CUSTOM_\(maskLabel.uppercased())_MASKED]")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.teal)
                }
                .accessibilityIdentifier("maskLabelPreview")
            }
        }
    }

    // MARK: - Test Section

    private var testSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Test Your Rule")
                .font(.subheadline)
                .fontWeight(.medium)

            // Sample text input
            VStack(alignment: .leading, spacing: 6) {
                Text("Sample Text")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextEditor(text: $testText)
                    .frame(height: 60)
                    .font(.body)
                    .padding(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .accessibilityIdentifier("testSampleTextField")
            }

            // Test button
            Button(action: runTest) {
                HStack {
                    if isTesting {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 16, height: 16)
                    } else {
                        Image(systemName: "play.fill")
                    }
                    Text(isTesting ? "Testing..." : "Test Rule")
                }
            }
            .buttonStyle(.bordered)
            .disabled(isTesting || !canTest)
            .accessibilityIdentifier("testRuleButton")

            // Results
            if let error = testError {
                testErrorView(error)
            } else if !testResults.isEmpty {
                testResultsView
            } else if !isTesting && !testText.isEmpty && canTest {
                Text("Click 'Test Rule' to see what would be detected.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var canTest: Bool {
        !testText.trimmingCharacters(in: .whitespaces).isEmpty &&
        !description.trimmingCharacters(in: .whitespaces).isEmpty &&
        !maskLabel.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func testErrorView(_ error: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)

            Text(error)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(8)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(6)
        .accessibilityIdentifier("testErrorView")
    }

    private var testResultsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Results:")
                .font(.caption)
                .fontWeight(.medium)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(testResults) { result in
                    PromptTestResultRow(result: result)
                }
            }
            .padding(8)
            .background(Color.green.opacity(0.05))
            .cornerRadius(6)
        }
        .accessibilityIdentifier("testResultsView")
    }

    @MainActor
    private func runTest() {
        guard canTest else { return }

        isTesting = true
        testResults = []
        testError = nil

        Task {
            do {
                let results = try await performTest()
                testResults = results
                if results.isEmpty {
                    testError = "No matches found. Try adjusting your description or examples."
                }
            } catch {
                testError = error.localizedDescription
            }
            isTesting = false
        }
    }

    private func performTest() async throws -> [PromptTestResult] {
        // Simple pattern matching against examples for MVP
        // This provides instant feedback without LLM dependency
        var results: [PromptTestResult] = []
        let trimmedTestText = testText.trimmingCharacters(in: .whitespaces)

        // Check each example against the test text
        for example in examples {
            if trimmedTestText.localizedCaseInsensitiveContains(example) {
                results.append(PromptTestResult(text: example, confidence: 1.0))
            }
        }

        // Simulate a small delay for better UX
        try await Task.sleep(nanoseconds: 300_000_000) // 300ms

        return results
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack {
            Spacer()

            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.escape, modifiers: [])
            .accessibilityIdentifier("cancelRuleButton")

            Button(mode.saveButtonTitle) {
                saveRule()
            }
            .keyboardShortcut(.return, modifiers: .command)
            .buttonStyle(.borderedProminent)
            .disabled(!isFormValid)
            .accessibilityIdentifier("saveRuleButton")
        }
        .padding()
    }

    // MARK: - Validation

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !description.trimmingCharacters(in: .whitespaces).isEmpty &&
        !maskLabel.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Save

    private func saveRule() {
        guard isFormValid else {
            validationMessage = "Please fill in all required fields."
            showValidationError = true
            return
        }

        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedDesc = description.trimmingCharacters(in: .whitespaces)
        let trimmedLabel = maskLabel.trimmingCharacters(in: .whitespaces).uppercased()

        switch mode {
        case .add:
            let rule = PromptRule(
                name: trimmedName,
                description: trimmedDesc,
                patternExamples: "",
                examples: examples,
                maskLabel: trimmedLabel,
                isBuiltIn: false
            )
            rulesManager.addRule(rule)

        case .edit(let existingRule):
            var updated = existingRule
            updated.name = trimmedName
            updated.description = trimmedDesc
            updated.examples = examples
            updated.maskLabel = trimmedLabel
            rulesManager.updateRule(updated)
        }

        dismiss()
    }
}

// MARK: - Test Result Model

struct PromptTestResult: Identifiable {
    let id = UUID()
    let text: String
    let confidence: Double
}

// MARK: - Test Result Row

struct PromptTestResultRow: View {
    let result: PromptTestResult

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.caption)

            Text("\"\(result.text)\"")
                .font(.caption)
                .fontWeight(.medium)

            Text("detected")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            Text(String(format: "%.0f%%", result.confidence * 100))
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Example Tag

struct PromptExampleTag: View {
    let text: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.caption)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(text)")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.accentColor.opacity(0.1))
        .cornerRadius(4)
    }
}

// MARK: - Flow Layout

struct PromptFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = PromptFlowResult(
            in: proposal.width ?? 0,
            spacing: spacing,
            subviews: subviews
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = PromptFlowResult(
            in: bounds.width,
            spacing: spacing,
            subviews: subviews
        )

        for (index, subview) in subviews.enumerated() {
            subview.place(
                at: CGPoint(
                    x: bounds.minX + result.positions[index].x,
                    y: bounds.minY + result.positions[index].y
                ),
                proposal: ProposedViewSize(result.sizes[index])
            )
        }
    }

    struct PromptFlowResult {
        var positions: [CGPoint] = []
        var sizes: [CGSize] = []
        var size: CGSize = .zero

        init(in maxWidth: CGFloat, spacing: CGFloat, subviews: Subviews) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth, x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                sizes.append(size)
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}

// MARK: - Preview

#Preview("Add Mode") {
    PromptRuleEditorView(
        rulesManager: PromptRulesManager(),
        mode: .add
    )
}

#Preview("Edit Mode") {
    let rule = PromptRule(
        name: "Project Codenames",
        description: "Detect internal project names used within the company",
        patternExamples: "",
        examples: ["Phoenix", "Atlas", "Titan-2024"],
        maskLabel: "PROJECT",
        isBuiltIn: false
    )
    return PromptRuleEditorView(
        rulesManager: PromptRulesManager(),
        mode: .edit(rule)
    )
}
