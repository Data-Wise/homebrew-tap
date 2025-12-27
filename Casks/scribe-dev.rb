cask "scribe-dev" do
  version "0.4.0-alpha.1"
  sha256 "a25e44a2ad3ff2b2659171d22693e593a7f70ccfb226d1f16eab23166d6571cf"

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
    ohai "⚠️  This is a DEVELOPMENT build (v#{version})"
    ohai "   Expect bugs and incomplete features."
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
    ⚠️  DEVELOPMENT BUILD (v#{version})

    This is a pre-release version from the development channel.
    Features may be incomplete, unstable, or change without notice.

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
