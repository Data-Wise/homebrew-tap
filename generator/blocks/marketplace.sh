    # Also create symlink in local-marketplace for plugin discovery
    MARKETPLACE_DIR="$HOME/.claude/local-marketplace"
    mkdir -p "$MARKETPLACE_DIR" 2>/dev/null || true
    ln -sfh "$TARGET_DIR" "$MARKETPLACE_DIR/$PLUGIN_NAME" 2>/dev/null || true

    # Add to marketplace.json manifest (required for 'claude plugin install' discovery)
    MANIFEST_FILE="$MARKETPLACE_DIR/.claude-plugin/marketplace.json"
    PLUGIN_DESC="{install_script_desc}"
    if command -v jq &>/dev/null && [ -f "$MANIFEST_FILE" ]; then
        # Check if plugin already exists in manifest
        if ! jq -e --arg name "$PLUGIN_NAME" '.plugins[] | select(.name == $name)' "$MANIFEST_FILE" >/dev/null 2>&1; then
            TEMP_FILE=$(mktemp)
            if jq --arg name "$PLUGIN_NAME" --arg desc "$PLUGIN_DESC" \
                '.plugins = [{"name": $name, "source": ("./"+$name), "description": $desc}] + .plugins' \
                "$MANIFEST_FILE" > "$TEMP_FILE" 2>/dev/null; then
                mv "$TEMP_FILE" "$MANIFEST_FILE"
            else
                rm -f "$TEMP_FILE" 2>/dev/null
            fi
        fi
    fi
