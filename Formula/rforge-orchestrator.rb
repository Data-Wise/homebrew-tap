# typed: false
# frozen_string_literal: true

# RforgeOrchestrator formula for the data-wise/tap Homebrew tap.
class RforgeOrchestrator < Formula
  desc "Auto-delegation orchestrator for RForge MCP tools - Claude Code plugin"
  homepage "https://github.com/Data-Wise/claude-plugins"
  url "https://github.com/Data-Wise/claude-plugins/archive/refs/tags/rforge-orchestrator-v0.1.0.tar.gz"
  sha256 "8c065681864b18c9bea41996aa33bec17b95697ed8330846c8b510bd81bbad2e"
  license "MIT"

  depends_on "jq" => :optional

  def install
    libexec.install Dir["rforge-orchestrator/*"]

    (bin/"rforge-orchestrator-install").write <<~EOS
      #!/bin/bash
      # NOTE: Not using set -e to handle permission errors gracefully

      PLUGIN_NAME="rforge-orchestrator"
      TARGET_DIR="$HOME/.claude/plugins/$PLUGIN_NAME"
      # Use stable opt path — Homebrew maintains this symlink across upgrades
      SOURCE_DIR="$(brew --prefix)/opt/rforge-orchestrator/libexec"

      echo "Installing RForgeOrchestrator plugin to Claude Code..."

      # Create plugins directory if it doesn't exist
      mkdir -p "$HOME/.claude/plugins" 2>/dev/null || true

      # Remove existing installation (handle macOS extended attributes)
      if [ -L "$TARGET_DIR" ] || [ -d "$TARGET_DIR" ]; then
          rm -rf "$TARGET_DIR" 2>/dev/null || rm -f "$TARGET_DIR" 2>/dev/null || true
      fi

      # Create symlink to Homebrew-managed files
      # Try multiple approaches for macOS compatibility
      LINK_SUCCESS=false

      # Method 1: ln -sfh (macOS, replaces symlink atomically, prevents circular symlinks)
      if ln -sfh "$SOURCE_DIR" "$TARGET_DIR" 2>/dev/null; then
          LINK_SUCCESS=true
      # Method 2: Standard symlink
      elif ln -sf "$SOURCE_DIR" "$TARGET_DIR" 2>/dev/null; then
          LINK_SUCCESS=true
      # Method 3: Remove and recreate
      elif rm -f "$TARGET_DIR" 2>/dev/null && ln -s "$SOURCE_DIR" "$TARGET_DIR" 2>/dev/null; then
          LINK_SUCCESS=true
      fi

      if [ "$LINK_SUCCESS" = true ]; then
          # Also create symlink in local-marketplace for plugin discovery
          MARKETPLACE_DIR="$HOME/.claude/local-marketplace"
          mkdir -p "$MARKETPLACE_DIR" 2>/dev/null || true
          ln -sfh "$TARGET_DIR" "$MARKETPLACE_DIR/$PLUGIN_NAME" 2>/dev/null || true

          # Add to marketplace.json manifest (required for 'claude plugin install' discovery)
          MANIFEST_FILE="$MARKETPLACE_DIR/.claude-plugin/marketplace.json"
          PLUGIN_DESC="Auto-delegation orchestrator for RForge MCP tools"
          if command -v jq &>/dev/null && [ -f "$MANIFEST_FILE" ]; then
              # Check if plugin already exists in manifest
              if ! jq -e --arg name "$PLUGIN_NAME" '.plugins[] | select(.name == $name)' "$MANIFEST_FILE" >/dev/null 2>&1; then
                  TEMP_FILE=$(mktemp)
                  if jq --arg name "$PLUGIN_NAME" --arg desc "$PLUGIN_DESC" \
                      '.plugins = [{"name": $name, "source": ("./"+$name), "description": $desc}] + .plugins' \
                      "$MANIFEST_FILE" > "$TEMP_FILE" 2>/dev/null; then
                      mv "$TEMP_FILE" "$MANIFEST_FILE"
                  else
                      rm -f "$TEMP_FILE" 2>/dev/null
                  fi
              fi
          fi

          # Try to auto-enable via jq if available
          # Skip if Claude Code is running (holds file locks that can block mv)
          SETTINGS_FILE="$HOME/.claude/settings.json"
          AUTO_ENABLED=false
          CLAUDE_RUNNING=false

          if pgrep -x "claude" >/dev/null 2>&1; then
              CLAUDE_RUNNING=true
          fi

          if [ "$CLAUDE_RUNNING" = false ] && command -v jq &>/dev/null && [ -f "$SETTINGS_FILE" ]; then
              TEMP_FILE=$(mktemp)
              if jq --arg plugin "${PLUGIN_NAME}@local-plugins" '.enabledPlugins[$plugin] = true' "$SETTINGS_FILE" > "$TEMP_FILE" 2>/dev/null; then
                  mv "$TEMP_FILE" "$SETTINGS_FILE" 2>/dev/null && AUTO_ENABLED=true
              fi
              [ -f "$TEMP_FILE" ] && rm -f "$TEMP_FILE" 2>/dev/null
          fi

          echo "✅ RForgeOrchestrator plugin installed successfully!"
          echo ""
          if [ "$AUTO_ENABLED" = true ]; then
              echo "Plugin auto-enabled in Claude Code."
          elif [ "$CLAUDE_RUNNING" = true ]; then
              echo "Claude Code is running - skipped auto-enable to avoid conflicts."
              echo "Run: claude plugin install rforge-orchestrator@local-plugins"
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
          echo "✅ RForgeOrchestrator plugin uninstalled"
      else
          echo "Plugin not found at $TARGET_DIR"
      fi

    EOS

    chmod "+x", bin/"rforge-orchestrator-install"
    chmod "+x", bin/"rforge-orchestrator-uninstall"
  end

  def post_install
    # Step 1: Auto-install plugin with 30s timeout
    begin
      require "timeout"
      pid = Process.spawn(bin/"rforge-orchestrator-install")
      Timeout.timeout(30) { Process.waitpid(pid) }
    rescue Timeout::Error
      begin
        Process.kill("TERM", pid)
      rescue
        nil
      end
      begin
        Process.waitpid(pid)
      rescue
        nil
      end
      opoo "rforge-orchestrator-install timed out after 30 seconds (skipping)"
    rescue
      nil
    end

    # Step 2: Sync Claude Code plugin registry (optional)
    begin
      system "claude", "plugin", "update", "rforge-orchestrator@local-plugins" if which("claude")
    rescue
      nil
    end
  end

  def post_uninstall
    system bin/"rforge-orchestrator-uninstall" if (bin/"rforge-orchestrator-uninstall").exist?
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
        https://github.com/Data-Wise/claude-plugins
    EOS
  end

  test do
    assert_path_exists libexec/".claude-plugin/plugin.json"
    assert_predicate libexec/"commands", :directory?
    assert_predicate libexec/"agents", :directory?
  end
end
