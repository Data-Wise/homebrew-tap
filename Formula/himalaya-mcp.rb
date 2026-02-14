class HimalayaMcp < Formula
  desc "Privacy-first email MCP server and Claude Code plugin wrapping himalaya CLI"
  homepage "https://github.com/Data-Wise/himalaya-mcp"
  url "https://github.com/Data-Wise/himalaya-mcp/archive/refs/tags/v1.1.0.tar.gz"
  sha256 "PLACEHOLDER_SHA256_REPLACE_AFTER_RELEASE"
  license "MIT"

  depends_on "himalaya"
  depends_on "node"
  depends_on "jq" => :optional

  def install
    # Build the project: install all deps (including devDependencies for tsc), then bundle
    system "npm", "install", "--production=false"
    system "npm", "run", "build:bundle"

    # Install only the essential directories to libexec (no node_modules)
    libexec.install ".claude-plugin"
    libexec.install ".mcp.json"
    libexec.install "plugin"
    libexec.install "dist"

    # Create wrapper script that symlinks to ~/.claude/plugins/
    # Use stable /opt/homebrew/opt path (survives upgrades) instead of versioned Cellar path
    (bin/"himalaya-mcp-install").write <<~EOS
      #!/bin/bash
      # Note: Not using set -e to handle permission errors gracefully

      PLUGIN_NAME="himalaya-mcp"
      TARGET_DIR="$HOME/.claude/plugins/$PLUGIN_NAME"
      # Use stable opt path - Homebrew maintains this symlink across upgrades
      SOURCE_DIR="$(brew --prefix)/opt/himalaya-mcp/libexec"

      # Strip unrecognized keys from plugin.json (Claude Code rejects them)
      PLUGIN_JSON="$SOURCE_DIR/.claude-plugin/plugin.json"
      if grep -q 'claude_md_budget' "$PLUGIN_JSON" 2>/dev/null; then
          python3 -c "import json,sys;p=sys.argv[1];d=json.load(open(p));c={k:v for k,v in d.items() if k in('name','version','description','author')};f=open(p,'w');json.dump(c,f,indent=2);f.write(chr(10));f.close()" "$PLUGIN_JSON" 2>/dev/null || true
      fi

      echo "Installing himalaya-mcp plugin to Claude Code..."

      # Create plugins directory if it doesn't exist
      mkdir -p "$HOME/.claude/plugins" 2>/dev/null || true

      # Remove existing installation (handle macOS extended attributes)
      if [ -L "$TARGET_DIR" ] || [ -d "$TARGET_DIR" ]; then
          rm -rf "$TARGET_DIR" 2>/dev/null || rm -f "$TARGET_DIR" 2>/dev/null || true
      fi

      # Create symlink to Homebrew-managed files
      # Try multiple approaches for macOS compatibility
      LINK_SUCCESS=false

      # Method 1: Standard symlink
      if ln -sf "$SOURCE_DIR" "$TARGET_DIR" 2>/dev/null; then
          LINK_SUCCESS=true
      # Method 2: Remove and recreate (handles some edge cases)
      elif rm -f "$TARGET_DIR" 2>/dev/null && ln -s "$SOURCE_DIR" "$TARGET_DIR" 2>/dev/null; then
          LINK_SUCCESS=true
      # Method 3: Use ln -sfh (macOS specific, replaces symlink atomically)
      elif ln -sfh "$SOURCE_DIR" "$TARGET_DIR" 2>/dev/null; then
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

          # Check if Claude Code has settings.json open
          if command -v lsof &>/dev/null; then
              if lsof "$SETTINGS_FILE" 2>/dev/null | grep -q "claude"; then
                  CLAUDE_RUNNING=true
              fi
          elif pgrep -x "claude" >/dev/null 2>&1; then
              # Fallback: check if claude process is running
              CLAUDE_RUNNING=true
          fi

          if [ "$CLAUDE_RUNNING" = false ] && command -v jq &>/dev/null && [ -f "$SETTINGS_FILE" ]; then
              TEMP_FILE=$(mktemp)
              if jq --arg plugin "${PLUGIN_NAME}@local-plugins" '.enabledPlugins[$plugin] = true' "$SETTINGS_FILE" > "$TEMP_FILE" 2>/dev/null; then
                  mv "$TEMP_FILE" "$SETTINGS_FILE" 2>/dev/null && AUTO_ENABLED=true
              fi
              [ -f "$TEMP_FILE" ] && rm -f "$TEMP_FILE" 2>/dev/null
          fi

          echo "✅ himalaya-mcp plugin installed successfully!"
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
          echo "4 email skills available:"
          echo "  /email:inbox   - List and browse inbox"
          echo "  /email:triage  - Classify emails (actionable/FYI/skip)"
          echo "  /email:digest  - Daily email digest"
          echo "  /email:reply   - Draft and send replies"
          echo ""
          echo "After upgrades, sync with: claude plugin update himalaya-mcp@local-plugins"
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

      # Remove from marketplace.json manifest
      MARKETPLACE_DIR="$HOME/.claude/local-marketplace"
      MANIFEST_FILE="$MARKETPLACE_DIR/.claude-plugin/marketplace.json"
      if command -v jq &>/dev/null && [ -f "$MANIFEST_FILE" ]; then
          TEMP_FILE=$(mktemp)
          if jq --arg name "$PLUGIN_NAME" '.plugins = [.plugins[]? | select(.name != $name)]' "$MANIFEST_FILE" > "$TEMP_FILE" 2>/dev/null; then
              mv "$TEMP_FILE" "$MANIFEST_FILE" 2>/dev/null
          fi
          [ -f "$TEMP_FILE" ] && rm -f "$TEMP_FILE" 2>/dev/null
      fi

      # Remove marketplace symlink
      rm -f "$MARKETPLACE_DIR/$PLUGIN_NAME" 2>/dev/null || true

      # Remove plugin symlink
      if [ -L "$TARGET_DIR" ] || [ -d "$TARGET_DIR" ]; then
          rm -rf "$TARGET_DIR"
          echo "✅ himalaya-mcp plugin uninstalled"
      else
          echo "Plugin not found at $TARGET_DIR"
      fi
    EOS

    chmod "+x", bin/"himalaya-mcp-install"
    chmod "+x", bin/"himalaya-mcp-uninstall"
  end

  def post_install
    # Step 1: Strip keys not recognized by Claude Code's strict plugin.json schema
    begin
      require "json"
      plugin_json = libexec/".claude-plugin/plugin.json"
      if plugin_json.exist?
        allowed_keys = %w[name version description author]
        data = JSON.parse(plugin_json.read)
        cleaned = data.select { |k, _| allowed_keys.include?(k) }
        if cleaned.size < data.size
          plugin_json.write(JSON.pretty_generate(cleaned) + "\n")
        end
      end
    rescue
      # Non-fatal: plugin may still work if key issue is fixed in source
      nil
    end

    # Step 2: Auto-install plugin (always runs regardless of step 1)
    system bin/"himalaya-mcp-install"

    # Step 3: Sync Claude Code plugin registry (optional)
    begin
      system "claude", "plugin", "update", "himalaya-mcp@local-plugins" if which("claude")
    rescue
      # Don't fail if claude CLI not available or update fails
      nil
    end
  end

  def post_uninstall
    # Auto-uninstall plugin after brew uninstall
    system bin/"himalaya-mcp-uninstall" if (bin/"himalaya-mcp-uninstall").exist?
  end

  test do
    assert_predicate libexec/".claude-plugin/plugin.json", :exist?
    assert_predicate libexec/"dist/index.js", :exist?
    assert_predicate libexec/"plugin/skills", :directory?
  end

  def caveats
    <<~EOS
      The himalaya-mcp plugin has been installed to:
        ~/.claude/plugins/himalaya-mcp

      If not auto-enabled, run:
        claude plugin install himalaya-mcp@local-plugins

      4 email skills for Claude Code:
        /email:inbox   - List and browse inbox
        /email:triage  - Classify emails (actionable/FYI/skip)
        /email:digest  - Daily email digest
        /email:reply   - Draft and send replies

      11 MCP tools for email operations:
        list_emails, search_emails, read_email, read_email_html,
        flag_email, move_email, draft_reply, send_email,
        export_to_markdown, create_action_item, copy_to_clipboard

      For Claude Desktop setup (future):
        himalaya-mcp setup

      After upgrades, sync Claude Code registry:
        claude plugin update himalaya-mcp@local-plugins

      If symlink failed (macOS permissions), run manually:
        ln -sf $(brew --prefix)/opt/himalaya-mcp/libexec ~/.claude/plugins/himalaya-mcp

      Requires himalaya CLI configured with at least one account.
      See: https://github.com/Data-Wise/himalaya-mcp
    EOS
  end
end
