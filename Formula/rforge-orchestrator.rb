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
    # Use stable /opt/homebrew/opt path (survives upgrades) instead of versioned Cellar path
    (bin/"rforge-orchestrator-install").write <<~EOS
      #!/bin/bash
      # Note: Not using set -e to handle permission errors gracefully

      PLUGIN_NAME="rforge-orchestrator"
      TARGET_DIR="$HOME/.claude/plugins/$PLUGIN_NAME"
      # Use stable opt path - Homebrew maintains this symlink across upgrades
      SOURCE_DIR="$(brew --prefix)/opt/rforge-orchestrator/libexec"

      echo "Installing RForge Orchestrator plugin to Claude Code..."

      # Create plugins directory if it doesn't exist
      mkdir -p "$HOME/.claude/plugins" 2>/dev/null || true

      # Remove existing installation (handle macOS extended attributes)
      if [ -L "$TARGET_DIR" ] || [ -d "$TARGET_DIR" ]; then
          rm -rf "$TARGET_DIR" 2>/dev/null || rm -f "$TARGET_DIR" 2>/dev/null || true
      fi

      # Create symlink to Homebrew-managed files
      # Try multiple approaches for macOS compatibility
      LINK_SUCCESS=false

      if ln -sf "$SOURCE_DIR" "$TARGET_DIR" 2>/dev/null; then
          LINK_SUCCESS=true
      elif rm -f "$TARGET_DIR" 2>/dev/null && ln -s "$SOURCE_DIR" "$TARGET_DIR" 2>/dev/null; then
          LINK_SUCCESS=true
      elif ln -sfh "$SOURCE_DIR" "$TARGET_DIR" 2>/dev/null; then
          LINK_SUCCESS=true
      fi

      if [ "$LINK_SUCCESS" = true ]; then
          # Also create symlink in local-marketplace for plugin discovery
          MARKETPLACE_DIR="$HOME/.claude/local-marketplace"
          mkdir -p "$MARKETPLACE_DIR" 2>/dev/null || true
          ln -sfh "$TARGET_DIR" "$MARKETPLACE_DIR/$PLUGIN_NAME" 2>/dev/null || true

          # Try to auto-enable via jq if available
          SETTINGS_FILE="$HOME/.claude/settings.json"
          AUTO_ENABLED=false
          if command -v jq &>/dev/null && [ -f "$SETTINGS_FILE" ]; then
              TEMP_FILE=$(mktemp)
              if jq --arg plugin "${PLUGIN_NAME}@local-plugins" '.enabledPlugins[$plugin] = true' "$SETTINGS_FILE" > "$TEMP_FILE" 2>/dev/null; then
                  mv "$TEMP_FILE" "$SETTINGS_FILE"
                  AUTO_ENABLED=true
              else
                  rm -f "$TEMP_FILE" 2>/dev/null
              fi
          fi

          echo "✅ RForge Orchestrator plugin installed successfully!"
          echo ""
          if [ "$AUTO_ENABLED" = true ]; then
              echo "Plugin auto-enabled in Claude Code."
          else
              echo "To enable, run: claude plugin install rforge-orchestrator@local-plugins"
          fi
          echo ""
          echo "Commands: /rforge:analyze, /rforge:quick, /rforge:thorough"
      else
          echo "⚠️  Automatic symlink failed (macOS permissions)."
          echo ""
          echo "Run this command manually to complete installation:"
          echo ""
          echo "  ln -sf $SOURCE_DIR $TARGET_DIR"
          echo ""
          exit 0  # Don't fail the brew install
      fi
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

      If not auto-enabled, run:
        claude plugin install rforge-orchestrator@local-plugins

      Requirements:
        - Claude Code CLI must be installed
        - RForge MCP server must be configured in ~/.claude/settings.json

      Available commands:
        /rforge:analyze  - Analyze R project and recommend tools
        /rforge:quick    - Quick project analysis
        /rforge:thorough - Thorough multi-stage analysis

      If symlink failed (macOS permissions), run manually:
        ln -sf $(brew --prefix)/opt/rforge-orchestrator/libexec ~/.claude/plugins/rforge-orchestrator

      For more information:
        https://github.com/Data-Wise/claude-plugins/tree/main/rforge-orchestrator
    EOS
  end
end
