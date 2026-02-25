    echo "✅ {display_name} plugin installed successfully!"
    echo ""
    if [ "$AUTO_ENABLED" = true ]; then
        echo "Plugin auto-enabled in Claude Code."
    elif [ "$CLAUDE_RUNNING" = true ]; then
        echo "Claude Code is running - skipped auto-enable to avoid conflicts."
        echo "Run: claude plugin install {plugin_name}@local-plugins"
    else
        echo "To enable, run: claude plugin install {plugin_name}@local-plugins"
    fi
{hook_message}
    echo ""
{summary_lines}
