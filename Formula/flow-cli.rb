# typed: false
# frozen_string_literal: true

# FlowCli formula for the data-wise/tap Homebrew tap.
class FlowCli < Formula
  desc "ZSH workflow tools designed for ADHD brains"
  homepage "https://data-wise.github.io/flow-cli/"
  url "https://github.com/Data-Wise/flow-cli/archive/refs/tags/v7.4.1.tar.gz"
  sha256 "c2c3a4327c78ecdf25b7328d395da1144425e383d01575ba5b9c4b6b32eae663"
  license "MIT"
  head "https://github.com/Data-Wise/flow-cli.git", branch: "main"

  depends_on "fzf"
  depends_on "git"
  depends_on "zsh"

  def install
    # Move man pages to proper Homebrew location (share/man) before installing
    man1.install Dir["man/man1/*"] if (buildpath/"man/man1").exist?
    rm_r(buildpath/"man") if (buildpath/"man").exist?

    # Install the plugin files
    prefix.install Dir["*"]

    # Create a loader script
    (prefix/"bin/flow-cli-init").write <<~EOS
      #!/bin/zsh
      # Source this file in your .zshrc to enable flow-cli
      # Add to .zshrc: eval "$(flow-cli-init)"

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
