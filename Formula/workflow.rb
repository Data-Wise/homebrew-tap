class Workflow < Formula
  desc "ADHD-friendly workflow automation with auto-delegation - Claude Code plugin"
  homepage "https://github.com/Data-Wise/claude-plugins"
  url "https://github.com/Data-Wise/claude-plugins/releases/download/workflow-v0.1.0/workflow-v0.1.0.tar.gz"
  sha256 "cf155a7ad9855d5c5f4180847b3c62dbda6c99b410485b681b7148f270338783"
  version "0.1.0"
  license "MIT"

  depends_on "jq"

  def install
    # Install plugin files to libexec
    libexec.install Dir["*"]

    # Create wrapper scripts
    (bin/"workflow-install").write <<~EOS
      #!/bin/bash
      set -e

      PLUGIN_DIR=#{libexec}
      TARGET_DIR="$HOME/.claude/plugins/workflow"

      echo "Installing Workflow Plugin v#{version}..."

      # Create .claude/plugins directory if it doesn't exist
      mkdir -p "$HOME/.claude/plugins"

      # Remove existing installation if present
      if [ -d "$TARGET_DIR" ] || [ -L "$TARGET_DIR" ]; then
        echo "Removing existing installation..."
        rm -rf "$TARGET_DIR"
      fi

      # Copy plugin files
      echo "Copying plugin files..."
      cp -r "$PLUGIN_DIR" "$TARGET_DIR"

      # Run tests to verify installation
      echo "Verifying installation..."
      if bash "$TARGET_DIR/tests/test-plugin-structure.sh"; then
        echo ""
        echo "✅ Workflow Plugin v#{version} installed successfully!"
        echo ""
        echo "Location: $TARGET_DIR"
        echo ""
        echo "Next steps:"
        echo "  1. Restart Claude Code"
        echo "  2. Test auto-activation: mention 'API design'"
        echo "  3. Try: /brainstorm quick feature notifications"
        echo "  4. Read: $TARGET_DIR/docs/QUICK-START.md"
        echo ""
      else
        echo "❌ Installation verification failed"
        exit 1
      fi
    EOS

    (bin/"workflow-uninstall").write <<~EOS
      #!/bin/bash
      set -e

      TARGET_DIR="$HOME/.claude/plugins/workflow"

      if [ ! -d "$TARGET_DIR" ] && [ ! -L "$TARGET_DIR" ]; then
        echo "Workflow Plugin is not installed"
        exit 0
      fi

      echo "Uninstalling Workflow Plugin..."
      rm -rf "$TARGET_DIR"
      echo "✅ Workflow Plugin uninstalled"
      echo ""
      echo "Please restart Claude Code to complete uninstallation"
    EOS

    chmod 0755, bin/"workflow-install"
    chmod 0755, bin/"workflow-uninstall"
  end

  def post_install
    system bin/"workflow-install"
  end

  def caveats
    <<~EOS
      Workflow Plugin v#{version} has been installed to:
        ~/.claude/plugins/workflow

      The plugin includes:
        • 3 auto-activating skills (backend, frontend, devops)
        • Enhanced /brainstorm command (8 modes)
        • Workflow orchestrator agent
        • 60+ proven design patterns

      Quick Start:
        1. Restart Claude Code
        2. Test auto-activation: mention "API design"
        3. Try: /brainstorm quick feature notifications
        4. Read: ~/.claude/plugins/workflow/docs/QUICK-START.md

      Documentation:
        • Full guide: ~/.claude/plugins/workflow/README.md
        • Quick start: ~/.claude/plugins/workflow/docs/QUICK-START.md
        • Reference: ~/.claude/plugins/workflow/docs/REFCARD.md
        • Patterns: ~/.claude/plugins/workflow/PATTERN-LIBRARY.md

      Uninstall:
        brew uninstall workflow
    EOS
  end

  test do
    assert_predicate libexec/".claude-plugin/plugin.json", :exist?
    assert_predicate libexec/"README.md", :exist?
    assert_predicate libexec/"commands/brainstorm.md", :exist?
    assert_predicate libexec/"skills/design/backend-designer.md", :exist?
    assert_predicate libexec/"skills/design/frontend-designer.md", :exist?
    assert_predicate libexec/"skills/design/devops-helper.md", :exist?
    assert_predicate libexec/"agents/orchestrator.md", :exist?

    # Validate JSON files
    system "jq", "empty", libexec/".claude-plugin/plugin.json"
    system "jq", "empty", libexec/"package.json"

    # Run plugin tests
    system "bash", libexec/"tests/test-plugin-structure.sh"
  end
end
