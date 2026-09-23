# typed: false
# frozen_string_literal: true

# RforgeOrchestrator formula for the data-wise/tap Homebrew tap.
#
# DEPRECATED 2026-05-10: This formula was the original packaging of
# rforge when it lived inside the claude-plugins monorepo. The plugin
# was extracted to its own repo (Data-Wise/rforge) and renamed to
# `rforge`. New users should install:
#
#     brew install --HEAD data-wise/tap/rforge
#
# This formula is kept for the deprecation grace period; it will be
# upgraded to `disable!` in a future release, and removed thereafter.
class RforgeOrchestrator < Formula
  desc "Auto-delegation orchestrator for RForge MCP tools - Claude Code plugin"
  homepage "https://github.com/Data-Wise/rforge"
  url "https://github.com/Data-Wise/claude-plugins/archive/refs/tags/rforge-orchestrator-v0.1.0.tar.gz"
  sha256 "8c065681864b18c9bea41996aa33bec17b95697ed8330846c8b510bd81bbad2e"
  license "MIT"
  revision 2

  deprecate! date: "2026-05-10", because: "renamed; use `brew install --HEAD data-wise/tap/rforge`"

  depends_on "jq"

  def install
    bin.mkpath

    libexec.install Dir["rforge-orchestrator/*"]

    (bin/"rforge-orchestrator-install").write <<~EOS
      #!/bin/bash
      # NOTE: Not using set -e to handle permission errors gracefully

      PLUGIN_NAME="rforge-orchestrator"
      # Claude Code plugin id and the marketplace it is installed from (manifest
      # `claude_plugin`; `<name>@local-plugins` when the plugin is in no marketplace).
      PLUGIN_REF="rforge-orchestrator@local-plugins"
      MARKETPLACE="local-plugins"
      TARGET_DIR="$HOME/.claude/plugins/$PLUGIN_NAME"
      # Copy from the stable opt path — Homebrew repoints opt/<name> across upgrades.
      # Run by the user (Homebrew's sandboxed post_install cannot reach ~/.claude).
      SOURCE_DIR="$(brew --prefix)/opt/rforge-orchestrator/libexec"

      echo "Installing RForgeOrchestrator plugin to Claude Code..."

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
          # Mirror into local-marketplace for plugin discovery — a REAL copy, not a
          # symlink (also migrates a legacy symlink here). Costs ~2x disk per plugin;
          # accepted tradeoff for the no-symlinks install policy.
          MARKETPLACE_DIR="$HOME/.claude/local-marketplace"
          mkdir -p "$MARKETPLACE_DIR" 2>/dev/null || true
          if [ -d "$TARGET_DIR" ]; then
              rm -rf "$MARKETPLACE_DIR/$PLUGIN_NAME" 2>/dev/null || rm -f "$MARKETPLACE_DIR/$PLUGIN_NAME" 2>/dev/null || true
              mkdir -p "$MARKETPLACE_DIR/$PLUGIN_NAME" 2>/dev/null || true
              ( cd "$TARGET_DIR" && tar cf - . ) 2>/dev/null | ( cd "$MARKETPLACE_DIR/$PLUGIN_NAME" && tar xf - ) 2>/dev/null || true
          fi

          # Add to marketplace.json manifest (required for 'claude plugin install' discovery)
          MANIFEST_FILE="$MARKETPLACE_DIR/.claude-plugin/marketplace.json"
          # Create the local-plugins manifest if this is the first plugin mirrored here;
          # without it the directory is not a marketplace and `marketplace add` rejects it.
          if [ ! -f "$MANIFEST_FILE" ]; then
              mkdir -p "$MARKETPLACE_DIR/.claude-plugin" 2>/dev/null || true
              echo '{"name": "local-plugins", "owner": {"name": "data-wise/tap"}, "plugins": []}' > "$MANIFEST_FILE" 2>/dev/null || true
          fi
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
              if jq --arg plugin "$PLUGIN_REF" '.enabledPlugins[$plugin] = true' "$SETTINGS_FILE" > "$TEMP_FILE" 2>/dev/null; then
                  mv "$TEMP_FILE" "$SETTINGS_FILE" 2>/dev/null && AUTO_ENABLED=true
              fi
              [ -f "$TEMP_FILE" ] && rm -f "$TEMP_FILE" 2>/dev/null
          fi

          echo "✅ RForgeOrchestrator plugin files copied to $TARGET_DIR"

          # Register with Claude Code through the marketplace it actually loads the
          # plugin from. CLI registration is safe while Claude Code is running (the
          # CLAUDE_RUNNING guard above only protects the direct settings.json edit).
          REGISTERED=false
          if command -v claude &>/dev/null; then
              # Register ~/.claude/local-marketplace as "local-plugins" on first use
              if ! claude plugin marketplace list 2>/dev/null | grep -qF "local-plugins"; then
                  claude plugin marketplace add "$HOME/.claude/local-marketplace" >/dev/null 2>&1 || true
              fi
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

          echo ""
          echo "Commands: /rforge:analyze, /rforge:quick, /rforge:thorough"
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

  def post_uninstall
    system bin/"rforge-orchestrator-uninstall" if (bin/"rforge-orchestrator-uninstall").exist?
  end

  def caveats
    <<~EOS
      ⚠️  DEPRECATED — This formula is no longer maintained.

      The plugin has been renamed to `rforge` and now lives in its own
      repository. Migrate with:

          brew uninstall data-wise/tap/rforge-orchestrator
          rm -rf ~/.claude/plugins/rforge-orchestrator
          brew install --HEAD data-wise/tap/rforge

      The new formula installs to ~/.claude/plugins/rforge and ships
      v1.2.0 features (R-aware PreToolUse hook, marketplace install,
      validation skills, 15 commands).

      ──────────────────────────────────────────────────────

      Legacy install info (for users on this deprecated formula):

      The RForge Orchestrator plugin has been installed to:
        ~/.claude/plugins/rforge-orchestrator

      If not auto-enabled, run:
        claude plugin install rforge-orchestrator@local-plugins

      Requirements:
        - Claude Code CLI must be installed
        - RForge MCP server must be configured in ~/.claude/settings.json

      Available commands (v0.1.0 had only these three):
        /rforge:analyze  - Analyze R project and recommend tools
        /rforge:quick    - Quick project analysis
        /rforge:thorough - Thorough multi-stage analysis

      If the automatic copy failed (macOS permissions), run manually:
        mkdir -p ~/.claude/plugins/rforge-orchestrator && ( cd $(brew --prefix)/opt/rforge-orchestrator/libexec && tar cf - . ) | ( cd ~/.claude/plugins/rforge-orchestrator && tar xf - )

      For the new plugin and full v1.2.0 docs:
        https://github.com/Data-Wise/rforge
    EOS
  end

  test do
    assert_path_exists libexec/".claude-plugin/plugin.json"
    assert_path_exists bin/"rforge-orchestrator-install"
    assert_predicate libexec/"commands", :directory?
    assert_predicate libexec/"agents", :directory?
  end
end
