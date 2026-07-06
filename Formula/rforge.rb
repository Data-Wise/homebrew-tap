# typed: false
# frozen_string_literal: true

# Rforge formula for the data-wise/tap Homebrew tap.
class Rforge < Formula
  desc "R package ecosystem orchestrator — 41 commands — Claude Code plugin"
  homepage "https://github.com/Data-Wise/rforge"
  url "https://github.com/Data-Wise/rforge/archive/refs/tags/v2.18.0.tar.gz"
  sha256 "7683de54d5aaa15f03490236ac5817f4c0f04e4858fd9dc8e7ca05cc53a6ffe2"
  license "MIT"
  head "https://github.com/Data-Wise/rforge.git", branch: "main"

  depends_on "jq"

  def install
    libexec.install Dir["*", ".*"].reject { |f| %w[. .. .git].include?(f) }

    (bin/"rforge-install").write <<~EOS
      #!/bin/bash
      # NOTE: Not using set -e to handle permission errors gracefully

      PLUGIN_NAME="rforge"
      TARGET_DIR="$HOME/.claude/plugins/$PLUGIN_NAME"
      # Copy from the stable opt path — Homebrew repoints opt/<name> across upgrades,
      # and post_install re-runs this installer to refresh the real copy.
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
          PLUGIN_DESC="R package ecosystem orchestrator - analyze, test, release, cascade changes"
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

          echo "✅ RForge plugin installed successfully!"

          # Register plugin in Claude Code if not already installed
          if [ "$CLAUDE_RUNNING" = false ] && command -v claude &>/dev/null; then
              if ! claude plugin list 2>/dev/null | grep -q "rforge@local-plugins"; then
                  claude plugin install "rforge@local-plugins" 2>/dev/null || true
              fi
          fi

          echo ""
          if [ "$AUTO_ENABLED" = true ]; then
              echo "Plugin auto-enabled in Claude Code."
          elif [ "$CLAUDE_RUNNING" = true ]; then
              echo "Claude Code is running - skipped auto-enable to avoid conflicts."
              echo "After restarting Claude Code, the rforge plugin will be available."
          fi

          echo ""
          echo "15 commands available:"
          echo "  /rforge:analyze, /rforge:status, /rforge:deps, /rforge:cascade"
          echo "  /rforge:release, /rforge:impact, /rforge:next, /rforge:complete"
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

  def post_install
    # Step 1: Auto-install plugin with 30s timeout
    begin
      require "timeout"
      pid = Process.spawn(bin/"rforge-install")
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
      opoo "rforge-install timed out after 30 seconds (skipping)"
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
          system "claude", "plugin", "install", "rforge@local-plugins"
        else
          opoo "marketplace sync didn't settle in time - run: " \
               "claude plugin marketplace update local-plugins && " \
               "claude plugin update rforge@local-plugins"
        end
      else
        opoo "claude not on PATH - run: claude plugin install rforge@local-plugins to finish"
      end
    rescue
      nil
    end

    # Prune old cached plugin versions (keep newest 3)
    begin
      cache = Pathname.new("#{Dir.home}/.claude/plugins/cache/local-plugins/rforge")
      cache.children.select(&:directory?).sort_by(&:mtime).reverse.drop(3).each(&:rmtree) if cache.directory?
    rescue
      nil
    end

    # Warn if the installed copy's version drifts from this formula
    begin
      require "json"
      installed = Pathname.new("#{Dir.home}/.claude/plugins/rforge/.claude-plugin/plugin.json")
      if installed.file?
        iv = JSON.parse(installed.read)["version"]
        opoo "installed rforge v#{iv} != formula v#{version}" if iv && iv.to_s != version.to_s
      end
    rescue
      nil
    end
  end

  def post_uninstall
    system bin/"rforge-uninstall" if (bin/"rforge-uninstall").exist?
  end

  def caveats
    <<~EOS
      The RForge plugin has been installed to:
        ~/.claude/plugins/rforge

      If not auto-enabled, run:
        claude plugin install rforge@local-plugins

      35 commands for R package ecosystem management.

      If the automatic copy failed (macOS permissions), run manually:
        mkdir -p ~/.claude/plugins/rforge && ( cd $(brew --prefix)/opt/rforge/libexec && tar cf - . ) | ( cd ~/.claude/plugins/rforge && tar xf - )

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
