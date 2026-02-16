# typed: false
# frozen_string_literal: true

# Workflow formula for the data-wise/tap Homebrew tap.
class Workflow < Formula
  desc "ADHD-friendly workflow automation with auto-delegation - Claude Code plugin"
  homepage "https://github.com/Data-Wise/claude-plugins"
  url "https://github.com/Data-Wise/claude-plugins/releases/download/workflow-v0.1.0/workflow-v0.1.0.tar.gz"
  sha256 "cf155a7ad9855d5c5f4180847b3c62dbda6c99b410485b681b7148f270338783"
  license "MIT"

  depends_on "jq" => :optional

  def install
    libexec.install Dir["*", ".*"].reject { |f| %w[. .. .git].include?(f) }

    (bin/"workflow-install").write <<~EOS
      #!/bin/bash
      # NOTE: Not using set -e to handle permission errors gracefully

      PLUGIN_NAME="workflow"
      TARGET_DIR="$HOME/.claude/plugins/$PLUGIN_NAME"
      # Use stable opt path — Homebrew maintains this symlink across upgrades
      SOURCE_DIR="$(brew --prefix)/opt/workflow/libexec"

      echo "Installing Workflow plugin to Claude Code..."

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
          PLUGIN_DESC="ADHD-friendly workflow automation - brainstorm, orchestrate, and design"
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

          echo "✅ Workflow plugin installed successfully!"
          echo ""
          if [ "$AUTO_ENABLED" = true ]; then
              echo "Plugin auto-enabled in Claude Code."
          elif [ "$CLAUDE_RUNNING" = true ]; then
              echo "Claude Code is running - skipped auto-enable to avoid conflicts."
              echo "Run: claude plugin install workflow@local-plugins"
          else
              echo "To enable, run: claude plugin install workflow@local-plugins"
          fi

          echo ""
          echo "Skills: backend-designer, frontend-designer, devops-helper"
          echo "Commands: /brainstorm, /workflow:spec-review"
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

    (bin/"workflow-uninstall").write <<~EOS
      #!/bin/bash
      # NOTE: Not using set -e to handle permission errors gracefully

      PLUGIN_NAME="workflow"
      TARGET_DIR="$HOME/.claude/plugins/$PLUGIN_NAME"

      if [ -L "$TARGET_DIR" ] || [ -d "$TARGET_DIR" ]; then
          rm -rf "$TARGET_DIR"
          echo "✅ Workflow plugin uninstalled"
      else
          echo "Plugin not found at $TARGET_DIR"
      fi

    EOS

    chmod "+x", bin/"workflow-install"
    chmod "+x", bin/"workflow-uninstall"
  end

  def post_install
    begin
      system bin/"workflow-install"
    rescue
      nil
    end

    begin
      system "claude", "plugin", "update", "workflow@local-plugins" if which("claude")
    rescue
      nil
    end
  end

  def post_uninstall
    system bin/"workflow-uninstall" if (bin/"workflow-uninstall").exist?
  end

  def caveats
    <<~EOS
      The Workflow plugin has been installed to:
        ~/.claude/plugins/workflow

      If not auto-enabled, run:
        claude plugin install workflow@local-plugins

      The plugin includes:
        - 3 auto-activating skills (backend, frontend, devops)
        - Enhanced /brainstorm command (8 modes)
        - Workflow orchestrator agent
        - 60+ proven design patterns

      If symlink failed (macOS permissions), run manually:
        ln -sf $(brew --prefix)/opt/workflow/libexec ~/.claude/plugins/workflow

      For more information:
        https://github.com/Data-Wise/claude-plugins
    EOS
  end

  test do
    assert_path_exists libexec/".claude-plugin/plugin.json"
    assert_path_exists libexec/"commands/brainstorm.md"
    assert_path_exists libexec/"skills/design/backend-designer.md"
    assert_path_exists libexec/"agents/orchestrator.md"
  end
end
