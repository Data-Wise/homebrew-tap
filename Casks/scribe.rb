cask "scribe" do
  version "1.19.0"

  # Architecture-specific SHA256 hashes
  on_arm do
    sha256 "fbc649d5250aea51706be0696d7712f4f2794cd46873f6f42d262a9cca1706d6"

    url "https://github.com/Data-Wise/scribe/releases/download/v#{version}/Scribe_#{version}_aarch64.dmg"
  end
  on_intel do
    sha256 "76965116e075aad5e2eb0e4a315fd111f0399310f204d969157d0c4ca2f6efa8"

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
    ohai "What's New in v1.17.0:"
    ohai "  - Quarto autocomplete (YAML, chunk options, cross-refs, code chunks)"
    ohai "  - Context-aware LaTeX completions scoped to math mode"
    ohai "  - 2,187 tests passing"
    ohai ""
    ohai "Quick Start:"
    ohai "  - Global hotkey: Cmd+Shift+N (opens Scribe from anywhere)"
    ohai "  - Command palette: Cmd+K"
    ohai "  - Focus mode: Cmd+Shift+F"
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

    New in v1.17.0:
    - Quarto autocomplete - YAML frontmatter, chunk options, cross-references
    - Context-aware LaTeX completions - scoped to math mode, suppressed in code blocks
    - Quarto code chunk completions - R, Python, Julia, OJS, Mermaid, Graphviz
    - 2,187 tests passing

    Features:
    - Three Editor Modes - Source (Cmd+1), Live Preview (Cmd+2), Reading (Cmd+3)
    - Callouts - 11 types with color coding (> [!note], > [!tip], > [!warning], etc.)
    - LaTeX Math - KaTeX rendering ($...$ inline, $$...$$ display)
    - 8 ADHD-friendly themes (visual gallery)
    - 14 recommended fonts
    - Wiki-links and tags with backlinks
    - Focus mode & global hotkey (Cmd+Shift+N)
    - Citation autocomplete
    - Export via Pandoc
    - Quick Actions (Improve, Expand, Summarize, Explain, Research)

    Keyboard Shortcuts:
    - Cmd+Shift+N    Open Scribe from anywhere
    - Cmd+,          Settings (fuzzy search)
    - Cmd+K          Command palette
    - Cmd+Shift+F    Toggle focus mode
    - Cmd+E          Toggle write/preview mode
    - Cmd+Option+1-9 Quick Actions (customizable)

    Optional Dependencies:
    - Pandoc: brew install pandoc
    - LaTeX: brew install --cask mactex (for PDF export)

    Report issues: https://github.com/Data-Wise/scribe/issues
  EOS
end
