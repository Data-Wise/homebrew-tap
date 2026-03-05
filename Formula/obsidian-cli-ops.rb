# typed: false
# frozen_string_literal: true

# Obsidian CLI Ops formula for the data-wise/tap Homebrew tap.
class ObsidianCliOps < Formula
  include Language::Python::Virtualenv

  desc "CLI tool for Obsidian vault management with AI-powered graph analysis"
  homepage "https://data-wise.github.io/obsidian-cli-ops/"
  url "https://github.com/Data-Wise/obsidian-cli-ops/archive/refs/tags/v3.0.0.tar.gz"
  sha256 "cc9990bbbd43f49db64134a2581b8598aa1e72798969a2f7fd4764c951b32de8"
  license "MIT"
  head "https://github.com/Data-Wise/obsidian-cli-ops.git", branch: "main"

  depends_on "python@3.12"
  depends_on "jq" => :optional
  depends_on "zsh"

  def install
    # Create virtualenv with Python dependencies
    venv = virtualenv_create(libexec/"venv", "python3.12", system_site_packages: false)

    # Core dependencies (order matters — install deps before dependents)
    venv.pip_install "PyYAML>=6.0"
    venv.pip_install "markdown>=3.5"
    venv.pip_install "python-frontmatter>=1.0.0"
    venv.pip_install "mistune>=3.0.0"
    venv.pip_install "requests>=2.31.0"
    venv.pip_install "numpy>=1.24.0"
    venv.pip_install "networkx>=3.2"
    venv.pip_install "tqdm>=4.66.0"

    # CLI output (rich has sub-deps handled by pip)
    venv.pip_install "pygments>=2.13.0"
    venv.pip_install "mdurl>=0.1"
    venv.pip_install "markdown-it-py>=2.2.0"
    venv.pip_install "rich>=13.7.0"

    # CLI framework
    venv.pip_install "click>=8.1.0"
    venv.pip_install "shellingham>=1.3.0"
    venv.pip_install "typing_extensions>=3.7.4.3"
    venv.pip_install "typer>=0.9.0"

    # Install Python backend and schema
    libexec.install "src/python"
    libexec.install "schema"

    # Install ZSH CLI wrapper
    libexec.install "src/obs.zsh"

    # Create the obs launcher script
    # Uses the virtualenv Python so deps are always available
    (bin/"obs").write <<~EOS
      #!/bin/zsh
      # Obsidian CLI Ops launcher (Homebrew-installed)
      # Uses Homebrew-managed virtualenv for Python deps.

      # Use Homebrew virtualenv Python (has all deps installed)
      export OBS_PYTHON="#{libexec}/venv/bin/python3"

      # Source the CLI and dispatch
      source "#{libexec}/obs.zsh"
      obs "$@"
    EOS
    (bin/"obs").chmod 0755

    # Essential docs
    prefix.install "README.md"
    prefix.install "LICENSE" if (buildpath/"LICENSE").exist?
  end

  def post_install
    # Initialize database on first install
    system "#{libexec}/venv/bin/python3", "#{libexec}/python/obs_cli.py",
           "db", "init"
  end

  def caveats
    <<~EOS
      Obsidian CLI Ops v#{version} installed!

      Quick start:
        obs                    # List your vaults
        obs discover <path>    # Find Obsidian vaults
        obs stats <vault>      # Show vault statistics
        obs analyze <vault>    # Analyze knowledge graph
        obs health <vault>     # Vault health dashboard

      AI features (optional):
        obs ai setup           # Interactive AI setup wizard
        obs ai status          # Check provider status

      Documentation: https://data-wise.github.io/obsidian-cli-ops/
    EOS
  end

  test do
    # Test that core files exist
    assert_path_exists libexec/"obs.zsh"
    assert_path_exists libexec/"python/obs_cli.py"
    assert_path_exists libexec/"schema/vault_db.sql"

    # Test version output
    output = shell_output("#{bin}/obs version 2>&1", 0)
    assert_match "3.0.0", output
  end
end
