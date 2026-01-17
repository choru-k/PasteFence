import SwiftUI

/// Settings view for managing prompt rules (LLM-based detection)
struct PromptRulesSettingsView: View {
    @ObservedObject var rulesManager: PromptRulesManager

    @State private var showingAddSheet = false
    @State private var editingRule: PromptRule?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerSection

            ScrollView {
                VStack(spacing: 16) {
                    // Built-in rules section
                    builtInSection

                    // Custom rules section
                    customSection
                }
            }

            addButton

            Divider()

            footerInfo
        }
        .padding()
        .accessibilityIdentifier("promptRulesSettingsView")
        .sheet(isPresented: $showingAddSheet) {
            PromptRuleEditorView(
                rulesManager: rulesManager,
                mode: .add
            )
        }
        .sheet(item: $editingRule) { rule in
            PromptRuleEditorView(
                rulesManager: rulesManager,
                mode: .edit(rule)
            )
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Prompt Rules")
                .font(.headline)

            Text("Configure LLM-based detection rules. These rules guide the AI model.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Built-in Section

    private var builtInSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("BUILT-IN")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(rulesManager.builtInRules.filter { $0.isEnabled }.count)/\(rulesManager.builtInRules.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 8) {
                ForEach(rulesManager.builtInRules) { rule in
                    PromptRuleRowView(
                        rule: rule,
                        onToggle: {
                            rulesManager.toggleRule(id: rule.id)
                        },
                        onEdit: nil, // Built-in rules cannot be edited
                        onDelete: nil // Built-in rules cannot be deleted
                    )
                }
            }
        }
    }

    // MARK: - Custom Section

    private var customSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("CUSTOM")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                Spacer()

                if !rulesManager.customRules.isEmpty {
                    Text("\(rulesManager.customRules.filter { $0.isEnabled }.count)/\(rulesManager.customRules.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if rulesManager.customRules.isEmpty {
                emptyCustomState
            } else {
                VStack(spacing: 8) {
                    ForEach(rulesManager.customRules) { rule in
                        PromptRuleRowView(
                            rule: rule,
                            onToggle: {
                                rulesManager.toggleRule(id: rule.id)
                            },
                            onEdit: {
                                editingRule = rule
                            },
                            onDelete: {
                                rulesManager.deleteRule(id: rule.id)
                            }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyCustomState: some View {
        VStack(spacing: 8) {
            Text("No custom rules")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("Add rules for organization-specific sensitive data.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }

    // MARK: - Add Button

    private var addButton: some View {
        Button(action: { showingAddSheet = true }) {
            Label("Add Custom Rule", systemImage: "plus.circle.fill")
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier("addCustomRuleButton")
    }

    // MARK: - Footer

    private var footerInfo: some View {
        Text("Built-in rules cannot be deleted. Toggle rules off to exclude them from detection.")
            .font(.caption)
            .foregroundColor(.secondary)
    }
}

// MARK: - Prompt Rule Row View

struct PromptRuleRowView: View {
    let rule: PromptRule
    let onToggle: () -> Void
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?

    @State private var showingDeleteConfirmation = false
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row
            HStack(alignment: .top, spacing: 12) {
                // Expand button (only for rules with pattern examples)
                if !rule.patternExamples.isEmpty {
                    Button(action: { withAnimation { isExpanded.toggle() } }) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 16)
                    }
                    .buttonStyle(.plain)
                } else {
                    Spacer()
                        .frame(width: 16)
                }

                // Rule Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(rule.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(rule.isEnabled ? .primary : .secondary)

                    Text(rule.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(isExpanded ? nil : 1)
                }

                Spacer()

                // Type badge
                Text(rule.sensitiveType)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(badgeColor.opacity(0.2))
                    .foregroundColor(badgeColor)
                    .cornerRadius(4)

                // Enable/Disable Toggle (same style as regex patterns)
                Button(action: onToggle) {
                    Image(systemName: rule.isEnabled ? "checkmark.square.fill" : "square")
                        .foregroundColor(rule.isEnabled ? .accentColor : .secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(rule.isEnabled ? "Disable rule" : "Enable rule")
                .accessibilityIdentifier("ruleToggle_\(rule.id.uuidString)")

                // Action Buttons (only for custom rules)
                if !rule.isBuiltIn {
                    HStack(spacing: 4) {
                        if let onEdit = onEdit {
                            Button(action: onEdit) {
                                Image(systemName: "pencil")
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Edit rule")
                            .accessibilityIdentifier("editRuleButton_\(rule.id.uuidString)")
                        }

                        if onDelete != nil {
                            Button(action: { showingDeleteConfirmation = true }) {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .foregroundColor(.red)
                            .accessibilityLabel("Delete rule")
                            .accessibilityIdentifier("deleteRuleButton_\(rule.id.uuidString)")
                        }
                    }
                }
            }
            .padding(12)

            // Expanded details
            if isExpanded && !rule.patternExamples.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Divider()
                        .padding(.leading, 28)

                    Text(rule.patternExamples)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 28)
                        .padding(.trailing, 12)
                        .padding(.vertical, 8)
                }
            }

            // Custom rule examples
            if !rule.examples.isEmpty && (isExpanded || !rule.isBuiltIn) {
                HStack(spacing: 4) {
                    ForEach(rule.examples.prefix(3), id: \.self) { example in
                        Text(example)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.1))
                            .cornerRadius(4)
                    }
                    if rule.examples.count > 3 {
                        Text("+\(rule.examples.count - 3)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.leading, 28)
                .padding(.bottom, 8)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .opacity(rule.isEnabled ? 1.0 : 0.7)
        .accessibilityIdentifier("ruleRow_\(rule.id.uuidString)")
        .confirmationDialog(
            "Delete Rule?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                onDelete?()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete \"\(rule.name)\"? This cannot be undone.")
        }
    }

    private var badgeColor: Color {
        rule.isBuiltIn ? .blue : .teal
    }
}

// MARK: - Preview

#Preview("With Rules") {
    let manager = PromptRulesManager()
    #if DEBUG
    manager.addSampleRules()
    #endif
    return PromptRulesSettingsView(rulesManager: manager)
        .frame(width: 550, height: 600)
}

#Preview("Empty Custom") {
    PromptRulesSettingsView(rulesManager: PromptRulesManager())
        .frame(width: 550, height: 600)
}
