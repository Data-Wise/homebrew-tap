    echo "⚠️  Automatic install failed (could not copy plugin files)."
    echo ""
    echo "Copy the plugin into place manually to complete installation:"
    echo ""
    echo "  mkdir -p $TARGET_DIR && ( cd $SOURCE_DIR && tar cf - . ) | ( cd $TARGET_DIR && tar xf - )"
    echo ""
    exit 0  # Don't fail the brew install
