# typed: false
# frozen_string_literal: true

# Craft formula for the data-wise/tap Homebrew tap.
class Craft < Formula
  desc "Full-stack developer toolkit for Claude Code with 111 commands"
  homepage "https://github.com/Data-Wise/craft"
  url "https://github.com/Data-Wise/craft/archive/refs/tags/v2.21.0.tar.gz"
  sha256 "46532a5e91e8b0e47a0bffcfc24429fc7a2a45be836f34b550efd8134fc33dee"
  license "MIT"

  depends_on "jq" => :optional

  def install
    libexec.install Dir["*", ".*"].reject { |f| %w[. .. .git].include?(f) }

    (bin/"craft-install").write <<~EOS
      #!/bin/bash
      # NOTE: Not using set -e to handle permission errors gracefully

      PLUGIN_NAME="craft"
      TARGET_DIR="$HOME/.claude/plugins/$PLUGIN_NAME"
      # Use stable opt path — Homebrew maintains this symlink across upgrades
      SOURCE_DIR="$(brew --prefix)/opt/craft/libexec"

      # Strip unrecognized keys from plugin.json (Claude Code rejects them)
      PLUGIN_JSON="$SOURCE_DIR/.claude-plugin/plugin.json"
      if grep -q 'claude_md_budget' "$PLUGIN_JSON" 2>/dev/null; then
          python3 -c "import json,sys;p=sys.argv[1];d=json.load(open(p));c={k:v for k,v in d.items() if k in('name','version','description','author')};f=open(p,'w');json.dump(c,f,indent=2);f.write(chr(10));f.close()" "$PLUGIN_JSON" 2>/dev/null || true
      fi

      echo "Installing Craft plugin to Claude Code..."

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
          PLUGIN_DESC="Full-stack developer toolkit - code, git, site, docs, testing, and architecture commands"
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

          # --- Branch Guard Hook Installation ---
          HOOK_SRC="$SOURCE_DIR/scripts/branch-guard.sh"
          HOOK_DIR="$HOME/.claude/hooks"
          HOOK_DEST="$HOOK_DIR/branch-guard.sh"
          HOOK_INSTALLED=false

          if [ -f "$HOOK_SRC" ]; then
              mkdir -p "$HOOK_DIR" 2>/dev/null || true

              # Copy hook (skip if symlink — dev setup)
              if [ -L "$HOOK_DEST" ]; then
                  HOOK_INSTALLED=true
              elif [ -f "$HOOK_DEST" ]; then
                  if ! diff -q "$HOOK_SRC" "$HOOK_DEST" >/dev/null 2>&1; then
                      cp "$HOOK_SRC" "$HOOK_DEST" && chmod +x "$HOOK_DEST" && HOOK_INSTALLED=true
                  else
                      HOOK_INSTALLED=true
                  fi
              else
                  cp "$HOOK_SRC" "$HOOK_DEST" && chmod +x "$HOOK_DEST" && HOOK_INSTALLED=true
              fi

              # Register in settings.json (if jq available and not already registered)
              if [ "$HOOK_INSTALLED" = true ] && [ "$CLAUDE_RUNNING" = false ] && command -v jq &>/dev/null && [ -f "$SETTINGS_FILE" ]; then
                  if ! jq -e '.hooks.PreToolUse // [] | map(.hooks[]?.command) | any(test("branch-guard"))' "$SETTINGS_FILE" >/dev/null 2>&1; then
                      HOOK_CMD="/bin/bash $HOME/.claude/hooks/branch-guard.sh"
                      TEMP_FILE=$(mktemp)
                      if jq --arg cmd "$HOOK_CMD" '
                          .hooks.PreToolUse = (.hooks.PreToolUse // []) + [
                              {"matcher": "Edit|Write", "hooks": [{"type": "command", "command": $cmd, "timeout": 5000}]},
                              {"matcher": "Bash", "hooks": [{"type": "command", "command": $cmd, "timeout": 5000}]}
                          ]
                      ' "$SETTINGS_FILE" > "$TEMP_FILE" 2>/dev/null; then
                          mv "$TEMP_FILE" "$SETTINGS_FILE" 2>/dev/null
                      fi
                      [ -f "$TEMP_FILE" ] && rm -f "$TEMP_FILE" 2>/dev/null
                  fi
              fi
          fi

          echo "✅ Craft plugin installed successfully!"
          echo ""
          if [ "$AUTO_ENABLED" = true ]; then
              echo "Plugin auto-enabled in Claude Code."
          elif [ "$CLAUDE_RUNNING" = true ]; then
              echo "Claude Code is running - skipped auto-enable to avoid conflicts."
              echo "Run: claude plugin install craft@local-plugins"
          else
              echo "To enable, run: claude plugin install craft@local-plugins"
          fi
          if [ "$HOOK_INSTALLED" = true ]; then
              echo "Branch guard hook installed (protects main/dev branches)."
          fi
          echo ""
          echo "111 commands available:"
          echo "  /craft:do, /craft:orchestrate, /brainstorm, /craft:check"
          echo "  Categories: arch, ci, code, dist, docs, git, plan, site, test, workflow"
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

    (bin/"craft-uninstall").write <<~EOS
      #!/bin/bash
      set -e

      PLUGIN_NAME="craft"
      TARGET_DIR="$HOME/.claude/plugins/$PLUGIN_NAME"

      if [ -L "$TARGET_DIR" ] || [ -d "$TARGET_DIR" ]; then
          rm -rf "$TARGET_DIR"
          echo "✅ Craft plugin uninstalled"
      else
          echo "Plugin not found at $TARGET_DIR"
      fi

    EOS

    chmod "+x", bin/"craft-install"
    chmod "+x", bin/"craft-uninstall"
  end

  def post_install
    # Step 1: Strip keys not recognized by Claude Code's strict plugin.json schema
    begin
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

    # Step 2: Auto-install plugin (always runs regardless of step 1)
    begin
      system bin/"craft-install"
    rescue
      nil
    end

    # Step 3: Sync Claude Code plugin registry (optional)
    begin
      system "claude", "plugin", "update", "craft@local-plugins" if which("claude")
    rescue
      nil
    end
  end

  def post_uninstall
    system bin/"craft-uninstall" if (bin/"craft-uninstall").exist?
  end

  def caveats
    <<~EOS
      111 commands for full-stack development:
        - Architecture & planning
        - Code generation & refactoring
        - Testing & CI/CD
        - Documentation & site generation
        - Git workflows & branch protection
        - ADHD-friendly task management

      Branch guard protects main/dev from accidental edits.
      Bypass: /craft:git:unprotect (session-scoped)

      Try: /craft:do "your task"
      Or:  /brainstorm

      After upgrades, sync Claude Code registry:
        claude plugin update craft@local-plugins

      If symlink failed (macOS permissions), run manually:
        ln -sf $(brew --prefix)/opt/craft/libexec ~/.claude/plugins/craft

      For more information:
        https://github.com/Data-Wise/craft
    EOS
  end

  test do
    assert_path_exists libexec/".claude-plugin/plugin.json"
    assert_predicate libexec/"commands", :directory?
    assert_predicate libexec/"skills", :directory?
    assert_predicate libexec/"agents", :directory?
    assert_match "2.21.0", shell_output("cat #{libexec}/.claude-plugin/plugin.json")
  end
end
