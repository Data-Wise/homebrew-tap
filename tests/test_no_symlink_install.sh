#!/usr/bin/env bash
# Contract: claude-plugin formulas install REAL copies, never symlinks.
#
# Enforces the no-symlinks install policy (SPEC-dist-surface-hardening B):
#   - no `ln -s` anywhere in a generated claude-plugin formula
#   - jq is a REQUIRED dependency (not `=> :optional`)
#   - the install uses a tar-pipe copy
#
# Scope: the 6 generated claude-plugin formulas only. Non-plugin formulas
# (e.g. aiterm's zsh-integration symlink) are out of scope.

set -u
cd "$(dirname "$0")/.." || exit 2

# Claude-plugin formulas (type == claude-plugin && generated != false)
PLUGINS=$(python3 -c "
import json
m = json.load(open('generator/manifest.json'))
print(' '.join(n for n, c in m['formulas'].items()
      if c.get('type') == 'claude-plugin' and c.get('generated', True)))
")

fail=0
note() { printf '  %s\n' "$1"; }

for name in $PLUGINS; do
    f="Formula/${name}.rb"
    if [ ! -f "$f" ]; then
        echo "FAIL ${name}: $f missing"; fail=1; continue
    fi

    # 1. No symlink creation anywhere in the formula
    if grep -qE '\bln -s' "$f"; then
        echo "FAIL ${name}: contains 'ln -s' (must install a real copy)"
        grep -nE '\bln -s' "$f" | sed 's/^/    /'
        fail=1
    fi

    # 2. jq is a required dependency, not optional
    if ! grep -qE '^\s*depends_on "jq"\s*$' "$f"; then
        echo "FAIL ${name}: jq is not a required dependency (depends_on \"jq\")"
        fail=1
    fi
    if grep -qE 'depends_on "jq" => :optional' "$f"; then
        echo "FAIL ${name}: jq is still declared :optional"
        fail=1
    fi

    # 3. Install uses a tar-pipe copy
    if ! grep -q 'tar cf - .' "$f"; then
        echo "FAIL ${name}: no tar-pipe copy found (expected real-copy install)"
        fail=1
    fi
done

if [ "$fail" -eq 0 ]; then
    echo "PASS: all claude-plugin formulas install real copies (no symlinks, jq required)"
    echo "  checked: $PLUGINS"
fi
exit "$fail"
