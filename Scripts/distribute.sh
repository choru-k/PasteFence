#!/bin/bash
# distribute.sh - Build, sign, notarize, and create DMG for distribution

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DIST_DIR="$PROJECT_DIR/dist"

# Code signing configuration
DEVELOPER_ID="Developer ID Application: Cheol Kang (ESURPGU29C)"
KEYCHAIN_PROFILE="PasteFenceNotarization"
ENTITLEMENTS="$PROJECT_DIR/PasteFence/PasteFence/PasteFence.entitlements"

echo "=== PasteFence Distribution Script ==="
echo "Project: $PROJECT_DIR"

# Check if app path and version provided
APP_PATH="$1"
VERSION="$2"

if [ -z "$VERSION" ]; then
    echo "Error: VERSION is required"
    echo "Usage: $0 /path/to/app VERSION"
    exit 1
fi

echo "Version: $VERSION"

# Clean dist directory
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

if [ -z "$APP_PATH" ]; then
    # Try to find built app in common locations
    POSSIBLE_PATHS=(
        "$PROJECT_DIR/PasteFence/build/Build/Products/Release/PasteFence.app"
        "$PROJECT_DIR/build/Build/Products/Release/PasteFence.app"
        "$HOME/Library/Developer/Xcode/DerivedData/PasteFence-*/Build/Products/Release/PasteFence.app"
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
    echo "  $0 /path/to/PasteFence.app"
    echo ""
    echo "To build in Xcode: Product > Archive or Product > Build For > Running"
    exit 1
fi

# Sign app bundle before creating DMG
echo ""
echo "=== Step 1: Signing App Bundle ==="
echo "Signing with: $DEVELOPER_ID"

# Sign all nested frameworks and binaries first
find "$APP_PATH" -type f \( -name "*.dylib" -o -name "*.framework" \) -exec \
    codesign --force --options runtime --sign "$DEVELOPER_ID" {} \; 2>/dev/null || true

# Sign the main app bundle
codesign --force --deep --options runtime \
    --sign "$DEVELOPER_ID" \
    --entitlements "$ENTITLEMENTS" \
    "$APP_PATH"

echo "App signed successfully"
codesign --verify --verbose "$APP_PATH"

# Create DMG
echo ""
echo "=== Step 2: Creating DMG ==="
"$SCRIPT_DIR/create_dmg.sh" "$APP_PATH" "$DIST_DIR" "$VERSION"

# Get DMG file
DMG_FILE=$(ls "$DIST_DIR"/*.dmg 2>/dev/null | head -1)

if [ -z "$DMG_FILE" ]; then
    echo "Error: No DMG file found"
    exit 1
fi

# Sign DMG
echo ""
echo "=== Step 3: Signing DMG ==="
codesign --force --sign "$DEVELOPER_ID" "$DMG_FILE"
echo "DMG signed successfully"

# Notarize
echo ""
echo "=== Step 4: Submitting for Notarization ==="
echo "This may take a few minutes..."
xcrun notarytool submit "$DMG_FILE" \
    --keychain-profile "$KEYCHAIN_PROFILE" \
    --wait

# Staple notarization ticket
echo ""
echo "=== Step 5: Stapling Notarization Ticket ==="
xcrun stapler staple "$DMG_FILE"

# Verify
echo ""
echo "=== Step 6: Verifying Signature ==="
xcrun stapler validate "$DMG_FILE"
spctl --assess --type open --context context:primary-signature --verbose "$DMG_FILE"
echo "✅ DMG is signed and notarized"

# Generate checksum
echo ""
echo "=== Step 7: Generating SHA256 checksum ==="
shasum -a 256 "$DMG_FILE" > "$DMG_FILE.sha256"
echo "Checksum: $(cat "$DMG_FILE.sha256")"

# Upload to GitHub Release
echo ""
echo "=== Step 8: Creating Tag and Uploading to GitHub Release ==="

TAG="v$VERSION"
echo "Tag: $TAG"

# Check if gh CLI is available
if ! command -v gh &> /dev/null; then
    echo "Error: GitHub CLI (gh) not installed."
    echo "Install with: brew install gh"
    exit 1
fi

# Check if authenticated
if ! gh auth status &> /dev/null; then
    echo "Error: Not authenticated with GitHub CLI."
    echo "Run: gh auth login"
    exit 1
fi

# Create and push tag if it doesn't exist
if git rev-parse "$TAG" >/dev/null 2>&1; then
    echo "Tag $TAG already exists locally."
else
    echo "Creating tag $TAG..."
    git tag "$TAG"
fi

# Push tag to remote
echo "Pushing tag $TAG to origin..."
git push origin "$TAG" 2>/dev/null || echo "Tag already exists on remote."

# Generate release notes from git commits
echo "Generating release notes..."
PREV_TAG=$(git describe --tags --abbrev=0 HEAD^ 2>/dev/null || echo "")
if [ -n "$PREV_TAG" ]; then
    CHANGES=$(git log --pretty=format:"- %s" "$PREV_TAG"..HEAD --no-merges | head -20)
else
    CHANGES=$(git log --pretty=format:"- %s" -10 --no-merges)
fi

SHA256_VALUE=$(cat "$DMG_FILE.sha256" | awk '{print $1}')

RELEASE_NOTES="## What's New

$CHANGES

## Checksum

\`$SHA256_VALUE\`"

# Create or update release
echo "Uploading to GitHub release $TAG..."

# Check if release exists
if gh release view "$TAG" &> /dev/null; then
    echo "Release $TAG exists. Uploading assets..."
    gh release upload "$TAG" "$DMG_FILE" "$DMG_FILE.sha256" --clobber
else
    echo "Creating new release $TAG..."
    gh release create "$TAG" \
        --title "PasteFence $TAG" \
        --notes "$RELEASE_NOTES" \
        "$DMG_FILE" "$DMG_FILE.sha256"
fi

echo "✅ Uploaded to: https://github.com/choru-k/PasteFence/releases/tag/$TAG"

# Update Homebrew Tap
echo ""
echo "=== Step 9: Updating Homebrew Tap ==="

# Look for homebrew-pastefence in common locations
HOMEBREW_TAP_DIRS=(
    "$HOME/Code/homebrew-pastefence"
    "$HOME/Projects/homebrew-pastefence"
    "$HOME/Developer/homebrew-pastefence"
    "$(dirname "$PROJECT_DIR")/homebrew-pastefence"
)

HOMEBREW_TAP_DIR=""
for dir in "${HOMEBREW_TAP_DIRS[@]}"; do
    if [ -d "$dir" ] && [ -f "$dir/Casks/pastefence.rb" ]; then
        HOMEBREW_TAP_DIR="$dir"
        break
    fi
done

if [ -n "$HOMEBREW_TAP_DIR" ]; then
    echo "Found tap at: $HOMEBREW_TAP_DIR"
    cd "$HOMEBREW_TAP_DIR"

    # Update cask with new version and SHA256
    sed -i '' "s/version \".*\"/version \"$VERSION\"/" Casks/pastefence.rb
    sed -i '' "s/sha256 \".*\"/sha256 \"$SHA256_VALUE\"/" Casks/pastefence.rb

    # Commit and push
    git add Casks/pastefence.rb
    git commit -m "Update to v$VERSION" || echo "No changes to commit"
    git push origin main || git push origin master

    echo "✅ Homebrew tap updated"
    cd "$PROJECT_DIR"
else
    echo "⚠️  Homebrew tap not found. Update manually:"
    echo "   1. Clone/create: https://github.com/choru-k/homebrew-pastefence"
    echo "   2. Update Casks/pastefence.rb with:"
    echo "      version \"$VERSION\""
    echo "      sha256 \"$SHA256_VALUE\""
fi

# Summary
echo ""
echo "=== Distribution Complete ==="
echo "Files created:"
ls -lh "$DIST_DIR"
echo ""
echo "SHA256: $(cat "$DMG_FILE.sha256" | awk '{print $1}')"
echo ""
echo "✅ App is signed and notarized - users can install without Gatekeeper warnings"
