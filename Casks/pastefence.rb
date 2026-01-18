# Homebrew Cask formula for PasteFence
#
# Personal Tap Installation:
#   brew tap choru-k/pastefence
#   brew install --cask pastefence
#
# To test locally:
#   brew install --cask ./Casks/pastefence.rb
#
# Future: Submit to https://github.com/Homebrew/homebrew-cask

cask "pastefence" do
  version "1.0.4"
  sha256 "1e1cedcb3920885c34b0649fac550d703593bafba2ce128c8f9b477eb36eb87a"

  url "https://github.com/choru-k/PasteFence/releases/download/v#{version}/PasteFence-#{version}.dmg"
  name "PasteFence"
  desc "Masks sensitive information in clipboard text using local LLM"
  homepage "https://github.com/choru-k/PasteFence"

  depends_on macos: ">= :sonoma"

  app "PasteFence.app"

  zap trash: [
    "~/Library/Application Support/PasteFence",
    "~/Library/Preferences/com.pastefence.app.plist",
    "~/Library/Caches/com.pastefence.app"
  ]

  caveats <<~EOS
    PasteFence requires Accessibility permissions for the global hotkey.
    Go to: System Settings -> Privacy & Security -> Accessibility
  EOS
end
