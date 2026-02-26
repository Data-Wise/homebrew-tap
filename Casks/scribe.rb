cask "scribe" do
  version "1.22.0"

  # Architecture-specific SHA256 hashes
  on_arm do
    sha256 "3d971ba3e7059fec448508310f6c43f7bb8e5c57097cd8ee862bd75f73075ae9"

    url "https://github.com/Data-Wise/scribe/releases/download/v#{version}/Scribe_#{version}_aarch64.dmg"
  end
  on_intel do
    sha256 "a7563fa74a0a35fee435e5f57dbd3a11fee9609067304d015d971549a282744a"

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
    ohai "What's New in v#{version}:"
    ohai "  - Responsive layout engine with auto-collapse sidebars"
    ohai "  - Global UI zoom (Cmd+/Cmd-, 50%-200%)"
    ohai "  - macOS 4-pane tiling support (350×350 minimum)"
    ohai "  - Right sidebar resize handle"
    ohai "  - 2,326 tests passing"
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

    New in v#{version}:
    - Responsive layout engine with auto-collapse sidebars
    - Global UI zoom (Cmd+/Cmd-, 50%-200%) with persistent preferences
    - macOS 4-pane tiling support (350×350 minimum window size)
    - Right sidebar resize handle (200-600px)
    - Touch resize + reduced-motion accessibility support
    - 2,326 tests passing

    Features:
    - Three Editor Modes - Source (Cmd+1), Live Preview (Cmd+2), Reading (Cmd+3)
    - Callouts - 11 types with color coding (> [!note], > [!tip], > [!warning], etc.)
    - LaTeX Math - KaTeX rendering ($...$ inline, $$...$$ display)
    - 10 ADHD-friendly themes (visual gallery)
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
