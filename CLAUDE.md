# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

PasteFence is a macOS menu bar application that masks sensitive information (PII) in clipboard text using local LLM inference. The core workflow: user copies text normally (Cmd+C), presses Cmd+Shift+V to trigger masking, reviews results in a preview window, then approves to paste masked text.

**Key Design Principle**: All data processing happens locally - no external API calls for privacy.

## Build Commands

```bash
# Resolve dependencies
swift package resolve

# Build (release)
swift build -c release

# Run executable
.build/release/PasteFence

# Run tests
swift test

# Run single test
swift test --filter RegexDetectorTests/testDetectsEmail

# Open in Xcode (recommended for full build with macros)
open Package.swift
```

**Note**: The KeyboardShortcuts library uses Swift macros that require Xcode to build properly. Command-line `swift build` may fail with macro-related errors.

## Makefile Commands

```bash
make test              # Quick swift tests (30 MLX tests skipped)
make test-full         # Full xcodebuild tests (all 630 tests with Metal)
make test-filter FILTER=Name  # Run specific tests
make build             # Build release
make clean             # Clean all artifacts
make xcode             # Open in Xcode
make help              # Show all commands
```

## Architecture

```
AppCoordinator (orchestrator)
    ├── ClipboardService      # NSPasteboard read/write
    ├── HotkeyService         # Global Cmd+Shift+V via KeyboardShortcuts
    └── MaskingEngine (actor) # Combines detection results
            ├── RegexDetector     # Fast pattern matching (~1ms)
            └── LLMDetector       # Contextual detection via MLX (optional)
```

### Core Flow
1. `HotkeyService` triggers on Cmd+Shift+V
2. `AppCoordinator.handleMaskPaste()` reads clipboard via `ClipboardService`
3. `MaskingEngine.mask()` runs regex (always) + LLM (if initialized)
4. `PreviewWindowController` shows diff with approve/cancel
5. On approve: masked text → clipboard → simulated Cmd+V paste

### Key Types

- `DetectedItem`: Represents detected PII with text, type, range, confidence, and source (regex/llm)
- `SensitiveType`: Enum of PII types (email, phone, creditCard, apiKey, jwt, ipAddress, password, privateKey, awsKey, genericSecret)
- `MaskingResult`: Contains original text, masked text, detected items, and processing time

### LLM Integration

Two backends supported:
- **MLX-Swift**: Built-in, optimized for Apple Silicon (default model: Qwen3-0.6B-MLX-8bit)
- **Ollama**: Optional integration for advanced users (localhost:11434)

Model files stored in: `~/Library/Application Support/PasteFence/models/`

## Detection Patterns

RegexDetector handles 12+ patterns including:
- Email, phone numbers (international + Korean)
- Credit cards, JWT tokens, IP addresses
- API keys (OpenAI, GitHub, Slack, AWS)
- Private keys (PEM format), passwords
- Korean resident registration numbers (주민등록번호)

False positive prevention: skips localhost IPs, version numbers that look like IPs, short phone-like sequences.

## Platform Requirements

- macOS 14.0+ (Sonoma)
- Apple Silicon recommended (for MLX performance)
- 8GB RAM minimum

## Test Architecture

### Test Locations

| Location | Type | Run Command |
|----------|------|-------------|
| `Tests/PasteFenceTests/` | Unit tests | `swift test` |
| `PasteFenceWrapper/PasteFenceUITests/` | UI tests | Xcode Cmd+U |

### Unit Tests (`Tests/PasteFenceTests/`)

- `RegexDetectorTests.swift` - Pattern detection
- `MaskingEngineTests.swift` - Engine integration
- `HistoryViewTests.swift` - History functionality

### UI Tests (`PasteFenceWrapper/PasteFenceUITests/`)

- `PasteFenceUITests.swift` - Preview window (11 tests)
- `SettingsUITests.swift` - Settings window (22 tests)

**Note**: UI tests require Xcode (not `swift test`) due to XCUITest framework.

### UI Testing Mode

App launches with `--ui-testing` flag for test mode:
- Auto-shows preview window with sample data
- Enables accessibility identifiers for XCUITest

### Running Tests

```bash
# Unit tests
swift test

# Single test
swift test --filter RegexDetectorTests/testDetectsEmail

# UI tests (Xcode only)
open PasteFenceWrapper/PasteFenceWrapper.xcodeproj
# Then: Product > Test (Cmd+U)
```

### Accessibility Identifiers

Key identifiers for UI testing:

**PreviewWindow**: `previewWindow`, `viewTabs`, `pasteMaskedButton`, `cancelButton`, `selectAllButton`, `deselectAllButton`

**SettingsView**: `launchAtLoginToggle`, `showNotificationsToggle`, `maskingFormatPicker`, `useOllamaToggle`, `refreshOllamaButton`

**HistoryView**: `historySearchField`, `historyList`, `exportHistoryButton`, `clearHistoryButton`
