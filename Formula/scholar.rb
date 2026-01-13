class Scholar < Formula
  desc "Academic workflows for research and teaching - Claude Code plugin"
  homepage "https://github.com/Data-Wise/scholar"
  url "https://github.com/Data-Wise/scholar/archive/refs/tags/v2.0.0.tar.gz"
  sha256 "157edc9c8ff1126d36ec6d87b486dedac02c35d7574df6f3eec8009fdb3a6225"
  license "MIT"

  def install
    # Install plugin to libexec (Homebrew-managed location)
    # Include hidden files like .claude-plugin
    libexec.install Dir["*", ".*"].reject { |f| %w[. .. .git].include?(f) }

    # Create wrapper script that symlinks to ~/.claude/plugins/
    (bin/"scholar-install").write <<~EOS
      #!/bin/bash
      # Note: Not using set -e to handle permission errors gracefully

      PLUGIN_NAME="scholar"
      TARGET_DIR="$HOME/.claude/plugins/$PLUGIN_NAME"
      SOURCE_DIR="#{libexec}"

      echo "Installing Scholar plugin to Claude Code..."

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
          echo "✅ Scholar plugin installed successfully!"
          echo ""
          echo "21 commands available (14 research + 7 teaching):"
          echo ""
          echo "Literature Management:"
          echo "  /arxiv <query>        - Search arXiv for papers"
          echo "  /doi <doi>            - Look up paper by DOI"
          echo "  /bib:search <query>   - Search BibTeX files"
          echo "  /bib:add <file>       - Add BibTeX entries"
          echo ""
          echo "Teaching:"
          echo "  /teach:syllabus       - Generate course syllabus"
          echo "  /teach:homework       - Create homework assignment"
          echo "  /teach:rubric         - Generate grading rubric"
          echo "  /teach:quiz           - Generate quiz questions"
          echo "  /teach:exam           - Create comprehensive exam"
          echo "  /teach:feedback       - Generate student feedback"
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

    (bin/"scholar-uninstall").write <<~EOS
      #!/bin/bash
      set -e

      PLUGIN_NAME="scholar"
      TARGET_DIR="$HOME/.claude/plugins/$PLUGIN_NAME"

      if [ -L "$TARGET_DIR" ] || [ -d "$TARGET_DIR" ]; then
          rm -rf "$TARGET_DIR"
          echo "✅ Scholar plugin uninstalled"
      else
          echo "Plugin not found at $TARGET_DIR"
      fi
    EOS

    chmod "+x", bin/"scholar-install"
    chmod "+x", bin/"scholar-uninstall"
  end

  def post_install
    # Auto-install plugin after brew install
    system bin/"scholar-install"
  end

  def post_uninstall
    # Auto-uninstall plugin after brew uninstall
    system bin/"scholar-uninstall" if (bin/"scholar-uninstall").exist?
  end

  def caveats
    <<~EOS
      The Scholar plugin has been installed to:
        ~/.claude/plugins/scholar

      21 commands available for academic workflows:
        - 14 research commands (literature, manuscript, simulation)
        - 7 teaching commands (syllabus, assignments, exams, feedback)

      Try: /arxiv "your research topic"

      If symlink failed (macOS permissions), run manually:
        ln -sf #{libexec} ~/.claude/plugins/scholar

      For more information:
        https://github.com/Data-Wise/scholar
    EOS
  end

  test do
    assert_path_exists libexec/".claude-plugin/plugin.json"
    assert_path_exists libexec/"src/plugin-api/commands"
    assert_path_exists libexec/"src/plugin-api/skills"
  end
end
