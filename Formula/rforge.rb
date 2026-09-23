# typed: false
# frozen_string_literal: true

# Rforge formula for the data-wise/tap Homebrew tap.
class Rforge < Formula
  desc "R package ecosystem orchestrator — 44 commands — Claude Code plugin"
  homepage "https://github.com/Data-Wise/rforge"
  url "https://github.com/Data-Wise/rforge/archive/refs/tags/v2.20.1.tar.gz"
  sha256 "99877e0349c9200b5907835885bfe1eb833a4be0f9e8f18f0fc343cc6f8b4ed4"
  license "MIT"
  revision 2
  head "https://github.com/Data-Wise/rforge.git", branch: "main"

  depends_on "jq"

  def install
    libexec.install Dir["*", ".*"].reject { |f| %w[. .. .git].include?(f) }

    (bin/"rforge-install").write <<~EOS
      #!/bin/bash
      # NOTE: Not using set -e to handle permission errors gracefully

      PLUGIN_NAME="rforge"
      # Claude Code plugin id and the marketplace it is installed from (manifest
      # `claude_plugin`; `<name>@local-plugins` when the plugin is in no marketplace).
      PLUGIN_REF="rforge@data-wise"
      MARKETPLACE="data-wise"
      TARGET_DIR="$HOME/.claude/plugins/$PLUGIN_NAME"
      # Copy from the stable opt path — Homebrew repoints opt/<name> across upgrades.
      # Run by the user (Homebrew's sandboxed post_install cannot reach ~/.claude).
      SOURCE_DIR="$(brew --prefix)/opt/rforge/libexec"

      echo "Installing RForge plugin to Claude Code..."

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

          echo "✅ RForge plugin files copied to $TARGET_DIR"

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

          echo ""
          echo "44 commands available:"
          echo "  /rforge:analyze, /rforge:status, /rforge:health, /rforge:r:check"
          echo "  /rforge:release, /rforge:next, /rforge:cascade, /rforge:r:test"
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

    (bin/"rforge-uninstall").write <<~EOS
      #!/bin/bash
      set -e

      PLUGIN_NAME="rforge"
      TARGET_DIR="$HOME/.claude/plugins/$PLUGIN_NAME"

      if [ -L "$TARGET_DIR" ] || [ -d "$TARGET_DIR" ]; then
          rm -rf "$TARGET_DIR"
          echo "✅ RForge plugin uninstalled"
      else
          echo "Plugin not found at $TARGET_DIR"
      fi

    EOS

    chmod "+x", bin/"rforge-install"
    chmod "+x", bin/"rforge-uninstall"
  end

  def post_uninstall
    system bin/"rforge-uninstall" if (bin/"rforge-uninstall").exist?
  end

  def caveats
    <<~EOS
      44 commands for R package ecosystem management.

      Claude Code setup (Homebrew's sandbox can't write to ~/.claude, so run these yourself):
        claude plugin marketplace update data-wise
        claude plugin install rforge@data-wise   # first install
        claude plugin update rforge@data-wise    # after upgrades
      Then restart Claude Code.

      For more information:
        https://github.com/Data-Wise/rforge
    EOS
  end

  test do
    assert_path_exists libexec/".claude-plugin/plugin.json"
    assert_predicate libexec/"commands", :directory?
    assert_predicate libexec/"lib", :directory?
  end
end
