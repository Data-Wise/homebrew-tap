#!/bin/bash
set -e

PLUGIN_NAME="{plugin_name}"
TARGET_DIR="$HOME/.claude/plugins/$PLUGIN_NAME"

if [ -L "$TARGET_DIR" ] || [ -d "$TARGET_DIR" ]; then
    rm -rf "$TARGET_DIR"
    echo "✅ {display_name} plugin uninstalled"
else
    echo "Plugin not found at $TARGET_DIR"
fi
