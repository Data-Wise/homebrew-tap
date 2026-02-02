# typed: false
# frozen_string_literal: true

class FlowCli < Formula
  desc "ZSH workflow tools designed for ADHD brains"
  homepage "https://data-wise.github.io/flow-cli/"
  url "https://github.com/Data-Wise/flow-cli/archive/refs/tags/v6.2.0.tar.gz"
  sha256 "122359bd0b56f7c2a21903f26d466ba0578e652617c615f9a3dffdd7119c0fd2"
  license "MIT"
  head "https://github.com/Data-Wise/flow-cli.git", branch: "main"

  depends_on "fzf"
  depends_on "git"
  depends_on "zsh"

  def install
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
