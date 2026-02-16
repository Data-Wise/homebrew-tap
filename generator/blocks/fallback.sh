    echo "⚠️  Automatic symlink failed (macOS permissions)."
    echo ""
    echo "Run this command manually to complete installation:"
    echo ""
    echo "  ln -sf $SOURCE_DIR $TARGET_DIR"
    echo ""
    exit 0  # Don't fail the brew install
