# typed: false
# frozen_string_literal: true

# Obsidian CLI Ops formula for the data-wise/tap Homebrew tap.
class ObsidianCliOps < Formula
  desc "CLI tool for Obsidian vault management with AI-powered graph analysis"
  homepage "https://data-wise.github.io/obsidian-cli-ops/"
  url "https://github.com/Data-Wise/obsidian-cli-ops/archive/refs/tags/v3.0.0.tar.gz"
  sha256 "cc9990bbbd43f49db64134a2581b8598aa1e72798969a2f7fd4764c951b32de8"
  license "MIT"
  head "https://github.com/Data-Wise/obsidian-cli-ops.git", branch: "main"

  depends_on "python@3.12"
  depends_on "zsh"
  depends_on "jq" => :optional

  def install
    # Install Python backend and schema
    libexec.install "src/python"
    libexec.install "schema"

    # Install ZSH CLI wrapper
    libexec.install "src/obs.zsh"

    # Create the obs launcher script
    (bin/"obs").write <<~EOS
      #!/bin/zsh
      # Obsidian CLI Ops launcher (Homebrew-installed)
      export OBS_PYTHON="#{Formula["python@3.12"].opt_bin}/python3.12"
      source "#{libexec}/obs.zsh"
      obs "$@"
    EOS
    (bin/"obs").chmod 0755

    # Create setup helper for Python deps
    (bin/"obs-setup").write <<~EOS
      #!/bin/bash
      set -e
      PYTHON="#{Formula["python@3.12"].opt_bin}/python3.12"
      echo "Installing Python dependencies for Obsidian CLI Ops..."
      "$PYTHON" -m pip install --user -q \\
        'markdown>=3.5' 'python-frontmatter>=1.0.0' 'mistune>=3.0.0' \\
        'PyYAML>=6.0' 'requests>=2.31.0' 'numpy>=1.24.0' \\
        'rich>=13.7.0' 'tqdm>=4.66.0' 'networkx>=3.2' \\
        'click>=8.1.0' 'typer>=0.9.0'
      echo ""
      echo "Initializing database..."
      "$PYTHON" "#{libexec}/python/obs_cli.py" db init 2>/dev/null || true
      echo ""
      echo "Done! Run 'obs' to get started."
    EOS
    (bin/"obs-setup").chmod 0755

    # Essential docs
    prefix.install "README.md"
    prefix.install "LICENSE" if (buildpath/"LICENSE").exist?
  end

  def post_install
    python = Formula["python@3.12"].opt_bin/"python3.12"
    # Try to install Python deps (non-fatal — user can run obs-setup manually)
    begin
      system python, "-m", "pip", "install", "--user", "--upgrade", "-q",
             "markdown>=3.5", "python-frontmatter>=1.0.0", "mistune>=3.0.0",
             "PyYAML>=6.0", "requests>=2.31.0", "numpy>=1.24.0",
             "rich>=13.7.0", "tqdm>=4.66.0", "networkx>=3.2",
             "click>=8.1.0", "typer>=0.9.0"
    rescue StandardError
      opoo "Python deps install failed. Run 'obs-setup' manually."
    end
    # Initialize database
    system python, "#{libexec}/python/obs_cli.py", "db", "init"
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

      If Python deps need reinstalling:
        obs-setup

      Documentation: https://data-wise.github.io/obsidian-cli-ops/
    EOS
  end

  test do
    # Test that core files exist
    assert_path_exists libexec/"obs.zsh"
    assert_path_exists libexec/"python/obs_cli.py"
    assert_path_exists libexec/"schema/vault_db.sql"

    # Test version output
    output = shell_output("#{bin}/obs version 2>&1")
    assert_match "3.0.0", output
  end
end
