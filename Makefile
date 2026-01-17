# PasteFence Makefile
# Simplifies testing and build commands

.PHONY: test test-full test-filter build clean resolve xcode help release

# Default target
.DEFAULT_GOAL := help

# =============================================================================
# Testing
# =============================================================================

## Run tests via swift test (quick, 30 MLX tests skipped)
test:
	@echo "Running swift test (MLX tests will be skipped)..."
	swift test

## Run all tests via xcodebuild (full suite, includes MLX/Metal tests)
test-full:
	@echo "Running xcodebuild test (full suite with Metal support)..."
	xcodebuild test -scheme PasteFence -destination 'platform=macOS'

## Run specific test filter: make test-filter FILTER=TestName
test-filter:
ifndef FILTER
	@echo "Usage: make test-filter FILTER=TestName"
	@echo "Example: make test-filter FILTER=RegexDetectorTests"
	@exit 1
endif
	@echo "Running tests matching: $(FILTER)"
	swift test --filter $(FILTER)

## Run xcodebuild test with specific filter
test-full-filter:
ifndef FILTER
	@echo "Usage: make test-full-filter FILTER=TestName"
	@exit 1
endif
	@echo "Running xcodebuild tests matching: $(FILTER)"
	xcodebuild test -scheme PasteFence -destination 'platform=macOS' -only-testing:PasteFenceTests/$(FILTER)

# =============================================================================
# Build
# =============================================================================

## Build release binary
build:
	@echo "Building release..."
	swift build -c release

## Build debug binary
build-debug:
	@echo "Building debug..."
	swift build

## Run the built application
run: build
	@echo "Running PasteFence..."
	.build/release/PasteFence

## Build release app, create DMG, and upload to GitHub Release
## Usage: make release VERSION=1.0.1
release:
ifndef VERSION
	@echo "Error: VERSION is required"
	@echo "Usage: make release VERSION=1.0.1"
	@exit 1
endif
	@echo "Building release v$(VERSION)..."
	xcodebuild \
		-project PasteFence/PasteFence.xcodeproj \
		-scheme PasteFence \
		-configuration Release \
		-derivedDataPath build \
		-destination 'platform=macOS'
	@echo "Creating DMG and uploading to GitHub..."
	chmod +x Scripts/distribute.sh Scripts/create_dmg.sh
	Scripts/distribute.sh build/Build/Products/Release/PasteFence.app $(VERSION)
	@echo ""
	@echo "Release artifacts created in dist/"
	@ls -la dist/

# =============================================================================
# Utilities
# =============================================================================

## Resolve package dependencies
resolve:
	@echo "Resolving dependencies..."
	swift package resolve

## Clean build artifacts
clean:
	@echo "Cleaning..."
	swift package clean
	rm -rf .build
	rm -rf ~/Library/Developer/Xcode/DerivedData/pastefence-*

## Open in Xcode
xcode:
	@echo "Opening in Xcode..."
	open PasteFence/PasteFence.xcodeproj

## Show help
help:
	@echo "PasteFence Makefile"
	@echo ""
	@echo "Testing:"
	@echo "  make test              - Run swift tests (quick, MLX skipped)"
	@echo "  make test-full         - Run xcodebuild tests (full, with Metal)"
	@echo "  make test-filter       - Run filtered tests: make test-filter FILTER=Name"
	@echo "  make test-full-filter  - Run xcodebuild filtered: make test-full-filter FILTER=Name"
	@echo ""
	@echo "Building:"
	@echo "  make build             - Build release binary"
	@echo "  make build-debug       - Build debug binary"
	@echo "  make run               - Build and run"
	@echo "  make release VERSION=x.y.z - Build, create DMG, tag and upload to GitHub"
	@echo ""
	@echo "Utilities:"
	@echo "  make resolve           - Resolve dependencies"
	@echo "  make clean             - Clean all build artifacts"
	@echo "  make xcode             - Open in Xcode"
	@echo "  make help              - Show this help"
