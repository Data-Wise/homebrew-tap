# typed: false
# frozen_string_literal: true

# HimalayaMcp formula for the data-wise/tap Homebrew tap.
class HimalayaMcp < Formula
  desc "Privacy-first email MCP server and Claude Code plugin wrapping himalaya CLI"
  homepage "https://github.com/Data-Wise/himalaya-mcp"
  url "https://github.com/Data-Wise/himalaya-mcp/archive/refs/tags/v1.2.1.tar.gz"
  sha256 "3a4c9fb936a3f3e6da67f925f4eeb766b24315a1e0741ea932a959e126d92692"
  license "MIT"

  depends_on "himalaya"
  depends_on "node"
  depends_on "jq" => :optional

  def install
    system "npm", "install", *std_npm_args(prefix: false)
    system "npm", "run", "build:bundle"

    libexec.install ".claude-plugin"
    libexec.install ".mcp.json"
    libexec.install "plugin"
    libexec.install "dist"

    (bin/"himalaya-mcp-install").write <<~EOS
      #!/bin/bash
      # NOTE: Not using set -e to handle permission errors gracefully

      PLUGIN_NAME="himalaya-mcp"
      TARGET_DIR="$HOME/.claude/plugins/$PLUGIN_NAME"
      # Use stable opt path — Homebrew maintains this symlink across upgrades
      SOURCE_DIR="$(brew --prefix)/opt/himalaya-mcp/libexec"

      # Strip unrecognized keys from plugin.json (Claude Code rejects them)
      PLUGIN_JSON="$SOURCE_DIR/.claude-plugin/plugin.json"
      if grep -q 'claude_md_budget' "$PLUGIN_JSON" 2>/dev/null; then
          python3 -c "import json,sys;p=sys.argv[1];d=json.load(open(p));c={k:v for k,v in d.items() if k in('name','version','description','author')};f=open(p,'w');json.dump(c,f,indent=2);f.write(chr(10));f.close()" "$PLUGIN_JSON" 2>/dev/null || true
      fi

      echo "Installing Himalaya MCP plugin to Claude Code..."

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
          PLUGIN_DESC="Privacy-first email MCP server and Claude Code plugin wrapping himalaya CLI"
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

          echo "✅ Himalaya MCP plugin installed successfully!"
          echo ""
          if [ "$AUTO_ENABLED" = true ]; then
              echo "Plugin auto-enabled in Claude Code."
          elif [ "$CLAUDE_RUNNING" = true ]; then
              echo "Claude Code is running - skipped auto-enable to avoid conflicts."
              echo "Run: claude plugin install himalaya-mcp@local-plugins"
          else
              echo "To enable, run: claude plugin install himalaya-mcp@local-plugins"
          fi

          echo ""
          echo "7 email skills available:"
          echo "  /email:inbox       - List and browse inbox"
          echo "  /email:triage      - Classify emails (actionable/FYI/skip)"
          echo "  /email:digest      - Daily email digest"
          echo "  /email:reply       - Draft and send replies"
          echo "  /email:compose     - Compose new emails"
          echo "  /email:attachments - Manage attachments"
          echo "  /email:help        - Help hub for all commands"
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

    (bin/"himalaya-mcp-uninstall").write <<~EOS
      #!/bin/bash
      set -e

      PLUGIN_NAME="himalaya-mcp"
      TARGET_DIR="$HOME/.claude/plugins/$PLUGIN_NAME"

      if [ -L "$TARGET_DIR" ] || [ -d "$TARGET_DIR" ]; then
          rm -rf "$TARGET_DIR"
          echo "✅ Himalaya MCP plugin uninstalled"
      else
          echo "Plugin not found at $TARGET_DIR"
      fi

    EOS

    chmod "+x", bin/"himalaya-mcp-install"
    chmod "+x", bin/"himalaya-mcp-uninstall"
  end

  def post_install
    # Step 1: Strip keys not recognized by Claude Code's strict plugin.json schema
    require "json"
    plugin_json = libexec/".claude-plugin/plugin.json"
    if plugin_json.exist?
      allowed_keys = %w[name version description author]
      data = JSON.parse(plugin_json.read)
      cleaned = data.slice(*allowed_keys)
      plugin_json.write("#{JSON.pretty_generate(cleaned)}\n") if cleaned.size < data.size
    end
  rescue
    nil
  end

  def post_uninstall
    system bin/"himalaya-mcp-uninstall" if (bin/"himalaya-mcp-uninstall").exist?
  end

  def caveats
    <<~EOS
      To complete installation, run:
        himalaya-mcp-install

      To uninstall the plugin:
        himalaya-mcp-uninstall

      7 email skills for Claude Code:
        /email:inbox   /email:triage   /email:digest
        /email:reply   /email:compose  /email:attachments
        /email:help

      19 MCP tools available.

      For Claude Desktop: himalaya-mcp setup

      Requires himalaya CLI with at least one configured account.
      See: https://github.com/Data-Wise/himalaya-mcp

      For more information:
        https://github.com/Data-Wise/himalaya-mcp
    EOS
  end

  test do
    assert_path_exists libexec/".claude-plugin/plugin.json"
    assert_path_exists libexec/"dist/index.js"
    assert_predicate libexec/"plugin/skills", :directory?
  end
end
