# Strip unrecognized keys from plugin.json (Claude Code rejects them)
PLUGIN_JSON="$SOURCE_DIR/.claude-plugin/plugin.json"
if grep -q 'claude_md_budget' "$PLUGIN_JSON" 2>/dev/null; then
    python3 -c "import json,sys;p=sys.argv[1];d=json.load(open(p));c={k:v for k,v in d.items() if k in('name','version','description','author')};f=open(p,'w');json.dump(c,f,indent=2);f.write(chr(10));f.close()" "$PLUGIN_JSON" 2>/dev/null || true
fi
