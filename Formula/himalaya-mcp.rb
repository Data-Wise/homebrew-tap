# typed: false
# frozen_string_literal: true

# HimalayaMcp formula for the data-wise/tap Homebrew tap.
class HimalayaMcp < Formula
  desc "Privacy-first email MCP server and Claude Code plugin wrapping himalaya CLI"
  homepage "https://github.com/Data-Wise/himalaya-mcp"
  url "https://github.com/Data-Wise/himalaya-mcp/archive/refs/tags/v1.7.0.tar.gz"
  sha256 "ec63631cca2ad28422a721fabf5365834ce594f6e7540b7815046bcf673f5714"
  license "MIT"

  depends_on "himalaya"
  depends_on "jq"
  depends_on "node"

  def install
    bin.mkpath

    system "npm", "install", *std_npm_args(prefix: false)
    system "npm", "run", "build"
    system "npm", "run", "build:bundle"

    mkdir_p libexec/".claude-plugin"
    cp "himalaya-mcp-plugin/.claude-plugin/plugin.json", libexec/".claude-plugin/plugin.json"
    cp_r "himalaya-mcp-plugin/.claude-plugin/hooks", libexec/".claude-plugin/hooks"
    cp ".claude-plugin/marketplace.json", libexec/".claude-plugin/marketplace.json"
    libexec.install ".mcp.json"
    libexec.install "dist"
    cp_r "himalaya-mcp-plugin/skills", libexec/"skills"
    cp_r "himalaya-mcp-plugin/agents", libexec/"agents"

    (bin/"himalaya-mcp").write <<~EOS
      #!/bin/bash
      exec node "#{libexec}/dist/cli/setup.js" "$@"
    EOS
    chmod "+x", bin/"himalaya-mcp"

    (bin/"himalaya-mcp-install").write <<~EOS
      #!/bin/bash
      # NOTE: Not using set -e to handle permission errors gracefully

      PLUGIN_NAME="himalaya-mcp"
      TARGET_DIR="$HOME/.claude/plugins/$PLUGIN_NAME"
      # Copy from the stable opt path — Homebrew repoints opt/<name> across upgrades,
      # and post_install re-runs this installer to refresh the real copy.
      SOURCE_DIR="$(brew --prefix)/opt/himalaya-mcp/libexec"

      # Strip unrecognized keys from plugin.json (Claude Code rejects them)
      PLUGIN_JSON="$SOURCE_DIR/.claude-plugin/plugin.json"
      if grep -q 'claude_md_budget' "$PLUGIN_JSON" 2>/dev/null; then
          python3 -c "import json,sys;p=sys.argv[1];d=json.load(open(p));c={k:v for k,v in d.items() if k in('name','version','description','author')};f=open(p,'w');json.dump(c,f,indent=2);f.write(chr(10));f.close()" "$PLUGIN_JSON" 2>/dev/null || true
      fi

      echo "Installing Himalaya MCP plugin to Claude Code..."

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

          echo "✅ Himalaya MCP plugin installed successfully!"
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
          echo "12 email skills available:"
          echo "  /email:inbox       - List and browse inbox"
          echo "  /email:triage      - Classify emails (actionable/FYI/skip)"
          echo "  /email:digest      - Daily email digest"
          echo "  /email:reply       - Draft and send replies"
          echo "  /email:compose     - Compose new emails"
          echo "  /email:attachments - Manage attachments"
          echo "  /email:search      - Search emails by keyword, sender, flags"
          echo "  /email:manage      - Bulk email operations"
          echo "  /email:stats       - Inbox statistics"
          echo "  /email:config      - Setup wizard"
          echo "  /email:morning     - Morning email briefing"
          echo "  /email:help        - Help hub for all commands"
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

    (bin/"himalaya-mcp-uninstall").write <<~EOS
      #!/bin/bash
      set -e

      PLUGIN_NAME="himalaya-mcp"
      TARGET_DIR="$HOME/.claude/plugins/$PLUGIN_NAME"

      if [ -L "$TARGET_DIR" ] || [ -d "$TARGET_DIR" ]; then
          rm -rf "$TARGET_DIR"
          echo "✅ Himalaya MCP plugin uninstalled"
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
        cleaned = data.slice(*allowed_keys)
        plugin_json.write("#{JSON.pretty_generate(cleaned)}\n") if cleaned.size < data.size
      end
    rescue
      nil
    end

    # Step 2: Auto-install plugin with 30s timeout
    begin
      require "timeout"
      pid = Process.spawn(bin/"himalaya-mcp-install")
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
      opoo "himalaya-mcp-install timed out after 30 seconds (skipping)"
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
          system "claude", "plugin", "update", "himalaya-mcp@local-plugins"
        else
          opoo "marketplace sync didn't settle in time - run: " \
               "claude plugin marketplace update local-plugins && " \
               "claude plugin update himalaya-mcp@local-plugins"
        end
      else
        opoo "claude not on PATH - run: claude plugin install himalaya-mcp@local-plugins to finish"
      end
    rescue
      nil
    end

    # Prune old cached plugin versions (keep newest 3)
    begin
      cache = Pathname.new("#{Dir.home}/.claude/plugins/cache/local-plugins/himalaya-mcp")
      cache.children.select(&:directory?).sort_by(&:mtime).reverse.drop(3).each(&:rmtree) if cache.directory?
    rescue
      nil
    end

    # Warn if the installed copy's version drifts from this formula
    begin
      require "json"
      installed = Pathname.new("#{Dir.home}/.claude/plugins/himalaya-mcp/.claude-plugin/plugin.json")
      if installed.file?
        iv = JSON.parse(installed.read)["version"]
        opoo "installed himalaya-mcp v#{iv} != formula v#{version}" if iv && iv.to_s != version.to_s
      end
    rescue
      nil
    end
  end

  def post_uninstall
    system bin/"himalaya-mcp-uninstall" if (bin/"himalaya-mcp-uninstall").exist?
  end

  def caveats
    <<~EOS
      12 email skills for Claude Code:
        /email:inbox   /email:triage   /email:digest
        /email:reply   /email:compose  /email:attachments
        /email:search  /email:manage   /email:stats
        /email:config  /email:morning  /email:help

      22 MCP tools available (incl. health_check for IMAP diagnostics).

      For Claude Desktop: himalaya-mcp setup

      Requires himalaya CLI with at least one configured account.
      See: https://github.com/Data-Wise/himalaya-mcp

      After upgrades, sync Claude Code registry:
        claude plugin update himalaya-mcp@local-plugins

      If the automatic copy failed (macOS permissions), run manually:
        mkdir -p ~/.claude/plugins/himalaya-mcp && ( cd $(brew --prefix)/opt/himalaya-mcp/libexec && tar cf - . ) | ( cd ~/.claude/plugins/himalaya-mcp && tar xf - )

      For more information:
        https://github.com/Data-Wise/himalaya-mcp
    EOS
  end

  test do
    assert_path_exists libexec/".claude-plugin/plugin.json"
    assert_path_exists libexec/".claude-plugin/hooks/session-start.sh"
    assert_path_exists libexec/".claude-plugin/hooks/pre-send.sh"
    assert_path_exists bin/"himalaya-mcp"
    assert_path_exists libexec/"dist/index.js"
    assert_predicate libexec/"skills", :directory?
    assert_predicate libexec/"agents", :directory?
  end
end
