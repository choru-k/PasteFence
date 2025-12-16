# Homebrew Cask formula for PasteFence
# Submit to: https://github.com/Homebrew/homebrew-cask
#
# To test locally:
#   brew install --cask ./Casks/pastefence.rb
#
# To submit:
#   1. Fork homebrew-cask
#   2. Add this file to Casks/p/pastefence.rb
#   3. Create PR

cask "pastefence" do
  version "1.0.0"
  sha256 "REPLACE_WITH_ACTUAL_SHA256_FROM_DISTRIBUTE_SCRIPT"

  url "https://github.com/YOUR_USER/pastefence/releases/download/v#{version}/PasteFence-#{version}.dmg"
  name "PasteFence"
  desc "Masks sensitive information in clipboard text using local LLM"
  homepage "https://github.com/YOUR_USER/pastefence"

  # Requires macOS 14.0 (Sonoma) or later
  depends_on macos: ">= :sonoma"

  app "PasteFence.app"

  # Remove quarantine attribute for unsigned app
  # This allows the app to run without Gatekeeper warnings
  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-cr", "#{appdir}/PasteFence.app"],
                   sudo: false
  end

  # Clean up on uninstall
  zap trash: [
    "~/Library/Application Support/PasteFence",
    "~/Library/Preferences/com.pastefence.app.plist",
    "~/Library/Caches/com.pastefence.app"
  ]

  caveats <<~EOS
    PasteFence is not signed with an Apple Developer ID.
    This is an open-source privacy tool that processes data locally.

    On first launch, you may need to:
      1. Right-click the app -> Open -> Click "Open" in the dialog
      OR
      2. Run: xattr -cr /Applications/PasteFence.app

    The app requires Accessibility permissions to use the global hotkey.
    Go to: System Settings -> Privacy & Security -> Accessibility
  EOS
end
