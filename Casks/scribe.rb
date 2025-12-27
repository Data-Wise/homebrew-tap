cask "scribe" do
  version "0.4.0-alpha.1"
  sha256 "a25e44a2ad3ff2b2659171d22693e593a7f70ccfb226d1f16eab23166d6571cf"

  url "https://github.com/Data-Wise/scribe/releases/download/v#{version}/Scribe_#{version}_aarch64.dmg"

  # Apple Silicon only for now (Intel builds coming soon)
  arch arm: "aarch64"
  depends_on arch: :arm64

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

  # Register global hotkey after install
  postflight do
    ohai "Scribe installed successfully!"
    ohai ""
    ohai "Quick Start:"
    ohai "  • Global hotkey: ⌘⇧N (opens Scribe from anywhere)"
    ohai "  • Command palette: ⌘K"
    ohai "  • Focus mode: ⌘⇧F"
    ohai ""
    ohai "Academic Features:"
    ohai "  • Type $...$ for inline math, $$...$$ for display math"
    ohai "  • Type @ to insert citations from your .bib file"
    ohai "  • Export to PDF/Word/LaTeX via Pandoc"
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

    Academic Features (NEW):
    • LaTeX math rendering (MathJax 3)
    • Citation autocomplete (@trigger)
    • BibTeX/Zotero integration
    • Export to PDF, Word, LaTeX, HTML (via Pandoc)
    • 5 citation styles (APA, Chicago, MLA, IEEE, Harvard)

    Keyboard Shortcuts:
    • ⌘⇧N  Open Scribe from anywhere
    • ⌘K   Command palette
    • ⌘⇧F  Toggle focus mode
    • ⌘E   Toggle write/preview mode

    Optional Dependencies:
    • Pandoc: brew install pandoc
    • LaTeX: brew install --cask mactex (for PDF export)

    Report issues: https://github.com/Data-Wise/scribe/issues
  EOS
end
