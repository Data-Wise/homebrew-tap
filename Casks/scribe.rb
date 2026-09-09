cask "scribe" do
  version "1.23.0"

  # Architecture-specific SHA256 hashes
  on_arm do
    sha256 "109e2786aefba140e1f4720e89aee0aa44fa4465da9e013ddf7d368b2dab2ecb"

    url "https://github.com/Data-Wise/scribe/releases/download/v#{version}/Scribe_#{version}_aarch64.dmg"
  end
  on_intel do
    sha256 "bcbb6ae184e5032fe64b19ace7195e77d8f4b57fb61e9300531c74f75b34b87a"

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

  app "Scribe.app"

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
    - Explorer tab in the sidebar - status-grouped project tree alongside
      Compact/Card, with expand/collapse per project
    - New 3-pill tab selector (Compact/Card/Explorer) replaces the old
      single toggle button
    - 2,342 tests passing

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
