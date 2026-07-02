#!/bin/bash
# NOTE: Not using set -e to handle permission errors gracefully

PLUGIN_NAME="{plugin_name}"
TARGET_DIR="$HOME/.claude/plugins/$PLUGIN_NAME"
# Copy from the stable opt path — Homebrew repoints opt/<name> across upgrades,
# and post_install re-runs this installer to refresh the real copy.
SOURCE_DIR="$(brew --prefix)/opt/{formula_name}/libexec"
