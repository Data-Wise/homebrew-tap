echo "Installing {display_name} plugin to Claude Code..."

# Create plugins directory if it doesn't exist
mkdir -p "$HOME/.claude/plugins" 2>/dev/null || true

# Remove existing installation (handle macOS extended attributes)
if [ -L "$TARGET_DIR" ] || [ -d "$TARGET_DIR" ]; then
    rm -rf "$TARGET_DIR" 2>/dev/null || rm -f "$TARGET_DIR" 2>/dev/null || true
fi

# Create symlink to Homebrew-managed files
# Try multiple approaches for macOS compatibility
LINK_SUCCESS=false

# Method 1: ln -sfh (macOS, replaces symlink atomically, prevents circular symlinks)
if ln -sfh "$SOURCE_DIR" "$TARGET_DIR" 2>/dev/null; then
    LINK_SUCCESS=true
# Method 2: Standard symlink
elif ln -sf "$SOURCE_DIR" "$TARGET_DIR" 2>/dev/null; then
    LINK_SUCCESS=true
# Method 3: Remove and recreate
elif rm -f "$TARGET_DIR" 2>/dev/null && ln -s "$SOURCE_DIR" "$TARGET_DIR" 2>/dev/null; then
    LINK_SUCCESS=true
fi
