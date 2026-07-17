#!/usr/bin/env bash
# Contract: every generated claude-plugin manifest entry declares
# features.marketplace and features.claude_detection.
#
# Root cause (folio#18): folio's manifest entry shipped with no "features"
# key at all, so generate.py silently omitted both the marketplace-mirror
# block and the CLAUDE_RUNNING detection block — brew install "succeeded"
# but never registered the plugin with Claude Code, with no error anywhere.
# This test is the structural guard against the next new plugin shipping
# the same way.
#
# Scope: all claude-plugin, generated=true manifest entries.

set -u
cd "$(dirname "$0")/.." || exit 2

fail=0

result=$(python3 -c "
import json
m = json.load(open('generator/manifest.json'))
bad = []
for name, c in m['formulas'].items():
    if c.get('type') != 'claude-plugin' or not c.get('generated', True):
        continue
    features = c.get('features') or {}
    missing = [
        flag for flag in ('marketplace', 'claude_detection')
        if not features.get(flag)
    ]
    if missing:
        bad.append((name, missing))
for name, missing in bad:
    print(f'{name}: missing {missing}')
")

if [ -n "$result" ]; then
    echo "FAIL: claude-plugin formulas missing required manifest features:"
    echo "$result"
    fail=1
else
    echo "PASS: every generated claude-plugin manifest entry declares marketplace + claude_detection features"
fi

exit "$fail"
