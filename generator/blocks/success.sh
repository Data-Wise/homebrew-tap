    echo "✅ {display_name} plugin files copied to $TARGET_DIR"

    # Register with Claude Code through the marketplace it actually loads the
    # plugin from. CLI registration is safe while Claude Code is running (the
    # CLAUDE_RUNNING guard above only protects the direct settings.json edit).
    REGISTERED=false
    if command -v claude &>/dev/null; then
{register_marketplace}
        claude plugin marketplace update "$MARKETPLACE" >/dev/null 2>&1 || true
        if claude plugin list 2>/dev/null | grep -qF "$PLUGIN_REF"; then
            claude plugin update "$PLUGIN_REF" >/dev/null 2>&1 && REGISTERED=true
        else
            claude plugin install "$PLUGIN_REF" >/dev/null 2>&1 && REGISTERED=true
        fi
    fi

    echo ""
    if [ "$REGISTERED" = true ]; then
        echo "Registered $PLUGIN_REF with Claude Code. Restart Claude Code to load it."
    else
        echo "Could not register $PLUGIN_REF automatically. Run:"
        echo "  claude plugin marketplace update $MARKETPLACE"
        echo "  claude plugin install $PLUGIN_REF"
    fi
{hook_message}
    echo ""
{summary_lines}
