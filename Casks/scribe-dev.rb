cask "scribe-dev" do
  version "1.1.0"
  sha256 "bae1e26f1265abc733cd13ae6d612cdf655f5c2ce1aedc5a4b74418d508a6ce1"

  url "https://github.com/Data-Wise/scribe/releases/download/v#{version}/Scribe_#{version}_aarch64.dmg"

  # Apple Silicon only for now
  arch arm: "aarch64"
  depends_on arch: :arm64

  name "Scribe (Dev)"
  desc "ADHD-friendly distraction-free writer (development channel)"
  homepage "https://github.com/Data-Wise/scribe"

  # Track all releases (stable + pre-releases)
  livecheck do
    url :url
    strategy :github_latest
  end

  # Conflicts with stable version
  conflicts_with cask: "data-wise/tap/scribe"

  # Require macOS 10.15+ (Catalina)
  depends_on macos: ">= :catalina"

  app "Scribe.app"

  postflight do
    ohai "Scribe (Dev) v#{version} installed successfully!"
    ohai ""
    ohai "What's New in v1.1.0:"
    ohai "  • Project System - organize notes by project"
    ohai "  • Note Search - full-text search with FTS5"
    ohai "  • Scribe CLI - terminal access (scribe help)"
    ohai ""
    ohai "Quick Start:"
    ohai "  • Global hotkey: ⌘⇧N (opens Scribe from anywhere)"
    ohai "  • Command palette: ⌘K"
    ohai "  • Focus mode: ⌘⇧F"
    ohai ""
    ohai "Report issues: https://github.com/Data-Wise/scribe/issues"
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
    Scribe v#{version} - ADHD-Friendly Distraction-Free Writer

    New in v1.1.0:
    • Project System - organize notes by project
    • Note Search - full-text search with FTS5
    • Scribe CLI - terminal access (run: scribe help)

    Features:
    • HybridEditor (Markdown + Preview)
    • 10 ADHD-friendly themes
    • 14 recommended fonts
    • Wiki-links and tags
    • Focus mode & global hotkey (⌘⇧N)
    • LaTeX math (KaTeX)
    • Citation autocomplete
    • Export via Pandoc

    CLI Setup (optional):
      source ~/.config/zsh/functions/scribe.zsh

    Report issues: https://github.com/Data-Wise/scribe/issues
  EOS
end
