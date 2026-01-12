class Scholar < Formula
  desc "Academic workflows for research and teaching - Claude Code plugin"
  homepage "https://github.com/Data-Wise/scholar"
  url "https://github.com/Data-Wise/scholar/archive/refs/tags/v2.0.0-alpha.1.tar.gz"
  sha256 "97c187211b4f464f7516ed85fbaad3ae34fcb8f1d515d712062eb72391e72796"
  version "2.0.0-alpha.1"
  license "MIT"

  def install
    # Install plugin to libexec (Homebrew-managed location)
    # Include hidden files like .claude-plugin
    libexec.install Dir["*", ".*"].reject { |f| f == "." || f == ".." || f == ".git" }

    # Create wrapper script that symlinks to ~/.claude/plugins/
    (bin/"scholar-install").write <<~EOS
      #!/bin/bash
      set -e

      PLUGIN_NAME="scholar"
      TARGET_DIR="$HOME/.claude/plugins/$PLUGIN_NAME"
      SOURCE_DIR="#{libexec}"

      echo "Installing Scholar plugin to Claude Code..."

      # Create plugins directory if it doesn't exist
      mkdir -p "$HOME/.claude/plugins"
      chmod 755 "$HOME/.claude/plugins"

      # Remove existing installation
      if [ -L "$TARGET_DIR" ]; then
          rm -f "$TARGET_DIR"
      elif [ -d "$TARGET_DIR" ]; then
          rm -rf "$TARGET_DIR"
      fi

      # Create symlink to Homebrew-managed files
      ln -sf "$SOURCE_DIR" "$TARGET_DIR" || {
          echo "Failed to create symlink. Trying alternative approach..."
          ln -sfh "$SOURCE_DIR" "$TARGET_DIR"
      }

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
      echo "  /teaching:syllabus    - Generate course syllabus"
      echo "  /teaching:assignment  - Create homework assignment"
      echo "  /teaching:rubric      - Generate grading rubric"
      echo "  /teaching:slides      - Create lecture slides"
      echo "  /teaching:quiz        - Generate quiz questions"
      echo "  /teaching:exam        - Create comprehensive exam"
      echo "  /teaching:feedback    - Generate student feedback"
      echo ""
      echo "To uninstall: brew uninstall scholar"
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

  test do
    assert_predicate libexec/".claude-plugin/plugin.json", :exist?
    assert_predicate libexec/"src/plugin-api/commands", :directory?
    assert_predicate libexec/"src/plugin-api/skills", :directory?
  end

  def caveats
    <<~EOS
      The Scholar plugin has been installed to:
        ~/.claude/plugins/scholar

      21 commands available for academic workflows:
        - 14 research commands (literature, manuscript, simulation)
        - 7 teaching commands (syllabus, assignments, exams, feedback)

      Try: /arxiv "your research topic"

      For more information:
        https://github.com/Data-Wise/scholar
    EOS
  end
end
