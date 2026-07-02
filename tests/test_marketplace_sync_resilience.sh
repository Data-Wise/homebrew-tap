#!/usr/bin/env bash
# Contract: claude-plugin formulas retry the post_install marketplace sync
# and degrade gracefully instead of failing loudly.
#
# Root cause (craft session 2026-07-02): Step 2's spawned install script can
# return (Process.waitpid) slightly before its marketplace-mirror write
# (blocks/marketplace.sh) is visible to a freshly-spawned `claude` CLI
# process, causing a spurious "marketplace not found" on `brew reinstall`
# even though the manifest is actually correct. Fix: retry once with a
# short delay, then degrade to an advisory `opoo` with the manual fix-it
# command instead of a raw failed-system-call trace.
#
# Scope: the 6 generated claude-plugin formulas only.

set -u
cd "$(dirname "$0")/.." || exit 2

PLUGINS=$(python3 -c "
import json
m = json.load(open('generator/manifest.json'))
print(' '.join(n for n, c in m['formulas'].items()
      if c.get('type') == 'claude-plugin' and c.get('generated', True)
      and c.get('features', {}).get('marketplace')))
")

fail=0

for name in $PLUGINS; do
    f="Formula/${name}.rb"
    if [ ! -f "$f" ]; then
        echo "FAIL ${name}: $f missing"; fail=1; continue
    fi

    # 1. Retries the marketplace-update call (not a single unconditional fire)
    if ! grep -q '2.times do |attempt|' "$f"; then
        echo "FAIL ${name}: no retry loop around marketplace-update"
        fail=1
    fi

    # 2. Breaks out early once synced (doesn't burn the full retry budget on success)
    if ! grep -qE '^\s*break if synced\s*$' "$f"; then
        echo "FAIL ${name}: retry loop doesn't short-circuit on success (break if synced)"
        fail=1
    fi

    # 3. Degrades to an advisory message on repeated failure, not a raw trace
    if ! grep -q "didn't settle in time" "$f"; then
        echo "FAIL ${name}: no advisory opoo fallback for repeated sync failure"
        fail=1
    fi

    # 4. The fallback message includes the exact manual fix-it command
    if ! grep -q "claude plugin marketplace update local-plugins" "$f"; then
        echo "FAIL ${name}: fallback message missing the manual marketplace-update command"
        fail=1
    fi
    if ! grep -q "claude plugin update ${name}@local-plugins" "$f"; then
        echo "FAIL ${name}: fallback message missing the manual plugin-update command"
        fail=1
    fi

    # 5. plugin update only runs when synced (not unconditionally after a failed sync)
    if ! grep -qE '^\s*if synced\s*$' "$f"; then
        echo "FAIL ${name}: plugin update is not gated on a successful marketplace sync"
        fail=1
    fi
done

if [ "$fail" -eq 0 ]; then
    echo "PASS: all claude-plugin formulas retry+degrade the marketplace sync gracefully"
    echo "  checked: $PLUGINS"
fi
exit "$fail"
