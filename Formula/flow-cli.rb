# typed: false
# frozen_string_literal: true

# FlowCli formula for the data-wise/tap Homebrew tap.
class FlowCli < Formula
  desc "ZSH workflow tools designed for ADHD brains"
  homepage "https://data-wise.github.io/flow-cli/"
  url "https://github.com/Data-Wise/flow-cli/archive/refs/tags/v7.6.0.tar.gz"
  sha256 "01e82afb30e3c720050b1a124a6f2424062cf6a7a1ec2edc6e584a46668757b3"
  license "MIT"
  head "https://github.com/Data-Wise/flow-cli.git", branch: "main"

  depends_on "fzf"
  depends_on "git"
  depends_on "zsh"

  def install
    # Man pages to proper Homebrew location
    man1.install Dir["man/man1/*"] if (buildpath/"man/man1").exist?
    rm_r(buildpath/"man") if (buildpath/"man").exist?

    # Core runtime files only (selective install)
    prefix.install "flow.plugin.zsh"
    prefix.install "lib"
    prefix.install "commands"
    prefix.install "completions"
    prefix.install "hooks"
    prefix.install "setup"
    prefix.install "scripts"
    prefix.install "config" if (buildpath/"config").exist?
    prefix.install "plugins" if (buildpath/"plugins").exist?
    prefix.install "zsh" if (buildpath/"zsh").exist?

    # Essential docs
    prefix.install "README.md"
    prefix.install "CHANGELOG.md"
    prefix.install "LICENSE"

    # Installer scripts
    prefix.install "install.sh" if (buildpath/"install.sh").exist?
    prefix.install "uninstall.sh" if (buildpath/"uninstall.sh").exist?

    # Create a loader script
    (prefix/"bin/flow-cli-init").write <<~EOS
      #!/bin/zsh
      echo "source #{prefix}/flow.plugin.zsh"
    EOS
    (prefix/"bin/flow-cli-init").chmod 0755
  end

  def caveats
    <<~EOS
      To activate flow-cli, add this to your ~/.zshrc:

        source #{prefix}/flow.plugin.zsh

      Or use the init script:

        eval "$(#{prefix}/bin/flow-cli-init)"

      Then restart your shell or run:
        source ~/.zshrc

      Quick start:
        work my-project    # Start session
        win "Fixed bug"    # Log accomplishment
        finish             # End session
    EOS
  end

  test do
    # Test that the plugin file exists
    assert_path_exists prefix/"flow.plugin.zsh"

    # Test that flow command is defined in the plugin
    output = shell_output("grep -l 'flow()' #{prefix}/**/*.zsh")
    assert_match "flow", output
  end
end
