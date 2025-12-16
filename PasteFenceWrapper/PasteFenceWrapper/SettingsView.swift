//
//  SettingsView.swift
//  PasteFenceWrapper
//
//  UI Testing wrapper for Settings window
//

import SwiftUI

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

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock")
                }

            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 700, height: 450)
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
    @AppStorage("useOllama") private var useOllama = false
    @AppStorage("ollamaModel") private var ollamaModel = "qwen2.5:0.5b"

    @State private var ollamaAvailable = false
    @State private var isCheckingOllama = false

    var body: some View {
        Form {
            Section("Local Model") {
                Text("Models would be listed here")
                    .foregroundColor(.secondary)
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
                            Text("qwen2.5:0.5b").tag("qwen2.5:0.5b")
                            Text("llama3:8b").tag("llama3:8b")
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
    }

    private func checkOllama() {
        isCheckingOllama = true
        // Simulate check
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isCheckingOllama = false
            ollamaAvailable = false // Always false in test wrapper
        }
    }
}

// MARK: - Shortcut Settings

struct ShortcutSettingsView: View {
    var body: some View {
        Form {
            Section("Keyboard Shortcuts") {
                HStack {
                    Text("Mask & Paste:")
                    Spacer()
                    Text("⌘⇧V")
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)
                }
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

// MARK: - History View

struct HistoryView: View {
    @State private var searchText = ""
    @State private var showClearConfirmation = false

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

                // Empty state (test wrapper has no real history)
                VStack(spacing: 16) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)

                    Text("No History Yet")
                        .font(.headline)

                    Text("Masking operations will appear here")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // For testing: hidden list with identifier
                List {
                    Text("Sample entry")
                }
                .listStyle(.plain)
                .accessibilityIdentifier("historyList")
                .frame(height: 1)
                .opacity(0)

                Divider()

                // Footer
                HStack {
                    Text("0 entries")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Button("Export...") {
                        // No-op in test wrapper
                    }
                    .buttonStyle(.borderless)
                    .disabled(true)
                    .accessibilityIdentifier("exportHistoryButton")

                    Button("Clear All") {
                        showClearConfirmation = true
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.red)
                    .disabled(true)
                    .accessibilityIdentifier("clearHistoryButton")
                }
                .padding(8)
                .confirmationDialog(
                    "Clear All History?",
                    isPresented: $showClearConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Clear All", role: .destructive) {}
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This action cannot be undone.")
                }
            }
            .frame(minWidth: 280)

            // Right: Detail pane
            VStack(spacing: 0) {
                // Tab picker (for accessibility identifier)
                Picker("View", selection: .constant(0)) {
                    Text("Original").tag(0)
                    Text("Masked").tag(1)
                    Text("Items (0)").tag(2)
                }
                .pickerStyle(.segmented)
                .padding()
                .accessibilityIdentifier("historyDetailTabs")

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
            .frame(minWidth: 300)
        }
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

            Text("Version 1.0.0 (Test Wrapper)")
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
