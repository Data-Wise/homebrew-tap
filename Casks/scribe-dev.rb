cask "scribe-dev" do
  version "1.9.0"
  sha256 "511bce4a7774be13837687cfffd5a60df6472f05835670a5bb1d491c16777043"

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
  depends_on macos: :catalina

  app "Scribe.app"

  postflight do
    ohai "Scribe (Dev) v#{version} installed successfully!"
    ohai ""
    ohai "What's New in v1.9.0:"
    ohai "  • Settings Enhancement - ⌘, fuzzy search, theme gallery"
    ohai "  • Quick Actions Customization - drag-to-reorder, edit prompts, shortcuts"
    ohai "  • Project Templates - Research+, Teaching+, Dev+, Writing+, Minimal"
    ohai "  • 1033 tests passing - comprehensive test coverage"
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

    New in v1.9.0:
    • Settings Enhancement - ⌘, fuzzy search, theme gallery
    • Quick Actions Customization - drag-to-reorder, edit prompts, shortcuts
    • Project Templates - Research+, Teaching+, Dev+, Writing+, Minimal
    • 1033 tests passing - comprehensive test coverage

    Features:
    • HybridEditor (Markdown + Preview)
    • 8 ADHD-friendly themes (visual gallery)
    • 14 recommended fonts
    • Wiki-links and tags
    • Focus mode & global hotkey (⌘⇧N)
    • LaTeX math (KaTeX)
    • Citation autocomplete
    • Export via Pandoc
    • Quick Actions (✨ Improve, 📝 Expand, 📋 Summarize, 💡 Explain, 🔍 Research)

    Keyboard Shortcuts:
    • ⌘⇧N    Open Scribe from anywhere
    • ⌘,     Settings (fuzzy search)
    • ⌘K     Command palette
    • ⌘⇧F    Toggle focus mode
    • ⌘E     Toggle write/preview mode
    • ⌘⌥1-9  Quick Actions (customizable)

    CLI Setup (optional):
      source ~/.config/zsh/functions/scribe.zsh

    Report issues: https://github.com/Data-Wise/scribe/issues
  EOS
end
