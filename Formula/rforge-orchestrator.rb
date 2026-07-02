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

  deprecate! date: "2026-05-10", because: "renamed; use `brew install --HEAD data-wise/tap/rforge`"

  depends_on "jq"

  def install
    bin.mkpath

    libexec.install Dir["rforge-orchestrator/*"]

    (bin/"rforge-orchestrator-install").write <<~EOS
      #!/bin/bash
      # NOTE: Not using set -e to handle permission errors gracefully

      PLUGIN_NAME="rforge-orchestrator"
      TARGET_DIR="$HOME/.claude/plugins/$PLUGIN_NAME"
      # Copy from the stable opt path — Homebrew repoints opt/<name> across upgrades,
      # and post_install re-runs this installer to refresh the real copy.
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
      if which("claude")
        synced = false
        2.times do |attempt|
          synced = system("claude", "plugin", "marketplace", "update", "local-plugins")
          break if synced

          sleep 1 if attempt.zero?
        end
        if synced
          system "claude", "plugin", "update", "rforge-orchestrator@local-plugins"
        else
          opoo "marketplace sync didn't settle in time - run: " \
               "claude plugin marketplace update local-plugins && " \
               "claude plugin update rforge-orchestrator@local-plugins"
        end
      else
        opoo "claude not on PATH - run: claude plugin install rforge-orchestrator@local-plugins to finish"
      end
    rescue
      nil
    end

    # Prune old cached plugin versions (keep newest 3)
    begin
      cache = Pathname.new("#{Dir.home}/.claude/plugins/cache/local-plugins/rforge-orchestrator")
      cache.children.select(&:directory?).sort_by(&:mtime).reverse.drop(3).each(&:rmtree) if cache.directory?
    rescue
      nil
    end

    # Warn if the installed copy's version drifts from this formula
    begin
      require "json"
      installed = Pathname.new("#{Dir.home}/.claude/plugins/rforge-orchestrator/.claude-plugin/plugin.json")
      if installed.file?
        iv = JSON.parse(installed.read)["version"]
        opoo "installed rforge-orchestrator v#{iv} != formula v#{version}" if iv && iv.to_s != version.to_s
      end
    rescue
      nil
    end
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
