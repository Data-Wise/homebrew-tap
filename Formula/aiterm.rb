class Aiterm < Formula
  include Language::Python::Virtualenv

  desc "Terminal optimizer for AI-assisted development with Claude Code and Gemini CLI"
  homepage "https://github.com/Data-Wise/aiterm"
  url "https://github.com/Data-Wise/aiterm/archive/v0.1.0.tar.gz"
  sha256 "114ef7fe7c51f46a6cdea6d31f68d62576986ead920831a43f265fb052c61f8c"
  license "MIT"

  depends_on "python@3.12"

  def install
    virtualenv_install_with_resources
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/aiterm --version")
    system bin/"aiterm", "doctor"
  end
end
