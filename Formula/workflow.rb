# typed: false
# frozen_string_literal: true

# Workflow formula for the data-wise/tap Homebrew tap.
class Workflow < Formula
  desc "ADHD-friendly workflow automation with auto-delegation - Claude Code plugin"
  homepage "https://github.com/Data-Wise/claude-plugins"
  url "https://github.com/Data-Wise/claude-plugins/releases/download/workflow-v0.1.0/workflow-v0.1.0.tar.gz"
  sha256 "cf155a7ad9855d5c5f4180847b3c62dbda6c99b410485b681b7148f270338783"
  license "MIT"

  depends_on "jq"

  def install
    bin.mkpath

    libexec.install Dir["*", ".*"].reject { |f| %w[. .. .git].include?(f) }

    (bin/"workflow-install").write <<~EOS
      #!/bin/bash
      # NOTE: Not using set -e to handle permission errors gracefully

      PLUGIN_NAME="workflow"
      TARGET_DIR="$HOME/.claude/plugins/$PLUGIN_NAME"
      # Copy from the stable opt path — Homebrew repoints opt/<name> across upgrades,
      # and post_install re-runs this installer to refresh the real copy.
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

          # Register plugin in Claude Code if not already installed
          if [ "$CLAUDE_RUNNING" = false ] && command -v claude &>/dev/null; then
              if ! claude plugin list 2>/dev/null | grep -q "workflow@local-plugins"; then
                  claude plugin install "workflow@local-plugins" 2>/dev/null || true
              fi
          fi

          echo ""
          if [ "$AUTO_ENABLED" = true ]; then
              echo "Plugin auto-enabled in Claude Code."
          elif [ "$CLAUDE_RUNNING" = true ]; then
              echo "Claude Code is running - skipped auto-enable to avoid conflicts."
              echo "After restarting Claude Code, the workflow plugin will be available."
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

  def post_install
    # Step 1: Auto-install plugin with 30s timeout
    begin
      require "timeout"
      pid = Process.spawn(bin/"workflow-install")
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
      opoo "workflow-install timed out after 30 seconds (skipping)"
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
          system "claude", "plugin", "install", "workflow@local-plugins"
        else
          opoo "marketplace sync didn't settle in time - run: " \
               "claude plugin marketplace update local-plugins && " \
               "claude plugin update workflow@local-plugins"
        end
      else
        opoo "claude not on PATH - run: claude plugin install workflow@local-plugins to finish"
      end
    rescue
      nil
    end

    # Prune old cached plugin versions (keep newest 3)
    begin
      cache = Pathname.new("#{Dir.home}/.claude/plugins/cache/local-plugins/workflow")
      cache.children.select(&:directory?).sort_by(&:mtime).reverse.drop(3).each(&:rmtree) if cache.directory?
    rescue
      nil
    end

    # Warn if the installed copy's version drifts from this formula
    begin
      require "json"
      installed = Pathname.new("#{Dir.home}/.claude/plugins/workflow/.claude-plugin/plugin.json")
      if installed.file?
        iv = JSON.parse(installed.read)["version"]
        opoo "installed workflow v#{iv} != formula v#{version}" if iv && iv.to_s != version.to_s
      end
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

      If the automatic copy failed (macOS permissions), run manually:
        mkdir -p ~/.claude/plugins/workflow && ( cd $(brew --prefix)/opt/workflow/libexec && tar cf - . ) | ( cd ~/.claude/plugins/workflow && tar xf - )

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
