    # --- Branch Guard Hook Installation ---
    HOOK_SRC="$SOURCE_DIR/scripts/branch-guard.sh"
    HOOK_DIR="$HOME/.claude/hooks"
    HOOK_DEST="$HOOK_DIR/branch-guard.sh"
    HOOK_INSTALLED=false

    if [ -f "$HOOK_SRC" ]; then
        mkdir -p "$HOOK_DIR" 2>/dev/null || true

        # Copy hook (skip if symlink — dev setup)
        if [ -L "$HOOK_DEST" ]; then
            HOOK_INSTALLED=true
        elif [ -f "$HOOK_DEST" ]; then
            if ! diff -q "$HOOK_SRC" "$HOOK_DEST" >/dev/null 2>&1; then
                cp "$HOOK_SRC" "$HOOK_DEST" && chmod +x "$HOOK_DEST" && HOOK_INSTALLED=true
            else
                HOOK_INSTALLED=true
            fi
        else
            cp "$HOOK_SRC" "$HOOK_DEST" && chmod +x "$HOOK_DEST" && HOOK_INSTALLED=true
        fi

        # Register in settings.json (if jq available and not already registered)
        if [ "$HOOK_INSTALLED" = true ] && [ "$CLAUDE_RUNNING" = false ] && command -v jq &>/dev/null && [ -f "$SETTINGS_FILE" ]; then
            if ! jq -e '.hooks.PreToolUse // [] | map(.hooks[]?.command) | any(test("branch-guard"))' "$SETTINGS_FILE" >/dev/null 2>&1; then
                HOOK_CMD="/bin/bash $HOME/.claude/hooks/branch-guard.sh"
                TEMP_FILE=$(mktemp)
                if jq --arg cmd "$HOOK_CMD" '
                    .hooks.PreToolUse = (.hooks.PreToolUse // []) + [
                        {"matcher": "Edit|Write", "hooks": [{"type": "command", "command": $cmd, "timeout": 5000}]},
                        {"matcher": "Bash", "hooks": [{"type": "command", "command": $cmd, "timeout": 5000}]}
                    ]
                ' "$SETTINGS_FILE" > "$TEMP_FILE" 2>/dev/null; then
                    mv "$TEMP_FILE" "$SETTINGS_FILE" 2>/dev/null
                fi
                [ -f "$TEMP_FILE" ] && rm -f "$TEMP_FILE" 2>/dev/null
            fi
        fi
    fi
