class RforgeOrchestrator < Formula
  desc "Auto-delegation orchestrator for RForge MCP tools - Claude Code plugin"
  homepage "https://github.com/Data-Wise/claude-plugins"
  url "https://github.com/Data-Wise/claude-plugins/archive/refs/tags/rforge-orchestrator-v0.1.0.tar.gz"
  sha256 "8c065681864b18c9bea41996aa33bec17b95697ed8330846c8b510bd81bbad2e"
  license "MIT"

  depends_on "jq" => :optional

  def install
    # Install plugin to libexec (Homebrew-managed location)
    libexec.install Dir["rforge-orchestrator/*"]

    # Create wrapper script that symlinks to ~/.claude/plugins/
    (bin/"rforge-orchestrator-install").write <<~EOS
      #!/bin/bash
      set -e

      PLUGIN_NAME="rforge-orchestrator"
      TARGET_DIR="$HOME/.claude/plugins/$PLUGIN_NAME"
      SOURCE_DIR="#{libexec}"

      echo "Installing RForge Orchestrator plugin to Claude Code..."

      # Create plugins directory if it doesn't exist
      mkdir -p "$HOME/.claude/plugins"

      # Remove existing installation
      if [ -L "$TARGET_DIR" ] || [ -d "$TARGET_DIR" ]; then
          rm -rf "$TARGET_DIR"
      fi

      # Create symlink to Homebrew-managed files
      ln -sf "$SOURCE_DIR" "$TARGET_DIR"

      echo "✅ RForge Orchestrator plugin installed successfully!"
      echo ""
      echo "The plugin is now available in Claude Code."
      echo "Use these slash commands:"
      echo "  /rforge:analyze  - Analyze R project and recommend tools"
      echo "  /rforge:quick    - Quick project analysis"
      echo "  /rforge:thorough - Thorough multi-stage analysis"
      echo ""
      echo "To uninstall: brew uninstall rforge-orchestrator"
    EOS

    (bin/"rforge-orchestrator-uninstall").write <<~EOS
      #!/bin/bash
      set -e

      PLUGIN_NAME="rforge-orchestrator"
      TARGET_DIR="$HOME/.claude/plugins/$PLUGIN_NAME"

      if [ -L "$TARGET_DIR" ] || [ -d "$TARGET_DIR" ]; then
          rm -rf "$TARGET_DIR"
          echo "✅ RForge Orchestrator plugin uninstalled"
      else
          echo "Plugin not found at $TARGET_DIR"
      fi
    EOS

    chmod "+x", bin/"rforge-orchestrator-install"
    chmod "+x", bin/"rforge-orchestrator-uninstall"
  end

  def post_install
    # Auto-install plugin after brew install
    system bin/"rforge-orchestrator-install"
  end

  def post_uninstall
    # Auto-uninstall plugin after brew uninstall
    system bin/"rforge-orchestrator-uninstall" if (bin/"rforge-orchestrator-uninstall").exist?
  end

  test do
    assert_predicate libexec/".claude-plugin/plugin.json", :exist?
    assert_predicate libexec/"commands", :directory?
    assert_predicate libexec/"agents", :directory?
  end

  def caveats
    <<~EOS
      The RForge Orchestrator plugin has been installed to:
        ~/.claude/plugins/rforge-orchestrator

      Requirements:
        - Claude Code CLI must be installed
        - RForge MCP server must be configured in ~/.claude/settings.json

      Available commands:
        /rforge:analyze  - Analyze R project and recommend tools
        /rforge:quick    - Quick project analysis
        /rforge:thorough - Thorough multi-stage analysis

      For more information:
        https://github.com/Data-Wise/claude-plugins/tree/main/rforge-orchestrator
    EOS
  end
end
