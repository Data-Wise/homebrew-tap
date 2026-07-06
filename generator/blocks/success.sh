    echo "✅ {display_name} plugin installed successfully!"

    # Register plugin in Claude Code if not already installed
    if [ "$CLAUDE_RUNNING" = false ] && command -v claude &>/dev/null; then
        if ! claude plugin list 2>/dev/null | grep -q "{plugin_name}@local-plugins"; then
            claude plugin install "{plugin_name}@local-plugins" 2>/dev/null || true
        fi
    fi

    echo ""
    if [ "$AUTO_ENABLED" = true ]; then
        echo "Plugin auto-enabled in Claude Code."
    elif [ "$CLAUDE_RUNNING" = true ]; then
        echo "Claude Code is running - skipped auto-enable to avoid conflicts."
        echo "After restarting Claude Code, the {plugin_name} plugin will be available."
    fi
{hook_message}
    echo ""
{summary_lines}
