cask "scribe-dev" do
  version "0.5.0-beta.1"
  sha256 "c31513bc8cc09f88806b8d341fa794b08bdb536c29db1fc3cca193429b33e62b"

  url "https://github.com/Data-Wise/scribe/releases/download/v#{version}/Scribe_#{version}_aarch64.dmg"

  # Apple Silicon only for now
  arch arm: "aarch64"
  depends_on arch: :arm64

  name "Scribe (Dev)"
  desc "ADHD-friendly distraction-free writer (development channel)"
  homepage "https://github.com/Data-Wise/scribe"

  # Track pre-releases (alpha, beta, rc)
  livecheck do
    url "https://github.com/Data-Wise/scribe/releases"
    regex(/^v?(\d+(?:\.\d+)*(?:-(?:alpha|beta|rc)\.\d+))$/i)
    strategy :github_releases do |json, regex|
      json.filter_map do |release|
        match = release["tag_name"]&.match(regex)
        next unless match
        next if release["draft"]

        match[1]
      end
    end
  end

  # Conflicts with stable version
  conflicts_with cask: "data-wise/tap/scribe"

  # Require macOS 10.15+ (Catalina)
  depends_on macos: ">= :catalina"

  app "Scribe.app"

  postflight do
    ohai "Scribe (Dev) installed successfully!"
    ohai ""
    ohai "⚠️  This is a BETA build (v#{version})"
    ohai "   Nearing v1.0 stable release."
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
    ⚠️  BETA BUILD (v#{version})

    This is a beta version nearing v1.0 stable release.
    Most features are complete. Please report any issues.

    To switch to stable (when available):
      brew uninstall --cask scribe-dev
      brew install --cask data-wise/tap/scribe

    Current Features:
    • HybridEditor (Markdown + Preview)
    • 10 ADHD-friendly themes
    • 14 recommended fonts
    • Wiki-links and tags
    • Focus mode & global hotkey (⌘⇧N)
    • LaTeX math (KaTeX)
    • Citation autocomplete
    • Export via Pandoc

    Report issues: https://github.com/Data-Wise/scribe/issues
  EOS
end
