cask "scribe" do
  version "1.12.0"

  # Architecture-specific SHA256 hashes
  on_arm do
    sha256 "bcf2f71c33f3f8b8144dcd1b773a7b7452225768d36ce05b96bf2d6caf5e6d45"
    url "https://github.com/Data-Wise/scribe/releases/download/v#{version}/Scribe_#{version}_aarch64.dmg"
  end

  on_intel do
    sha256 "ce81112ab2e2f27e25fb9a3cfe1d65c3c2755dc0ae1aac86e143aca6f316565a"
    url "https://github.com/Data-Wise/scribe/releases/download/v#{version}/Scribe_#{version}_x64.dmg"
  end

  name "Scribe"
  desc "ADHD-friendly distraction-free writer with LaTeX, citations, and Pandoc export"
  homepage "https://github.com/Data-Wise/scribe"

  # Stable releases only (no alpha/beta/rc)
  livecheck do
    url "https://github.com/Data-Wise/scribe/releases"
    regex(/^v?(\d+(?:\.\d+)+)$/i)
    strategy :github_releases do |json, regex|
      json.filter_map do |release|
        match = release["tag_name"]&.match(regex)
        next unless match
        next if release["draft"] || release["prerelease"]

        match[1]
      end
    end
  end

  # Conflicts with dev version
  conflicts_with cask: "data-wise/tap/scribe-dev"

  # Require macOS 10.15+ (Catalina)
  depends_on macos: ">= :catalina"

  app "Scribe.app"

  postflight do
    ohai "Scribe v#{version} installed successfully!"
    ohai ""
    ohai "What's New in v1.12.0:"
    ohai "  • Browser Mode Fix - Wiki links and tags now indexed correctly"
    ohai "  • Backlinks panel fully functional in browser mode"
    ohai "  • Tag filtering working in browser mode"
    ohai "  • 930 unit tests passing (21 new component tests)"
    ohai "  • Intel Mac support added (both Apple Silicon and Intel)"
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

    New in v1.12.0:
    • Browser Mode Fix - Wiki links and tags now indexed correctly
    • Backlinks panel fully functional
    • Tag filtering working
    • 930 unit tests passing (21 new component tests)
    • Universal Binary - Now supports both Apple Silicon and Intel Macs

    Previous Release (v1.11.0):
    • Callout Support - 11 Obsidian-style callout types
    • Type-specific colors (note, tip, warning, danger, info, success, etc.)
    • Multi-line callouts with custom titles

    Features:
    • Three Editor Modes - Source (⌘1), Live Preview (⌘2), Reading (⌘3)
    • Callouts - 11 types with color coding (> [!note], > [!tip], > [!warning], etc.)
    • LaTeX Math - KaTeX rendering ($...$ inline, $$...$$ display)
    • 8 ADHD-friendly themes (visual gallery)
    • 14 recommended fonts
    • Wiki-links and tags with backlinks
    • Focus mode & global hotkey (⌘⇧N)
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

    Optional Dependencies:
    • Pandoc: brew install pandoc
    • LaTeX: brew install --cask mactex (for PDF export)

    Report issues: https://github.com/Data-Wise/scribe/issues
  EOS
end
