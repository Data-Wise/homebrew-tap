#!/bin/bash
# NOTE: Not using set -e to handle permission errors gracefully

PLUGIN_NAME="{plugin_name}"
TARGET_DIR="$HOME/.claude/plugins/$PLUGIN_NAME"
# Use stable opt path — Homebrew maintains this symlink across upgrades
SOURCE_DIR="$(brew --prefix)/opt/{formula_name}/libexec"
