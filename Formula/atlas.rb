# typed: false
# frozen_string_literal: true

# Atlas - Project state engine for developer workflows
class Atlas < Formula
  desc "Project state engine with registry, sessions, and capture"
  homepage "https://github.com/Data-Wise/atlas"
  url "https://github.com/Data-Wise/atlas/archive/refs/tags/v0.18.1.tar.gz"
  sha256 "6c88bf5344e1697b0c196a3a3fcfca8625757a37b3f118e1d14a0b3d65d5c05e"
  license "MIT"

  depends_on "python@3.12" => :build
  depends_on "node"

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

      Shell completions have been installed for bash, zsh, and fish.

      Data is stored in $XDG_CONFIG_HOME/atlas (or ~/.config/atlas) on new
      installs; existing ~/.atlas installs keep working unchanged until you
      run `atlas migrate --xdg`. Run `atlas doctor` to check which location
      is active.

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
