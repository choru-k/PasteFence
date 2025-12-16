# PasteFence

A macOS menu bar app that automatically masks sensitive information (PII) in clipboard text using local LLM inference. All processing happens on-device - your data never leaves your machine.

## Features

- **Local LLM Processing**: All masking happens locally using MLX-Swift - no external API calls
- **Hybrid Detection**: Combines fast regex patterns (~1ms) with context-aware LLM analysis
- **Preview & Approval**: Review masked results before pasting with a visual diff
- **Customizable**: Configure hotkeys, masking formats, and model settings

## Installation

### Option 1: Homebrew (Recommended)

```bash
brew install --cask pastefence
```

### Option 2: Download DMG

1. Download the latest `.dmg` from [GitHub Releases](https://github.com/choru-k/PasteFence/releases)
2. Open the DMG and drag to Applications
3. **First launch**: Right-click the app → "Open" → Click "Open" in the dialog

   Or run in Terminal:
   ```bash
   xattr -cr /Applications/PasteFence.app
   ```

> **Note**: This app is not signed with an Apple Developer ID. As an open-source project, you can verify the source code. All data processing happens locally.

## Supported Sensitive Information

| Category | Types |
|----------|-------|
| Personal | Email addresses, phone numbers (international + Korean), Korean resident registration numbers |
| Financial | Credit card numbers |
| Technical | API keys (OpenAI, GitHub, AWS, Slack), JWT tokens, IP addresses, passwords, private keys (PEM) |

## Usage

1. **Copy text** normally with `Cmd+C`
2. **Trigger masking** with `Cmd+Shift+V`
3. **Review** the masked result in the preview window
4. **Approve** with "Paste Masked" button or `Cmd+Enter`

The masked text is automatically pasted to your active application.

## Requirements

- macOS 14.0+ (Sonoma)
- Apple Silicon (M1/M2/M3) recommended for optimal LLM performance
- 8GB RAM minimum

## Build

```bash
# Resolve dependencies
swift package resolve

# Build release
swift build -c release

# Run
.build/release/PasteFence
```

> **Note**: The KeyboardShortcuts library uses Swift macros that require Xcode for proper compilation. Open `Package.swift` in Xcode for full build support.

## Configuration

### Local Model (Default)

On first launch, go to **Settings → Model** to download the default model (Qwen3-0.6B-MLX-8bit, ~400MB).

Models are stored in: `~/Library/Application Support/PasteFence/models/`

### Ollama Integration (Optional)

For advanced users who prefer Ollama:

1. Install [Ollama](https://ollama.ai)
2. Run `ollama serve`
3. Enable "Use Ollama" in **Settings → Model**

## Tech Stack

- **Language**: Swift 5.9+
- **UI**: SwiftUI + AppKit
- **LLM Runtime**: MLX-Swift (Apple Silicon optimized)
- **Default Model**: Qwen3-0.6B-MLX-8bit

## Architecture

```
AppCoordinator (orchestrator)
    ├── ClipboardService      # NSPasteboard read/write
    ├── HotkeyService         # Global Cmd+Shift+V via KeyboardShortcuts
    └── MaskingEngine         # Combines detection results
            ├── RegexDetector     # Fast pattern matching
            └── LLMDetector       # Contextual detection via MLX
```

## License

MIT License
