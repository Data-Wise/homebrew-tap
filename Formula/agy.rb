class Agy < Formula
  include Language::Python::Virtualenv

  desc "Causal inference assumption validator and workspace state synchronization CLI"
  homepage "https://github.com/Data-Wise/agy-cli"
  url "https://github.com/Data-Wise/agy-cli/archive/refs/tags/v0.3.0.tar.gz"
  sha256 "fc2e6a68391f8fd00e3bc36987cd3a298313774007ab74723c1d001e015e3901"
  license "MIT"

  depends_on "python@3.12"

  def install
    venv = virtualenv_create(libexec, "python3.12")

    # Install dependencies explicitly to ensure correct version pinning in virtualenv
    venv.pip_install "click>=8.1.0"
    venv.pip_install "rich>=13.7.0"
    venv.pip_install "PyYAML>=6.0"
    venv.pip_install "networkx>=3.2"
    venv.pip_install "pandas>=2.0.0"
    venv.pip_install "numpy>=1.24.0"
    venv.pip_install "requests>=2.31.0"

    venv.pip_install buildpath
    bin.install_symlink libexec/"bin/cagy"
  end

  test do
    system bin/"cagy", "status"
  end
end
