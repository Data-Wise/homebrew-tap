# typed: false
# frozen_string_literal: true

# Craft formula for the data-wise/tap Homebrew tap.
class Craft < Formula
  desc "Full-stack developer toolkit for Claude Code with 48 commands"
  homepage "https://github.com/Data-Wise/craft"
  url "https://github.com/Data-Wise/craft/archive/refs/tags/v4.6.1.tar.gz"
  sha256 "24b034f3771e0fc9b7766e35f3208140274c0edc84f115346bdf0db37b4ff05d"
  license "MIT"
  revision 3

  depends_on "jq"

  def install
    libexec.install Dir["*", ".*"].reject { |f| %w[. .. .git].include?(f) }

    (bin/"craft-install").write <<~EOS
      #!/bin/bash
      # NOTE: Not using set -e to handle permission errors gracefully

      PLUGIN_NAME="craft"
      # Claude Code plugin id and the marketplace it is installed from (manifest
      # `claude_plugin`; `<name>@local-plugins` when the plugin is in no marketplace).
      PLUGIN_REF="craft@data-wise"
      MARKETPLACE="data-wise"
      TARGET_DIR="$HOME/.claude/plugins/$PLUGIN_NAME"
      # Copy from the stable opt path — Homebrew repoints opt/<name> across upgrades.
      # Run by the user (Homebrew's sandboxed post_install cannot reach ~/.claude).
      SOURCE_DIR="$(brew --prefix)/opt/craft/libexec"

      # Strip unrecognized keys from plugin.json (Claude Code rejects them)
      PLUGIN_JSON="$SOURCE_DIR/.claude-plugin/plugin.json"
      if grep -q 'claude_md_budget' "$PLUGIN_JSON" 2>/dev/null; then
          python3 -c "import json,sys;p=sys.argv[1];d=json.load(open(p));c={k:v for k,v in d.items() if k in('name','version','description','author')};f=open(p,'w');json.dump(c,f,indent=2);f.write(chr(10));f.close()" "$PLUGIN_JSON" 2>/dev/null || true
      fi

      echo "Installing Craft plugin to Claude Code..."

      # Create plugins directory if it doesn't exist
      mkdir -p "$HOME/.claude/plugins" 2>/dev/null || true

      # Remove any existing installation. NOTE: older versions installed a SYMLINK
      # here — we now install a REAL copy, so this also MIGRATES legacy symlink
      # installs to a real directory.
      if [ -L "$TARGET_DIR" ] || [ -d "$TARGET_DIR" ]; then
          rm -rf "$TARGET_DIR" 2>/dev/null || rm -f "$TARGET_DIR" 2>/dev/null || true
      fi

      # Install a REAL copy of the Homebrew-managed files (never a symlink).
      # Use a tar pipe rather than `cp -R`: tar copies symlinks AS symlinks, so the
      # intentionally-broken governance test fixtures don't abort the copy on macOS
      # BSD cp. LINK_SUCCESS gates the success/fallback branches below.
      LINK_SUCCESS=false
      if [ -d "$SOURCE_DIR" ] && mkdir -p "$TARGET_DIR" 2>/dev/null; then
          if ( cd "$SOURCE_DIR" && tar cf - . ) 2>/dev/null | ( cd "$TARGET_DIR" && tar xf - ) 2>/dev/null; then
              # Verify the copy actually landed before declaring success
              if [ -f "$TARGET_DIR/.claude-plugin/plugin.json" ]; then
                  LINK_SUCCESS=true
              fi
          fi
          [ "$LINK_SUCCESS" = true ] || rm -rf "$TARGET_DIR" 2>/dev/null || true
      fi

      if [ "$LINK_SUCCESS" = true ]; then

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
              if jq --arg plugin "$PLUGIN_REF" '.enabledPlugins[$plugin] = true' "$SETTINGS_FILE" > "$TEMP_FILE" 2>/dev/null; then
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

          echo "✅ Craft plugin files copied to $TARGET_DIR"

          # Register with Claude Code through the marketplace it actually loads the
          # plugin from. CLI registration is safe while Claude Code is running (the
          # CLAUDE_RUNNING guard above only protects the direct settings.json edit).
          REGISTERED=false
          if command -v claude &>/dev/null; then

              claude plugin marketplace update "$MARKETPLACE" >/dev/null 2>&1 || true
              if claude plugin list 2>/dev/null | grep -qF "$PLUGIN_REF"; then
                  claude plugin update "$PLUGIN_REF" >/dev/null 2>&1 && REGISTERED=true
              else
                  claude plugin install "$PLUGIN_REF" >/dev/null 2>&1 && REGISTERED=true
              fi
          fi

          echo ""
          if [ "$REGISTERED" = true ]; then
              echo "Registered $PLUGIN_REF with Claude Code. Restart Claude Code to load it."
          else
              echo "Could not register $PLUGIN_REF automatically. Run:"
              echo "  claude plugin marketplace update $MARKETPLACE"
              echo "  claude plugin install $PLUGIN_REF"
          fi
          if [ "$HOOK_INSTALLED" = true ]; then
              echo "Branch guard hook installed (protects main/dev branches)."
          fi
          echo ""
          echo "48 commands available:"
          echo "  /craft:do, /craft:orchestrate, /brainstorm, /craft:check"
          echo "  Categories: arch, ci, code, dist, docs, git, plan, site, test, workflow"
      else
          echo "⚠️  Automatic install failed (could not copy plugin files)."
          echo ""
          echo "Copy the plugin into place manually to complete installation:"
          echo ""
          echo "  mkdir -p $TARGET_DIR && ( cd $SOURCE_DIR && tar cf - . ) | ( cd $TARGET_DIR && tar xf - )"
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
    # Strip keys not recognized by Claude Code's strict plugin.json schema
    require "json"
    plugin_json = libexec/".claude-plugin/plugin.json"
    return unless plugin_json.exist?

    allowed_keys = %w[name version description author]
    data = JSON.parse(plugin_json.read)
    cleaned = data.slice(*allowed_keys)
    plugin_json.write("#{JSON.pretty_generate(cleaned)}\n") if cleaned.size < data.size
  rescue
    nil
  end

  def post_uninstall
    system bin/"craft-uninstall" if (bin/"craft-uninstall").exist?
  end

  def caveats
    <<~EOS
      48 commands for full-stack development:
        - Architecture & planning
        - Code generation & refactoring
        - Testing & CI/CD
        - Documentation & site generation
        - Git workflows & branch protection
        - ADHD-friendly task management

      Branch guard protects main/dev from accidental edits.
      Bypass: ask "unprotect dev" or "bypass branch guard" (session-scoped)

      Try: /craft:do "your task"
      Or:  /brainstorm

      Claude Code setup (Homebrew's sandbox can't write to ~/.claude, so run these yourself):
        claude plugin marketplace update data-wise
        claude plugin install craft@data-wise   # first install
        claude plugin update craft@data-wise    # after upgrades
      Then restart Claude Code.

      For more information:
        https://github.com/Data-Wise/craft
    EOS
  end

  test do
    assert_path_exists libexec/".claude-plugin/plugin.json"
    assert_predicate libexec/"commands", :directory?
    assert_predicate libexec/"skills", :directory?
    assert_predicate libexec/"agents", :directory?
  end
end
