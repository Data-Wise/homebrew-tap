class Scholar < Formula
  desc "Academic workflows for research and teaching - Claude Code plugin"
  homepage "https://github.com/Data-Wise/scholar"
  url "https://github.com/Data-Wise/scholar/archive/refs/tags/v2.0.0.tar.gz"
  sha256 "157edc9c8ff1126d36ec6d87b486dedac02c35d7574df6f3eec8009fdb3a6225"
  license "MIT"

  depends_on "jq" => :optional

  def install
    # Install plugin to libexec (Homebrew-managed location)
    # Include hidden files like .claude-plugin
    libexec.install Dir["*", ".*"].reject { |f| %w[. .. .git].include?(f) }

    # Create wrapper script that symlinks to ~/.claude/plugins/
    # Use stable /opt/homebrew/opt path (survives upgrades) instead of versioned Cellar path
    (bin/"scholar-install").write <<~EOS
      #!/bin/bash
      # Note: Not using set -e to handle permission errors gracefully

      PLUGIN_NAME="scholar"
      TARGET_DIR="$HOME/.claude/plugins/$PLUGIN_NAME"
      # Use stable opt path - Homebrew maintains this symlink across upgrades
      SOURCE_DIR="$(brew --prefix)/opt/scholar/libexec"

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
          # Also create symlink in local-marketplace for plugin discovery
          MARKETPLACE_DIR="$HOME/.claude/local-marketplace"
          mkdir -p "$MARKETPLACE_DIR" 2>/dev/null || true
          ln -sfh "$TARGET_DIR" "$MARKETPLACE_DIR/$PLUGIN_NAME" 2>/dev/null || true

          # Add to marketplace.json manifest (required for 'claude plugin install' discovery)
          MANIFEST_FILE="$MARKETPLACE_DIR/.claude-plugin/marketplace.json"
          PLUGIN_DESC="Academic workflows for research and teaching - literature, manuscript, simulation, and course materials"
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
          SETTINGS_FILE="$HOME/.claude/settings.json"
          AUTO_ENABLED=false
          if command -v jq &>/dev/null && [ -f "$SETTINGS_FILE" ]; then
              TEMP_FILE=$(mktemp)
              if jq --arg plugin "${PLUGIN_NAME}@local-plugins" '.enabledPlugins[$plugin] = true' "$SETTINGS_FILE" > "$TEMP_FILE" 2>/dev/null; then
                  mv "$TEMP_FILE" "$SETTINGS_FILE"
                  AUTO_ENABLED=true
              else
                  rm -f "$TEMP_FILE" 2>/dev/null
              fi
          fi

          echo "✅ Scholar plugin installed successfully!"
          echo ""
          if [ "$AUTO_ENABLED" = true ]; then
              echo "Plugin auto-enabled in Claude Code."
          else
              echo "To enable, run: claude plugin install scholar@local-plugins"
          fi
          echo ""
          echo "21 commands available (14 research + 7 teaching):"
          echo "  /arxiv, /doi, /bib:search, /bib:add"
          echo "  /teach:exam, /teach:quiz, /teach:syllabus, /teach:homework"
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

      If not auto-enabled, run:
        claude plugin install scholar@local-plugins

      21 commands available for academic workflows:
        - 14 research commands (literature, manuscript, simulation)
        - 7 teaching commands (syllabus, assignments, exams, feedback)

      Try: /arxiv "your research topic"

      If symlink failed (macOS permissions), run manually:
        ln -sf $(brew --prefix)/opt/scholar/libexec ~/.claude/plugins/scholar

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
