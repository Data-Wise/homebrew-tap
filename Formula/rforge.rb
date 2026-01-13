class Rforge < Formula
  desc "R package ecosystem orchestrator - 15 commands - Claude Code plugin"
  homepage "https://github.com/Data-Wise/rforge"
  head "https://github.com/Data-Wise/rforge.git", branch: "main"
  license "MIT"

  depends_on "jq" => :optional

  def install
    # Install plugin to libexec (Homebrew-managed location)
    # Include hidden files like .claude-plugin
    libexec.install Dir["*", ".*"].reject { |f| f == "." || f == ".." || f == ".git" }

    # Create wrapper script that symlinks to ~/.claude/plugins/
    # Use stable /opt/homebrew/opt path (survives upgrades) instead of versioned Cellar path
    (bin/"rforge-install").write <<~EOS
      #!/bin/bash
      # Note: Not using set -e to handle permission errors gracefully

      PLUGIN_NAME="rforge"
      TARGET_DIR="$HOME/.claude/plugins/$PLUGIN_NAME"
      # Use stable opt path - Homebrew maintains this symlink across upgrades
      SOURCE_DIR="$(brew --prefix)/opt/rforge/libexec"

      echo "Installing RForge plugin to Claude Code..."

      # Create plugins directory if it doesn't exist
      mkdir -p "$HOME/.claude/plugins" 2>/dev/null || true

      # Remove existing installation (handle macOS extended attributes)
      if [ -L "$TARGET_DIR" ] || [ -d "$TARGET_DIR" ]; then
          rm -rf "$TARGET_DIR" 2>/dev/null || rm -f "$TARGET_DIR" 2>/dev/null || true
      fi

      # Create symlink to Homebrew-managed files
      # Try multiple approaches for macOS compatibility
      LINK_SUCCESS=false

      if ln -sf "$SOURCE_DIR" "$TARGET_DIR" 2>/dev/null; then
          LINK_SUCCESS=true
      elif rm -f "$TARGET_DIR" 2>/dev/null && ln -s "$SOURCE_DIR" "$TARGET_DIR" 2>/dev/null; then
          LINK_SUCCESS=true
      elif ln -sfh "$SOURCE_DIR" "$TARGET_DIR" 2>/dev/null; then
          LINK_SUCCESS=true
      fi

      if [ "$LINK_SUCCESS" = true ]; then
          echo "✅ RForge plugin installed successfully!"
          echo ""
          echo "15 commands for R package ecosystem management:"
          echo ""
          echo "Core Commands:"
          echo "  /rforge:analyze      - Analyze R project structure"
          echo "  /rforge:status       - Get ecosystem status"
          echo "  /rforge:detect       - Auto-detect project type"
          echo "  /rforge:cascade      - Plan coordinated updates"
          echo "  /rforge:deps         - Build dependency graph"
          echo ""
          echo "Modes: default, debug, optimize, release"
          echo "Formats: terminal, json, markdown"
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
    # Auto-install plugin after brew install
    system bin/"rforge-install"
  end

  def post_uninstall
    # Auto-uninstall plugin after brew uninstall
    system bin/"rforge-uninstall" if (bin/"rforge-uninstall").exist?
  end

  test do
    assert_predicate libexec/".claude-plugin/plugin.json", :exist?
    assert_predicate libexec/"commands", :directory?
    assert_predicate libexec/"agents", :directory?
  end

  def caveats
    <<~EOS
      The RForge plugin has been installed to:
        ~/.claude/plugins/rforge

      Requirements:
        - Claude Code CLI must be installed
        - RForge MCP server must be configured in ~/.claude/settings.json
          (npm install -g rforge-mcp)

      15 commands for R package ecosystem management:
        - Auto-detect single package vs ecosystem
        - Dependency analysis and cascade planning
        - Mode system: default, debug, optimize, release
        - Format options: terminal, json, markdown

      Try: /rforge:status

      If symlink failed (macOS permissions), run manually:
        ln -sf $(brew --prefix)/opt/rforge/libexec ~/.claude/plugins/rforge

      For more information:
        https://github.com/Data-Wise/rforge
    EOS
  end
end
