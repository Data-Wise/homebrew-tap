class Aiterm < Formula
  include Language::Python::Virtualenv

  desc "Terminal optimizer for AI-assisted development with Claude Code and Gemini CLI"
  homepage "https://github.com/Data-Wise/aiterm"
  url "https://github.com/Data-Wise/aiterm/archive/v0.2.1.tar.gz"
  sha256 "b067f7c3ce8e90bc859ed2ba6a4c291b433e94a6216b62f1a951c9cb4fe129a5"
  license "MIT"

  depends_on "python@3.12"

  def install
    venv = virtualenv_create(libexec, "python3.12", system_site_packages: false)
    venv.pip_install buildpath
    bin.install_symlink libexec/"bin/aiterm"
    bin.install_symlink libexec/"bin/ait"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/aiterm --version")
    system bin/"aiterm", "doctor"
  end
end
