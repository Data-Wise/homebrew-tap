class Aiterm < Formula
  include Language::Python::Virtualenv

  desc "Terminal optimizer for AI-assisted development with Claude Code and Gemini CLI"
  homepage "https://github.com/Data-Wise/aiterm"
  url "https://github.com/Data-Wise/aiterm/archive/v0.3.9.tar.gz"
  sha256 "3d48a4e3ffccaa165a66fa4d620edb47812ee720911758a83418991545ae2113"
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
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/aiterm --version")
    system bin/"aiterm", "doctor"
  end
end
