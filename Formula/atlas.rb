class Atlas < Formula
  desc "Project state engine - registry, sessions, capture, and context for ADHD-friendly workflow"
  homepage "https://github.com/Data-Wise/atlas"
  url "https://github.com/Data-Wise/atlas/archive/refs/tags/v0.5.5.tar.gz"
  sha256 "e875ed5426abdfcf2c29bfefa9c1f6098f85ee834b9a0667325599e1bab56c1f"
  license "MIT"

  depends_on "node@20"
  depends_on "python@3.12" => :build  # Required for node-gyp (better-sqlite3)

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
        atlas where                   # Show context

      Shell completions have been installed for bash, zsh, and fish.

      Data is stored in: ~/.atlas/

      For SQLite backend (better performance):
        atlas --storage sqlite status

      Documentation: https://github.com/Data-Wise/atlas#readme
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/atlas --version")
    assert_match "Usage: atlas", shell_output("#{bin}/atlas --help")

    # Test init creates config directory
    ENV["ATLAS_CONFIG"] = testpath/".atlas"
    system bin/"atlas", "init"
    assert_predicate testpath/".atlas", :exist?
  end
end
