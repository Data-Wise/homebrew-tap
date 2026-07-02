echo "Installing {display_name} plugin to Claude Code..."

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
