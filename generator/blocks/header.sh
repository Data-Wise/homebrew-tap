#!/bin/bash
# NOTE: Not using set -e to handle permission errors gracefully

PLUGIN_NAME="{plugin_name}"
# Claude Code plugin id and the marketplace it is installed from (manifest
# `claude_plugin`; `<name>@local-plugins` when the plugin is in no marketplace).
PLUGIN_REF="{plugin_ref}"
MARKETPLACE="{marketplace}"
TARGET_DIR="$HOME/.claude/plugins/$PLUGIN_NAME"
# Copy from the stable opt path — Homebrew repoints opt/<name> across upgrades.
# Run by the user (Homebrew's sandboxed post_install cannot reach ~/.claude).
SOURCE_DIR="$(brew --prefix)/opt/{formula_name}/libexec"
