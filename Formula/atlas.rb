# typed: false
# frozen_string_literal: true

# Atlas - Project state engine for developer workflows
class Atlas < Formula
  desc "Project state engine with registry, sessions, and capture"
  homepage "https://github.com/Data-Wise/atlas"
  url "https://github.com/Data-Wise/atlas/archive/refs/tags/v0.9.1.tar.gz"
  sha256 "521beaf16d4e4d182f1f81dbe6cde4e3dc81e353f4c117734fb0ec91ad0538c7"
  license "MIT"

  depends_on "python@3.12" => :build
  depends_on "node@20" # Required for node-gyp (better-sqlite3)

  def install
    system "npm", "install", *std_npm_args
    bin.install_symlink Dir["#{libexec}/bin/*"]

    # Install shell completions
    bash_completion.install "completions/atlas.bash" => "atlas"
    zsh_completion.install "completions/atlas.zsh" => "_atlas"
    fish_completion.install "completions/atlas.fish"
  end

  def caveats
    <<~EOS
      Atlas v#{version} has been installed!

      Quick Start:
        atlas init                    # Initialize atlas
        atlas sync                    # Import from .STATUS files
        atlas session start PROJECT   # Start work session
        atlas catch "idea"            # Quick capture
        atlas stats                   # Session analytics
        atlas dash                    # Interactive dashboard

      New in v0.9.0:
        React Ink TUI replaces blessed (73% code reduction)
        Multi-panel dashboard: Tab cycles SINGLE/SPLIT/TRIPLE layouts
        MCP Server with 10 tools for Claude integration
        atlas plan                    # Guided daily planning

      Shell completions have been installed for bash, zsh, and fish.

      Data is stored in: ~/.atlas/

      Documentation: https://data-wise.github.io/atlas/
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/atlas --version")
    assert_match "Usage: atlas", shell_output("#{bin}/atlas --help")

    # Test init creates config directory
    ENV["ATLAS_CONFIG"] = testpath/".atlas"
    system bin/"atlas", "init"
    assert_path_exists testpath/".atlas"
  end
end
