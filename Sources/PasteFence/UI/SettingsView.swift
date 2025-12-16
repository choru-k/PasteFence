import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            ModelSettingsView()
                .tabItem {
                    Label("Model", systemImage: "cpu")
                }

            ShortcutSettingsView()
                .tabItem {
                    Label("Shortcuts", systemImage: "command")
                }

            PromptRulesSettingsView(rulesManager: PromptRulesManager.shared)
                .tabItem {
                    Label("Prompt Rules", systemImage: "brain")
                }
                .accessibilityIdentifier("promptRulesTab")

            RegexPatternsSettingsView(patternsManager: RegexPatternsManager.shared)
                .tabItem {
                    Label("Regex Patterns", systemImage: "textformat.abc")
                }
                .accessibilityIdentifier("regexPatternsTab")

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock")
                }

            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 700, height: 500)
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("showNotifications") private var showNotifications = true
    @AppStorage("maskingFormat") private var maskingFormat = "label"

    var body: some View {
        Form {
            Section {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .accessibilityIdentifier("launchAtLoginToggle")
                Toggle("Show Notifications", isOn: $showNotifications)
                    .accessibilityIdentifier("showNotificationsToggle")
            }

            Section("Masking Format") {
                Picker("Format", selection: $maskingFormat) {
                    Text("[TYPE_MASKED]").tag("label")
                    Text("****").tag("asterisk")
                    Text("<REDACTED>").tag("redacted")
                    Text("Partial (john****@...)").tag("partial")
                }
                .pickerStyle(.radioGroup)
                .accessibilityIdentifier("maskingFormatPicker")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Model Settings

struct ModelSettingsView: View {
    @StateObject private var modelManager = ModelManager.shared
    @StateObject private var preloadManager = ModelPreloadManager.shared
    @AppStorage("useOllama") private var useOllama = false
    @AppStorage("ollamaModel") private var ollamaModel = "qwen2.5:0.5b"

    @State private var ollamaAvailable = false
    @State private var ollamaModels: [OllamaModel] = []
    @State private var isCheckingOllama = false

    var body: some View {
        Form {
            Section("Local Model") {
                ForEach(modelManager.availableModels) { model in
                    ModelRow(
                        model: model,
                        isDownloaded: modelManager.isDownloaded(model),
                        isActive: modelManager.activeModel?.id == model.id,
                        isDownloading: modelManager.isDownloading(model),
                        downloadProgress: modelManager.downloadProgress,
                        onDownload: {
                            Task {
                                try? await modelManager.downloadModel(model)
                            }
                        },
                        onSelect: {
                            modelManager.setActiveModel(model)
                        },
                        onDelete: {
                            try? modelManager.deleteModel(model)
                        }
                    )
                }

                // Preload status
                PreloadStatusView()
            }

            Section("Ollama Integration") {
                Toggle("Use Ollama (Advanced)", isOn: $useOllama)
                    .accessibilityIdentifier("useOllamaToggle")

                if useOllama {
                    HStack {
                        Text("Status:")
                        if isCheckingOllama {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: ollamaAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(ollamaAvailable ? .green : .red)
                            Text(ollamaAvailable ? "Connected" : "Not Available")
                        }
                        Spacer()
                        Button("Refresh") {
                            checkOllama()
                        }
                        .accessibilityIdentifier("refreshOllamaButton")
                    }

                    if ollamaAvailable {
                        Picker("Model", selection: $ollamaModel) {
                            ForEach(ollamaModels) { model in
                                Text(model.name).tag(model.name)
                            }
                        }
                        .accessibilityIdentifier("ollamaModelPicker")
                    } else {
                        Text("Install Ollama from ollama.ai and run 'ollama serve'")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            if useOllama {
                checkOllama()
            }
        }
    }

    private func checkOllama() {
        isCheckingOllama = true
        Task {
            let client = OllamaClient()
            let available = await client.isAvailable()

            await MainActor.run {
                ollamaAvailable = available
                isCheckingOllama = false
            }

            if available {
                do {
                    let models = try await client.listModels()
                    await MainActor.run {
                        ollamaModels = models
                    }
                } catch {
                    print("Failed to list Ollama models: \(error)")
                }
            }
        }
    }
}

struct ModelRow: View {
    let model: ModelInfo
    let isDownloaded: Bool
    let isActive: Bool
    let isDownloading: Bool
    let downloadProgress: Double
    let onDownload: () -> Void
    let onSelect: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                HStack {
                    Text(model.name)
                        .fontWeight(isActive ? .semibold : .regular)

                    if model.isDefault {
                        Text("Recommended")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }
                }

                Text(model.description)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(model.size)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isDownloaded {
                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Button("Use") {
                        onSelect()
                    }
                    .buttonStyle(.bordered)
                }

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)

            } else if isDownloading {
                ProgressView(value: downloadProgress)
                    .frame(width: 80)
            } else {
                Button("Download") {
                    onDownload()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preload Status View

struct PreloadStatusView: View {
    @StateObject private var preloadManager = ModelPreloadManager.shared

    var body: some View {
        HStack(spacing: 8) {
            // Status icon
            Group {
                switch preloadManager.state {
                case .idle:
                    Image(systemName: "circle")
                        .foregroundColor(.gray)
                case .waiting, .preloading:
                    ProgressView()
                        .scaleEffect(0.7)
                case .ready:
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                case .failed:
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.red)
                }
            }
            .frame(width: 16)

            // Status text
            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle)
                    .font(.subheadline)

                if case .preloading = preloadManager.state {
                    Text("\(Int(preloadManager.progress * 100))% loaded")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if case .failed(let error) = preloadManager.state {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Retry button for failed state
            if case .failed = preloadManager.state {
                Button("Retry") {
                    preloadManager.startPreloading(delay: 0)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("preloadStatusView")
    }

    private var statusTitle: String {
        switch preloadManager.state {
        case .idle:
            return "Model not loaded"
        case .waiting:
            return "Preparing to load model..."
        case .preloading:
            return "Loading model..."
        case .ready:
            return "Model ready for instant masking"
        case .failed:
            return "Model load failed"
        }
    }
}

// MARK: - Shortcut Settings

struct ShortcutSettingsView: View {
    var body: some View {
        Form {
            Section("Keyboard Shortcuts") {
                KeyboardShortcuts.Recorder("Mask & Paste:", name: .maskPaste)
                    .accessibilityIdentifier("hotkeyRecorder")
            }

            Section {
                Text("Default: ⌘⇧V (Command + Shift + V)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - About View

struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)

            Text("PasteFence")
                .font(.title)
                .fontWeight(.bold)

            Text("Version 1.0.0")
                .foregroundColor(.secondary)

            Text("Protect sensitive information when copying logs and error messages.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            Spacer()

            VStack(spacing: 8) {
                Link("GitHub Repository", destination: URL(string: "https://github.com")!)
                Link("Report Issue", destination: URL(string: "https://github.com")!)
            }
            .font(.caption)

            Text("Made with MLX-Swift")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
}
