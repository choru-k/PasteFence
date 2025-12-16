#!/bin/bash
# distribute.sh - Build and create DMG for distribution

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DIST_DIR="$PROJECT_DIR/dist"

echo "=== PasteFence Distribution Script ==="
echo "Project: $PROJECT_DIR"

# Clean dist directory
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

# Check if app path provided or need to build
APP_PATH="$1"

if [ -z "$APP_PATH" ]; then
    # Try to find built app in common locations
    POSSIBLE_PATHS=(
        "$PROJECT_DIR/PasteFenceWrapper/build/Build/Products/Release/PasteFenceWrapper.app"
        "$PROJECT_DIR/build/Build/Products/Release/PasteFenceWrapper.app"
        "$HOME/Library/Developer/Xcode/DerivedData/PasteFenceWrapper-*/Build/Products/Release/PasteFenceWrapper.app"
    )
    
    for path in "${POSSIBLE_PATHS[@]}"; do
        # Handle glob patterns
        for expanded_path in $path; do
            if [ -d "$expanded_path" ]; then
                APP_PATH="$expanded_path"
                echo "Found app at: $APP_PATH"
                break 2
            fi
        done
    done
fi

if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
    echo "Error: No app found. Please build the app first or provide path:"
    echo "  $0 /path/to/PasteFenceWrapper.app"
    echo ""
    echo "To build in Xcode: Product > Archive or Product > Build For > Running"
    exit 1
fi

# Create DMG
echo ""
echo "=== Step 1: Creating DMG ==="
"$SCRIPT_DIR/create_dmg.sh" "$APP_PATH" "$DIST_DIR"

# Generate checksum
echo ""
echo "=== Step 2: Generating SHA256 checksum ==="
DMG_FILE=$(ls "$DIST_DIR"/*.dmg 2>/dev/null | head -1)

if [ -z "$DMG_FILE" ]; then
    echo "Error: No DMG file found"
    exit 1
fi

shasum -a 256 "$DMG_FILE" > "$DMG_FILE.sha256"
echo "Checksum: $(cat "$DMG_FILE.sha256")"

# Summary
echo ""
echo "=== Distribution Complete ==="
echo "Files created:"
ls -lh "$DIST_DIR"
echo ""
echo "SHA256: $(cat "$DMG_FILE.sha256" | awk '{print $1}')"
echo ""
echo "Note: This is an unsigned app. Users will need to:"
echo "  1. Right-click > Open > Click 'Open' in dialog"
echo "  OR run: xattr -cr /Applications/PasteFence.app"
