import SwiftUI
import AppKit

// MARK: - HistoryView (Main Container)

struct HistoryView: View {
    @ObservedObject private var historyManager = HistoryManager.shared
    @State private var selectedEntry: MaskingHistoryEntry?
    @State private var searchText = ""

    var filteredEntries: [MaskingHistoryEntry] {
        if searchText.isEmpty {
            return historyManager.history.entries
        }
        return historyManager.search(query: searchText)
    }

    var body: some View {
        HSplitView {
            // Left: List pane
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search history...", text: $searchText)
                        .textFieldStyle(.plain)
                        .accessibilityIdentifier("historySearchField")
                }
                .padding(8)
                .background(Color(NSColor.controlBackgroundColor))

                Divider()

                // List or empty state
                if filteredEntries.isEmpty {
                    EmptyHistoryView(hasSearchQuery: !searchText.isEmpty)
                } else {
                    List(selection: $selectedEntry) {
                        ForEach(filteredEntries) { entry in
                            HistoryRowView(entry: entry)
                                .tag(entry)
                                .contextMenu {
                                    Button("Copy Original") {
                                        copyToClipboard(entry.originalText)
                                    }
                                    Button("Copy Masked") {
                                        copyToClipboard(entry.maskedText)
                                    }
                                    Divider()
                                    Button("Delete", role: .destructive) {
                                        historyManager.removeEntry(entry)
                                        if selectedEntry == entry {
                                            selectedEntry = nil
                                        }
                                    }
                                }
                        }
                    }
                    .listStyle(.plain)
                    .accessibilityIdentifier("historyList")
                }

                Divider()

                // Footer
                HistoryFooterView(historyManager: historyManager)
            }
            .frame(minWidth: 280)

            // Right: Detail pane
            if let entry = selectedEntry {
                HistoryDetailView(entry: entry)
                    .frame(minWidth: 300)
            } else {
                NoSelectionView()
                    .frame(minWidth: 300)
            }
        }
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

// MARK: - HistoryRowView

struct HistoryRowView: View {
    let entry: MaskingHistoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                TypePillsView(items: entry.detectedItems)
            }

            Text(entry.originalPreview)
                .font(.system(.body, design: .monospaced))
                .lineLimit(2)
                .truncationMode(.tail)

            HStack(spacing: 12) {
                Label("\(entry.detectedCount) detected", systemImage: "eye")
                Label("\(entry.appliedCount) masked", systemImage: "eye.slash")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - TypePillsView

struct TypePillsView: View {
    let items: [HistoryDetectedItem]

    var uniqueTypes: [String] {
        Array(Set(items.map(\.type))).sorted()
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(uniqueTypes.prefix(3), id: \.self) { type in
                Text(type)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(colorForType(type).opacity(0.2))
                    .foregroundColor(colorForType(type))
                    .cornerRadius(4)
            }

            if uniqueTypes.count > 3 {
                Text("+\(uniqueTypes.count - 3)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func colorForType(_ type: String) -> Color {
        switch type.uppercased() {
        case "EMAIL": return .blue
        case "PHONE": return .green
        case "CREDIT_CARD": return .orange
        case "API_KEY", "AWS_KEY": return .red
        case "JWT", "PRIVATE_KEY": return .purple
        case "PASSWORD", "GENERIC_SECRET": return .pink
        case "IP_ADDRESS": return .cyan
        default: return .gray
        }
    }
}

// MARK: - EmptyHistoryView

struct EmptyHistoryView: View {
    var hasSearchQuery: Bool = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: hasSearchQuery ? "magnifyingglass" : "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text(hasSearchQuery ? "No Results" : "No History Yet")
                .font(.headline)

            Text(hasSearchQuery ? "Try a different search term" : "Masking operations will appear here")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - NoSelectionView

struct NoSelectionView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("Select an Entry")
                .font(.headline)

            Text("Click on an entry to view details")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - HistoryDetailView

struct HistoryDetailView: View {
    let entry: MaskingHistoryEntry
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Header with timestamp
            HStack {
                Text(entry.timestamp, style: .date)
                Text("at")
                    .foregroundColor(.secondary)
                Text(entry.timestamp, style: .time)
                Spacer()
                SourceBadge(source: entry.source)
            }
            .font(.caption)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Tab picker
            Picker("View", selection: $selectedTab) {
                Text("Original").tag(0)
                Text("Masked").tag(1)
                Text("Items (\(entry.detectedCount))").tag(2)
            }
            .pickerStyle(.segmented)
            .padding()
            .accessibilityIdentifier("historyDetailTabs")

            // Tab content
            switch selectedTab {
            case 0:
                TextPreviewView(text: entry.originalText)
            case 1:
                TextPreviewView(text: entry.maskedText)
            case 2:
                ItemsListView(detected: entry.detectedItems, applied: entry.appliedItems)
            default:
                EmptyView()
            }
        }
    }
}

// MARK: - SourceBadge

struct SourceBadge: View {
    let source: MaskingHistoryEntry.MaskingSource

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: sourceIcon)
            Text(sourceLabel)
        }
        .font(.caption2)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(sourceColor.opacity(0.2))
        .foregroundColor(sourceColor)
        .cornerRadius(4)
    }

    private var sourceIcon: String {
        switch source {
        case .regexOnly: return "text.magnifyingglass"
        case .hybrid: return "cpu"
        case .ollamaOnly: return "brain"
        }
    }

    private var sourceLabel: String {
        switch source {
        case .regexOnly: return "Regex"
        case .hybrid: return "Hybrid"
        case .ollamaOnly: return "Ollama"
        }
    }

    private var sourceColor: Color {
        switch source {
        case .regexOnly: return .blue
        case .hybrid: return .purple
        case .ollamaOnly: return .orange
        }
    }
}

// MARK: - TextPreviewView

struct TextPreviewView: View {
    let text: String

    var body: some View {
        ScrollView {
            Text(text)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .background(Color(NSColor.textBackgroundColor))
    }
}

// MARK: - ItemsListView

struct ItemsListView: View {
    let detected: [HistoryDetectedItem]
    let applied: [HistoryDetectedItem]

    private var appliedIds: Set<UUID> {
        Set(applied.map(\.id))
    }

    var body: some View {
        List {
            ForEach(detected) { item in
                HistoryItemRow(item: item, wasApplied: appliedIds.contains(item.id))
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - HistoryItemRow

struct HistoryItemRow: View {
    let item: HistoryDetectedItem
    let wasApplied: Bool

    var body: some View {
        HStack {
            // Applied status
            Image(systemName: wasApplied ? "checkmark.circle.fill" : "circle")
                .foregroundColor(wasApplied ? .green : .secondary)

            // Text content
            Text(item.text)
                .font(.system(.body, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
                .strikethrough(!wasApplied)
                .foregroundColor(wasApplied ? .primary : .secondary)

            Spacer()

            // Type badge
            Text(item.type)
                .font(.caption2)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(typeColor.opacity(0.2))
                .foregroundColor(typeColor)
                .cornerRadius(3)

            // Priority
            Text("P:\(max(1, Int(round(item.confidence * 10))))")
                .font(.caption2)
                .foregroundColor(.secondary)

            // LLM indicator
            if item.source == "llm" {
                Image(systemName: "brain")
                    .font(.caption2)
                    .foregroundColor(.purple)
            }
        }
        .padding(.vertical, 2)
    }

    private var typeColor: Color {
        switch item.type.uppercased() {
        case "EMAIL": return .blue
        case "PHONE": return .green
        case "CREDIT_CARD": return .orange
        case "API_KEY", "AWS_KEY": return .red
        case "JWT", "PRIVATE_KEY": return .purple
        case "PASSWORD", "GENERIC_SECRET": return .pink
        case "IP_ADDRESS": return .cyan
        default: return .gray
        }
    }
}

// MARK: - HistoryFooterView

struct HistoryFooterView: View {
    @ObservedObject var historyManager: HistoryManager
    @State private var showClearConfirmation = false
    @State private var showExportError = false
    @State private var exportErrorMessage = ""

    var body: some View {
        HStack {
            Text("\(historyManager.history.entries.count) entries")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            Button("Export...") {
                exportHistory()
            }
            .buttonStyle(.borderless)
            .disabled(historyManager.history.entries.isEmpty)
            .accessibilityIdentifier("exportHistoryButton")

            Button("Clear All") {
                showClearConfirmation = true
            }
            .buttonStyle(.borderless)
            .foregroundColor(.red)
            .disabled(historyManager.history.entries.isEmpty)
            .accessibilityIdentifier("clearHistoryButton")
        }
        .padding(8)
        .confirmationDialog(
            "Clear All History?",
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear All", role: .destructive) {
                historyManager.clearHistory()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
        .alert("Export Failed", isPresented: $showExportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportErrorMessage)
        }
    }

    private func exportHistory() {
        do {
            let url = try historyManager.exportHistory()
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            exportErrorMessage = error.localizedDescription
            showExportError = true
        }
    }
}

// MARK: - Preview

#Preview {
    HistoryView()
        .frame(width: 700, height: 450)
}
