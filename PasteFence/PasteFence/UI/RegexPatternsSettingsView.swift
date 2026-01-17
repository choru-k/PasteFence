import SwiftUI

/// Settings view for managing regex pattern configuration
struct RegexPatternsSettingsView: View {
    @ObservedObject var patternsManager: RegexPatternsManager

    @State private var showingAddSheet = false
    @State private var editingPattern: RegexPatternConfig?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerSection

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(PatternCategory.allCases) { category in
                        CategorySectionView(
                            category: category,
                            patternsManager: patternsManager,
                            onEditPattern: { pattern in
                                editingPattern = pattern
                            },
                            onAddCustom: {
                                showingAddSheet = true
                            }
                        )
                    }
                }
            }

            addButton

            Divider()

            footerInfo
        }
        .padding()
        .accessibilityIdentifier("regexPatternsSettingsView")
        .sheet(isPresented: $showingAddSheet) {
            CustomRegexEditorView(
                patternsManager: patternsManager,
                mode: .add
            )
        }
        .sheet(item: $editingPattern) { pattern in
            CustomRegexEditorView(
                patternsManager: patternsManager,
                mode: .edit(pattern)
            )
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Regex Patterns")
                .font(.headline)

            Text("Configure which patterns are used for detection.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Add Button

    private var addButton: some View {
        Button(action: { showingAddSheet = true }) {
            Label("Add Custom Pattern", systemImage: "plus.circle.fill")
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier("addCustomPatternButton")
    }

    // MARK: - Footer

    private var footerInfo: some View {
        Text("Built-in patterns cannot be deleted. Toggle patterns off to exclude them from detection.")
            .font(.caption)
            .foregroundColor(.secondary)
    }
}

// MARK: - Category Section View

struct CategorySectionView: View {
    let category: PatternCategory
    @ObservedObject var patternsManager: RegexPatternsManager
    let onEditPattern: (RegexPatternConfig) -> Void
    let onAddCustom: () -> Void

    @State private var isExpanded: Bool = true

    private var categoryPatterns: [RegexPatternConfig] {
        patternsManager.patterns(for: category)
    }

    private var enabledCount: Int {
        patternsManager.enabledCount(for: category)
    }

    private var totalCount: Int {
        patternsManager.totalCount(for: category)
    }

    private var toggleState: ToggleState {
        if patternsManager.isCategoryEnabled(category) {
            return .allEnabled
        } else if patternsManager.isCategoryPartiallyEnabled(category) {
            return .mixed
        } else {
            return .allDisabled
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Category Header
            categoryHeader

            // Pattern List (when expanded)
            if isExpanded && !categoryPatterns.isEmpty {
                patternsList
            }

            // Empty state for custom category
            if isExpanded && category == .custom && categoryPatterns.isEmpty {
                customEmptyState
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .accessibilityIdentifier("categorySection_\(category.rawValue)")
    }

    // MARK: - Category Header

    private var categoryHeader: some View {
        HStack(spacing: 12) {
            // Expand/Collapse Button
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 16)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isExpanded ? "Collapse" : "Expand")

            // Category Icon
            Image(systemName: category.iconName)
                .foregroundColor(.accentColor)
                .frame(width: 20)

            // Category Name
            Text(category.displayName)
                .font(.subheadline)
                .fontWeight(.medium)

            Spacer()

            // Count Badge
            Text("\(enabledCount)/\(totalCount)")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(4)

            // Category Toggle
            categoryToggle

            // Add button for custom category
            if category == .custom {
                Button(action: onAddCustom) {
                    Image(systemName: "plus")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Add custom pattern")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation { isExpanded.toggle() }
        }
    }

    // MARK: - Category Toggle

    private var categoryToggle: some View {
        Button(action: {
            patternsManager.toggleCategory(category)
        }) {
            Image(systemName: toggleState.iconName)
                .foregroundColor(toggleState.iconColor)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Toggle all \(category.displayName) patterns")
        .accessibilityIdentifier("categoryToggle_\(category.rawValue)")
    }

    // MARK: - Patterns List

    private var patternsList: some View {
        VStack(spacing: 0) {
            Divider()
                .padding(.leading, 44)

            ForEach(categoryPatterns) { pattern in
                PatternRowView(
                    pattern: pattern,
                    onToggle: {
                        patternsManager.togglePattern(id: pattern.id)
                    },
                    onEdit: {
                        onEditPattern(pattern)
                    },
                    onDelete: {
                        patternsManager.deletePattern(id: pattern.id)
                    }
                )

                if pattern.id != categoryPatterns.last?.id {
                    Divider()
                        .padding(.leading, 44)
                }
            }
        }
    }

    // MARK: - Custom Empty State

    private var customEmptyState: some View {
        VStack(spacing: 8) {
            Divider()
                .padding(.leading, 44)

            Text("No custom patterns")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.vertical, 12)
        }
    }
}

// MARK: - Toggle State

private enum ToggleState {
    case allEnabled
    case allDisabled
    case mixed

    var iconName: String {
        switch self {
        case .allEnabled: return "checkmark.square.fill"
        case .allDisabled: return "square"
        case .mixed: return "minus.square.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .allEnabled: return .accentColor
        case .allDisabled: return .secondary
        case .mixed: return .accentColor.opacity(0.7)
        }
    }
}

// MARK: - Pattern Row View

struct PatternRowView: View {
    let pattern: RegexPatternConfig
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var showingDeleteConfirmation = false

    var body: some View {
        HStack(spacing: 12) {
            // Spacer for indentation
            Spacer()
                .frame(width: 32)

            // Pattern Info
            VStack(alignment: .leading, spacing: 2) {
                Text(pattern.name)
                    .font(.subheadline)
                    .foregroundColor(pattern.isEnabled ? .primary : .secondary)

                // Show description for all patterns
                if !pattern.description.isEmpty {
                    Text(pattern.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                // Show regex pattern only for custom patterns
                if !pattern.isBuiltIn {
                    Text(pattern.pattern)
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.7))
                        .lineLimit(1)
                }
            }

            Spacer()

            // Type Badge
            Text(pattern.sensitiveType)
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(badgeColor.opacity(0.2))
                .foregroundColor(badgeColor)
                .cornerRadius(4)

            // Priority indicator
            Text("\(max(1, Int(round(pattern.confidence * 10))))")
                .font(.caption2)
                .foregroundColor(.secondary)
                .help("Priority: higher values win when patterns overlap")

            // Enable/Disable Toggle (on right, same style as category toggle)
            Button(action: onToggle) {
                Image(systemName: pattern.isEnabled ? "checkmark.square.fill" : "square")
                    .foregroundColor(pattern.isEnabled ? .accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(pattern.isEnabled ? "Disable pattern" : "Enable pattern")
            .accessibilityIdentifier("patternToggle_\(pattern.id.uuidString)")

            // Action Buttons (only for custom patterns)
            if !pattern.isBuiltIn {
                HStack(spacing: 4) {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Edit pattern")
                    .accessibilityIdentifier("editPatternButton_\(pattern.id.uuidString)")

                    Button(action: { showingDeleteConfirmation = true }) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.red)
                    .accessibilityLabel("Delete pattern")
                    .accessibilityIdentifier("deletePatternButton_\(pattern.id.uuidString)")
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .opacity(pattern.isEnabled ? 1.0 : 0.7)
        .accessibilityIdentifier("patternRow_\(pattern.id.uuidString)")
        .confirmationDialog(
            "Delete Pattern?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete \"\(pattern.name)\"? This cannot be undone.")
        }
    }

    private var badgeColor: Color {
        switch pattern.category {
        case .pii: return .blue
        case .financial: return .green
        case .auth: return .orange
        case .cloudApi: return .purple
        case .infrastructure: return .gray
        case .custom: return .teal
        }
    }
}

// MARK: - Preview

#Preview("With Patterns") {
    RegexPatternsSettingsView(patternsManager: RegexPatternsManager.shared)
        .frame(width: 550, height: 500)
}
