import SwiftUI

// MARK: - Editor Mode

enum CustomRegexEditorMode: Identifiable {
    case add
    case edit(RegexPatternConfig)

    var id: String {
        switch self {
        case .add: return "add"
        case .edit(let pattern): return pattern.id.uuidString
        }
    }

    var title: String {
        switch self {
        case .add: return "Add Custom Pattern"
        case .edit: return "Edit Custom Pattern"
        }
    }

    var saveButtonTitle: String {
        switch self {
        case .add: return "Save Pattern"
        case .edit: return "Update Pattern"
        }
    }
}

// MARK: - Custom Regex Editor View

struct CustomRegexEditorView: View {
    @ObservedObject var patternsManager: RegexPatternsManager
    let mode: CustomRegexEditorMode

    @Environment(\.dismiss) private var dismiss

    // Form fields
    @State private var name: String = ""
    @State private var description: String = ""
    @State private var pattern: String = ""
    @State private var maskLabel: String = ""
    @State private var priority: Int = 9

    // Validation
    @State private var showValidationError = false
    @State private var validationMessage = ""

    // Test section state
    @State private var testText: String = ""
    @State private var testResults: [RegexTestResult] = []
    @State private var isTesting: Bool = false
    @State private var testError: String?

    init(patternsManager: RegexPatternsManager, mode: CustomRegexEditorMode) {
        self.patternsManager = patternsManager
        self.mode = mode

        // Pre-populate for edit mode
        if case .edit(let existingPattern) = mode {
            _name = State(initialValue: existingPattern.name)
            _description = State(initialValue: existingPattern.description)
            _pattern = State(initialValue: existingPattern.pattern)
            // Extract label from sensitiveType (remove CUSTOM_ prefix if present)
            let label = existingPattern.sensitiveType
                .replacingOccurrences(of: "CUSTOM_", with: "")
            _maskLabel = State(initialValue: label)
            _priority = State(initialValue: max(1, Int(round(existingPattern.confidence * 10))))
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
                    patternField
                    maskLabelField
                    priorityStepper

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
        .frame(width: 500, height: 600)
        .accessibilityIdentifier("customRegexEditorView")
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
            .accessibilityIdentifier("closeRegexEditorButton")
        }
        .padding()
    }

    // MARK: - Name Field

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Name")
                .font(.subheadline)
                .fontWeight(.medium)

            TextField("e.g., Internal Project ID", text: $name)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("patternNameField")
        }
    }

    // MARK: - Description Field

    private var descriptionField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Description")
                .font(.subheadline)
                .fontWeight(.medium)

            Text("Optional description of what this pattern detects.")
                .font(.caption)
                .foregroundColor(.secondary)

            TextField("e.g., Detects internal project identifiers", text: $description)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("patternDescriptionField")
        }
    }

    // MARK: - Pattern Field

    private var patternField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Regex Pattern")
                .font(.subheadline)
                .fontWeight(.medium)

            Text("Enter a valid regular expression pattern.")
                .font(.caption)
                .foregroundColor(.secondary)

            TextField("e.g., PROJ-\\d{4}", text: $pattern)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                .accessibilityIdentifier("patternRegexField")

            // Validation status
            patternValidationStatus
        }
    }

    private var patternValidationStatus: some View {
        HStack(spacing: 4) {
            if pattern.isEmpty {
                EmptyView()
            } else if isPatternValid {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Valid regex")
                    .foregroundColor(.green)
            } else {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                Text("Invalid regex")
                    .foregroundColor(.red)
            }
        }
        .font(.caption)
        .accessibilityIdentifier("patternValidationStatus")
    }

    private var isPatternValid: Bool {
        guard !pattern.isEmpty else { return false }
        do {
            _ = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            return true
        } catch {
            return false
        }
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

            TextField("e.g., PROJECT_ID", text: $maskLabel)
                .textFieldStyle(.roundedBorder)
                .textCase(.uppercase)
                .accessibilityIdentifier("patternMaskLabelField")

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

    // MARK: - Priority Stepper

    private var priorityStepper: some View {
        VStack(alignment: .leading, spacing: 6) {
            Stepper(value: $priority, in: 5...10) {
                HStack {
                    Text("Priority")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Spacer()

                    Text("\(priority)")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
            }
            .accessibilityIdentifier("priorityStepper")

            Text("Higher priority wins when patterns overlap (5=lowest, 10=highest)")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("Example: 'phone' (9) beats 'number' (7) for '555-1234'")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Test Section

    private var testSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Test Your Pattern")
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
                    Text(isTesting ? "Testing..." : "Test Pattern")
                }
            }
            .buttonStyle(.bordered)
            .disabled(isTesting || !canTest)
            .accessibilityIdentifier("testPatternButton")

            // Results
            if let error = testError {
                testErrorView(error)
            } else if !testResults.isEmpty {
                testResultsView
            } else if !isTesting && !testText.isEmpty && canTest {
                Text("Click 'Test Pattern' to see what would be detected.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var canTest: Bool {
        !testText.trimmingCharacters(in: .whitespaces).isEmpty &&
        !pattern.trimmingCharacters(in: .whitespaces).isEmpty &&
        isPatternValid
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
                    RegexTestResultRow(result: result)
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
                let results = try performTest()
                testResults = results
                if results.isEmpty {
                    testError = "No matches found. Try adjusting your pattern."
                }
            } catch {
                testError = error.localizedDescription
            }
            isTesting = false
        }
    }

    private func performTest() throws -> [RegexTestResult] {
        let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        let nsRange = NSRange(testText.startIndex..., in: testText)
        let matches = regex.matches(in: testText, options: [], range: nsRange)

        return matches.compactMap { match -> RegexTestResult? in
            guard let range = Range(match.range, in: testText) else { return nil }
            let matchedText = String(testText[range])
            return RegexTestResult(text: matchedText, range: match.range)
        }
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack {
            Spacer()

            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.escape, modifiers: [])
            .accessibilityIdentifier("cancelPatternButton")

            Button(mode.saveButtonTitle) {
                savePattern()
            }
            .keyboardShortcut(.return, modifiers: .command)
            .buttonStyle(.borderedProminent)
            .disabled(!isFormValid)
            .accessibilityIdentifier("savePatternButton")
        }
        .padding()
    }

    // MARK: - Validation

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !pattern.trimmingCharacters(in: .whitespaces).isEmpty &&
        !maskLabel.trimmingCharacters(in: .whitespaces).isEmpty &&
        isPatternValid
    }

    // MARK: - Save

    private func savePattern() {
        guard isFormValid else {
            validationMessage = "Please fill in all required fields with a valid regex pattern."
            showValidationError = true
            return
        }

        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedDescription = description.trimmingCharacters(in: .whitespaces)
        let trimmedPattern = pattern.trimmingCharacters(in: .whitespaces)
        let trimmedLabel = maskLabel.trimmingCharacters(in: .whitespaces).uppercased()

        // Convert priority (5-10) to confidence (0.5-1.0)
        let confidence = Double(priority) / 10.0

        switch mode {
        case .add:
            let config = RegexPatternConfig(
                name: trimmedName,
                description: trimmedDescription,
                pattern: trimmedPattern,
                sensitiveType: "CUSTOM_\(trimmedLabel)",
                category: .custom,
                confidence: confidence,
                isBuiltIn: false,
                isEnabled: true
            )
            patternsManager.addCustomPattern(config)

        case .edit(let existingPattern):
            let updated = RegexPatternConfig(
                id: existingPattern.id,
                name: trimmedName,
                description: trimmedDescription,
                pattern: trimmedPattern,
                sensitiveType: "CUSTOM_\(trimmedLabel)",
                category: .custom,
                confidence: confidence,
                isBuiltIn: false,
                isEnabled: existingPattern.isEnabled,
                createdAt: existingPattern.createdAt,
                modifiedAt: Date()
            )
            patternsManager.updatePattern(updated)
        }

        dismiss()
    }
}

// MARK: - Test Result Model

struct RegexTestResult: Identifiable {
    let id = UUID()
    let text: String
    let range: NSRange
}

// MARK: - Test Result Row

struct RegexTestResultRow: View {
    let result: RegexTestResult

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.caption)

            Text("\"\(result.text)\"")
                .font(.caption)
                .fontWeight(.medium)

            Text("at position \(result.range.location)")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()
        }
    }
}

// MARK: - Preview

#Preview("Add Mode") {
    CustomRegexEditorView(
        patternsManager: RegexPatternsManager.shared,
        mode: .add
    )
}

#Preview("Edit Mode") {
    let pattern = RegexPatternConfig(
        name: "Project ID",
        description: "Detects internal project identifiers",
        pattern: #"PROJ-\d{4}"#,
        sensitiveType: "CUSTOM_PROJECT_ID",
        category: .custom,
        confidence: 0.9,  // Displays as Priority: 9
        isBuiltIn: false,
        isEnabled: true
    )
    return CustomRegexEditorView(
        patternsManager: RegexPatternsManager.shared,
        mode: .edit(pattern)
    )
}
