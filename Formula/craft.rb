# typed: false
# frozen_string_literal: true

# Craft formula for the data-wise/tap Homebrew tap.
class Craft < Formula
  desc "Full-stack developer toolkit for Claude Code with 115 commands"
  homepage "https://github.com/Data-Wise/craft"
  url "https://github.com/Data-Wise/craft/archive/refs/tags/v2.60.0.tar.gz"
  sha256 "ccca5b9a500fda36054fda540a20b1ebc4267411650c20956271ca9b579049fe"
  license "MIT"

  depends_on "jq"

  def install
    libexec.install Dir["*", ".*"].reject { |f| %w[. .. .git].include?(f) }

    (bin/"craft-install").write <<~EOS
      #!/bin/bash
      # NOTE: Not using set -e to handle permission errors gracefully

      PLUGIN_NAME="craft"
      TARGET_DIR="$HOME/.claude/plugins/$PLUGIN_NAME"
      # Copy from the stable opt path — Homebrew repoints opt/<name> across upgrades,
      # and post_install re-runs this installer to refresh the real copy.
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
          echo "115 commands available:"
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

    # Step 2: Auto-install plugin with 30s timeout
    begin
      require "timeout"
      pid = Process.spawn(bin/"craft-install")
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
      opoo "craft-install timed out after 30 seconds (skipping)"
    rescue
      nil
    end

    # Step 3: Sync Claude Code plugin registry (optional)
    begin
      if which("claude")
        synced = false
        2.times do |attempt|
          synced = system("claude", "plugin", "marketplace", "update", "local-plugins")
          break if synced

          sleep 1 if attempt.zero?
        end
        if synced
          system "claude", "plugin", "update", "craft@local-plugins"
        else
          opoo "marketplace sync didn't settle in time - run: " \
               "claude plugin marketplace update local-plugins && " \
               "claude plugin update craft@local-plugins"
        end
      else
        opoo "claude not on PATH - run: claude plugin install craft@local-plugins to finish"
      end
    rescue
      nil
    end

    # Prune old cached plugin versions (keep newest 3)
    begin
      cache = Pathname.new("#{Dir.home}/.claude/plugins/cache/local-plugins/craft")
      cache.children.select(&:directory?).sort_by(&:mtime).reverse.drop(3).each(&:rmtree) if cache.directory?
    rescue
      nil
    end

    # Warn if the installed copy's version drifts from this formula
    begin
      require "json"
      installed = Pathname.new("#{Dir.home}/.claude/plugins/craft/.claude-plugin/plugin.json")
      if installed.file?
        iv = JSON.parse(installed.read)["version"]
        opoo "installed craft v#{iv} != formula v#{version}" if iv && iv.to_s != version.to_s
      end
    rescue
      nil
    end
  end

  def post_uninstall
    system bin/"craft-uninstall" if (bin/"craft-uninstall").exist?
  end

  def caveats
    <<~EOS
      115 commands for full-stack development:
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

      If the automatic copy failed (macOS permissions), run manually:
        mkdir -p ~/.claude/plugins/craft && ( cd $(brew --prefix)/opt/craft/libexec && tar cf - . ) | ( cd ~/.claude/plugins/craft && tar xf - )

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
