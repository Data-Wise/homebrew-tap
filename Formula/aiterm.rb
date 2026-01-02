class Aiterm < Formula
  include Language::Python::Virtualenv

  desc "Terminal optimizer for AI-assisted development with Claude Code and Gemini CLI"
  homepage "https://github.com/Data-Wise/aiterm"
  url "https://github.com/Data-Wise/aiterm/archive/v0.7.1.tar.gz"
  sha256 "9a40707ddfd39899745b74b4f0d52e20e4ffe5e8e3ac070c16167406cb77e42a"
  license "MIT"

  depends_on "python@3.12"

  def install
    venv = virtualenv_create(libexec, "python3.12", system_site_packages: false)

    # Install all dependencies including transitive ones
    # typer deps: click, shellingham, typing_extensions
    venv.pip_install "click>=8.0.0"
    venv.pip_install "shellingham>=1.3.0"
    venv.pip_install "typing_extensions>=3.7.4.3"
    venv.pip_install "typer>=0.9.0"

    # rich deps: markdown-it-py, pygments, mdurl
    venv.pip_install "mdurl>=0.1"
    venv.pip_install "markdown-it-py>=2.2.0"
    venv.pip_install "pygments>=2.13.0"
    venv.pip_install "rich>=13.0.0"

    # questionary deps: prompt_toolkit, wcwidth
    venv.pip_install "wcwidth>=0.1.4"
    venv.pip_install "prompt_toolkit>=2.0,<4.0"
    venv.pip_install "questionary>=2.0.0"

    # Direct deps
    venv.pip_install "pyyaml>=6.0"

    # Install the package itself
    venv.pip_install buildpath

    bin.install_symlink libexec/"bin/aiterm"
    bin.install_symlink libexec/"bin/ait"

    # Install flow-cli integration files
    (share/"aiterm/flow-integration").install "flow-integration/aiterm.zsh"
    (share/"aiterm/flow-integration").install "flow-integration/install-symlink.sh"
  end

  def post_install
    # Install flow-cli integration if flow-cli is present
    flow_cli_paths = [
      Pathname.new(Dir.home)/"projects/dev-tools/flow-cli",
      Pathname.new(Dir.home)/".local/share/flow-cli",
      Pathname.new(Dir.home)/".flow-cli",
    ]

    flow_cli_dir = flow_cli_paths.find { |p| p.directory? && (p/"flow.plugin.zsh").exist? }

    if flow_cli_dir
      target_dir = flow_cli_dir/"zsh/functions"
      target_dir.mkpath
      target = target_dir/"aiterm-integration.zsh"
      source = prefix/"share/aiterm/flow-integration/aiterm.zsh"

      if source.exist? && !target.exist?
        target.make_symlink(source)
        ohai "Installed flow-cli integration: tm command available"
      end
    end
  end

  def caveats
    <<~EOS
      To use the `tm` dispatcher with flow-cli:

        #{prefix}/share/aiterm/flow-integration/install-symlink.sh

      Or manually:
        ln -sf #{prefix}/share/aiterm/flow-integration/aiterm.zsh \\
          ~/projects/dev-tools/flow-cli/zsh/functions/aiterm-integration.zsh

      Then restart your shell or run: source ~/.zshrc
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/aiterm --version")
    system bin/"aiterm", "doctor"
  end
end
