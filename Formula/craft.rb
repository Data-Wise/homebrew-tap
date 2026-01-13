class Craft < Formula
  desc "Full-stack developer toolkit - 86 commands, 8 agents, 21 skills - Claude Code plugin"
  homepage "https://github.com/Data-Wise/craft"
  url "https://github.com/Data-Wise/craft/archive/refs/tags/v1.17.0.tar.gz"
  sha256 "ae6781155dbfc16d07a83d0d0626fba1286a7edfcfac6077d6a2efb08a6f3be5"
  license "MIT"

  def install
    # Install plugin to libexec (Homebrew-managed location)
    # Include hidden files like .claude-plugin
    libexec.install Dir["*", ".*"].reject { |f| f == "." || f == ".." || f == ".git" }

    # Create wrapper script that symlinks to ~/.claude/plugins/
    (bin/"craft-install").write <<~EOS
      #!/bin/bash
      # Note: Not using set -e to handle permission errors gracefully

      PLUGIN_NAME="craft"
      TARGET_DIR="$HOME/.claude/plugins/$PLUGIN_NAME"
      SOURCE_DIR="#{libexec}"

      echo "Installing Craft plugin to Claude Code..."

      # Create plugins directory if it doesn't exist
      mkdir -p "$HOME/.claude/plugins" 2>/dev/null || true

      # Remove existing installation (handle macOS extended attributes)
      if [ -L "$TARGET_DIR" ] || [ -d "$TARGET_DIR" ]; then
          rm -rf "$TARGET_DIR" 2>/dev/null || rm -f "$TARGET_DIR" 2>/dev/null || true
      fi

      # Create symlink to Homebrew-managed files
      # Try multiple approaches for macOS compatibility
      LINK_SUCCESS=false

      # Method 1: Standard symlink
      if ln -sf "$SOURCE_DIR" "$TARGET_DIR" 2>/dev/null; then
          LINK_SUCCESS=true
      # Method 2: Remove and recreate (handles some edge cases)
      elif rm -f "$TARGET_DIR" 2>/dev/null && ln -s "$SOURCE_DIR" "$TARGET_DIR" 2>/dev/null; then
          LINK_SUCCESS=true
      # Method 3: Use ln -sfh (macOS specific, replaces symlink atomically)
      elif ln -sfh "$SOURCE_DIR" "$TARGET_DIR" 2>/dev/null; then
          LINK_SUCCESS=true
      fi

      if [ "$LINK_SUCCESS" = true ]; then
          echo "✅ Craft plugin installed successfully!"
          echo ""
          echo "86 commands available (74 craft + 12 workflow):"
          echo ""
          echo "Quick Commands:"
          echo "  /craft:do <task>      - Universal task router"
          echo "  /craft:orchestrate    - Launch orchestrator mode"
          echo "  /brainstorm           - ADHD-friendly brainstorming"
          echo "  /craft:check          - Pre-flight validation"
          echo ""
          echo "Categories: arch, ci, code, dist, docs, git, plan, site, test, workflow"
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
    # Auto-install plugin after brew install
    system bin/"craft-install"
  end

  def post_uninstall
    # Auto-uninstall plugin after brew uninstall
    system bin/"craft-uninstall" if (bin/"craft-uninstall").exist?
  end

  test do
    assert_predicate libexec/".claude-plugin/plugin.json", :exist?
    assert_predicate libexec/"commands", :directory?
    assert_predicate libexec/"skills", :directory?
    assert_predicate libexec/"agents", :directory?
    assert_match "1.17.0", shell_output("cat #{libexec}/.claude-plugin/plugin.json")
  end

  def caveats
    <<~EOS
      The Craft plugin has been installed to:
        ~/.claude/plugins/craft

      86 commands for full-stack development:
        - Architecture & planning
        - Code generation & refactoring
        - Testing & CI/CD
        - Documentation & site generation
        - Git workflows
        - ADHD-friendly task management

      Try: /craft:do "your task"
      Or:  /brainstorm

      If symlink failed (macOS permissions), run manually:
        ln -sf #{libexec} ~/.claude/plugins/craft

      For more information:
        https://github.com/Data-Wise/craft
    EOS
  end
end
