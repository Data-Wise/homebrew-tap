# typed: false
# frozen_string_literal: true

# ADHD-friendly note-taking CLI with multi-vault support
class ScribeCli < Formula
  desc "ADHD-friendly note-taking CLI with multi-vault support"
  homepage "https://github.com/Data-Wise/scribe-sw"
  url "https://github.com/Data-Wise/scribe-sw/archive/refs/tags/v0.3.0.tar.gz"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"
  license "MIT"

  depends_on xcode: ["14.0", :build]
  depends_on :macos

  def install
    # Build the CLI
    system "swift", "build", "--disable-sandbox", "-c", "release", "--product", "scribe-cli"

    # Install binary
    bin.install ".build/release/scribe-cli"

    # Install shell completions
    bash_completion.install "completions/scribe-cli.bash" => "scribe-cli"
    zsh_completion.install "completions/_scribe-cli"
    fish_completion.install "completions/scribe-cli.fish"
  end

  def caveats
    <<~EOS
      Scribe CLI v#{version} - ADHD-Friendly Note-Taking CLI

      Shell completions have been installed to:
        Bash: #{bash_completion}/scribe-cli
        Zsh:  #{zsh_completion}/_scribe-cli
        Fish: #{fish_completion}/scribe-cli.fish

      To use completions, you may need to reload your shell or run:
        Bash: source #{bash_completion}/scribe-cli
        Zsh:  source ~/.zshrc
        Fish: (restart fish)

      Get started:
        scribe-cli help
        scribe-cli vault create my-vault ~/Documents/my-vault generic

      Documentation: https://github.com/Data-Wise/scribe-sw
    EOS
  end

  test do
    # Test that the binary runs
    assert_match "Scribe CLI", shell_output("#{bin}/scribe-cli help")

    # Test version
    system bin/"scribe-cli", "help"
  end
end
