    # Try to auto-enable via jq if available
    # Skip if Claude Code is running (holds file locks that can block mv)
    SETTINGS_FILE="$HOME/.claude/settings.json"
    AUTO_ENABLED=false
    CLAUDE_RUNNING=false

    if pgrep -x "claude" >/dev/null 2>&1; then
        CLAUDE_RUNNING=true
    fi

    if [ "$CLAUDE_RUNNING" = false ] && command -v jq &>/dev/null && [ -f "$SETTINGS_FILE" ]; then
        TEMP_FILE=$(mktemp)
        if jq --arg plugin "${PLUGIN_NAME}@local-plugins" '.enabledPlugins[$plugin] = true' "$SETTINGS_FILE" > "$TEMP_FILE" 2>/dev/null; then
            mv "$TEMP_FILE" "$SETTINGS_FILE" 2>/dev/null && AUTO_ENABLED=true
        fi
        [ -f "$TEMP_FILE" ] && rm -f "$TEMP_FILE" 2>/dev/null
    fi
