cask "scribe" do
  version "0.4.0-alpha.1"
  
  # Architecture-specific downloads
  on_intel do
    sha256 "PLACEHOLDER_X64_SHA256"
    url "https://github.com/Data-Wise/scribe/releases/download/v#{version}/Scribe_#{version}_x64.dmg"
  end
  on_arm do
    sha256 "27c96d532d13612a846872edf1ffd04f19bb7987f6002dae15b2ef74120ac589"
    url "https://github.com/Data-Wise/scribe/releases/download/v#{version}/Scribe_#{version}_aarch64.dmg"
  end

  name "Scribe"
  desc "ADHD-friendly distraction-free writer for academics and researchers"
  homepage "https://github.com/Data-Wise/scribe"

  # Pre-release/beta channel
  livecheck do
    url :url
    regex(/^v?(\d+(?:\.\d+)*(?:-(?:alpha|beta|rc)\.\d+)?)$/i)
  end

  # Require macOS 10.15+ (Catalina)
  depends_on macos: ">= :catalina"

  app "Scribe.app"

  # Register global hotkey after install
  postflight do
    ohai "Scribe installed successfully!"
    ohai ""
    ohai "Quick Start:"
    ohai "  • Global hotkey: ⌘⇧N (opens Scribe from anywhere)"
    ohai "  • Command palette: ⌘K"
    ohai "  • Focus mode: ⌘⇧F"
    ohai ""
    ohai "⚠️  This is an ALPHA release. Please report issues at:"
    ohai "  https://github.com/Data-Wise/scribe/issues"
  end

  uninstall quit: "com.scribe.app"

  zap trash: [
    "~/Library/Application Support/com.scribe.app",
    "~/Library/Caches/com.scribe.app",
    "~/Library/Logs/com.scribe.app",
    "~/Library/Preferences/com.scribe.app.plist",
    "~/Library/Saved Application State/com.scribe.app.savedState",
  ]

  caveats <<~EOS
    ⚠️  ALPHA RELEASE (v#{version})
    
    This is a pre-release version intended for testing.
    Some features may be incomplete or unstable.
    
    Features:
    • HybridEditor (Markdown + Preview)
    • 10 ADHD-friendly themes
    • 14 recommended fonts with Homebrew install
    • Wiki-links and tags
    • Focus mode
    • Global hotkey (⌘⇧N)
    
    Keyboard Shortcuts:
    • ⌘⇧N  Open Scribe from anywhere
    • ⌘K   Command palette
    • ⌘⇧F  Toggle focus mode
    • ⌘E   Toggle write/preview mode
    
    Report issues: https://github.com/Data-Wise/scribe/issues
  EOS
end
