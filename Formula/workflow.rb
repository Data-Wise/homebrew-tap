# typed: false
# frozen_string_literal: true

# Workflow formula for the data-wise/tap Homebrew tap.
class Workflow < Formula
  desc "ADHD-friendly workflow automation with auto-delegation - Claude Code plugin"
  homepage "https://github.com/Data-Wise/claude-plugins"
  url "https://github.com/Data-Wise/claude-plugins/releases/download/workflow-v0.1.0/workflow-v0.1.0.tar.gz"
  sha256 "cf155a7ad9855d5c5f4180847b3c62dbda6c99b410485b681b7148f270338783"
  license "MIT"
  revision 2

  depends_on "jq"

  def install
    bin.mkpath

    libexec.install Dir["*", ".*"].reject { |f| %w[. .. .git].include?(f) }

    (bin/"workflow-install").write <<~EOS
      #!/bin/bash
      # NOTE: Not using set -e to handle permission errors gracefully

      PLUGIN_NAME="workflow"
      # Claude Code plugin id and the marketplace it is installed from (manifest
      # `claude_plugin`; `<name>@local-plugins` when the plugin is in no marketplace).
      PLUGIN_REF="workflow@local-plugins"
      MARKETPLACE="local-plugins"
      TARGET_DIR="$HOME/.claude/plugins/$PLUGIN_NAME"
      # Copy from the stable opt path — Homebrew repoints opt/<name> across upgrades.
      # Run by the user (Homebrew's sandboxed post_install cannot reach ~/.claude).
      SOURCE_DIR="$(brew --prefix)/opt/workflow/libexec"

      echo "Installing Workflow plugin to Claude Code..."

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
              if jq --arg plugin "$PLUGIN_REF" '.enabledPlugins[$plugin] = true' "$SETTINGS_FILE" > "$TEMP_FILE" 2>/dev/null; then
                  mv "$TEMP_FILE" "$SETTINGS_FILE" 2>/dev/null && AUTO_ENABLED=true
              fi
              [ -f "$TEMP_FILE" ] && rm -f "$TEMP_FILE" 2>/dev/null
          fi

          echo "✅ Workflow plugin files copied to $TARGET_DIR"

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
          echo "Skills: backend-designer, frontend-designer, devops-helper"
          echo "Commands: /brainstorm, /workflow:spec-review"
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

    (bin/"workflow-uninstall").write <<~EOS
      #!/bin/bash
      set -e

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

  def post_uninstall
    system bin/"workflow-uninstall" if (bin/"workflow-uninstall").exist?
  end

  def caveats
    <<~EOS
      The plugin includes:
        - 3 auto-activating skills (backend, frontend, devops)
        - Enhanced /brainstorm command (8 modes)
        - Workflow orchestrator agent
        - 60+ proven design patterns

      Claude Code setup (Homebrew's sandbox can't write to ~/.claude, so run these yourself):
        workflow-install
      Then restart Claude Code.

      For more information:
        https://github.com/Data-Wise/claude-plugins
    EOS
  end

  test do
    assert_path_exists libexec/".claude-plugin/plugin.json"
    assert_path_exists bin/"workflow-install"
    assert_path_exists libexec/"commands/brainstorm.md"
    assert_path_exists libexec/"skills/design/backend-designer.md"
    assert_path_exists libexec/"agents/orchestrator.md"
  end
end
