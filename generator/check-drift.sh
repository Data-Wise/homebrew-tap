#!/usr/bin/env bash
#
# Formula drift guard.
#
# Fails if any committed Formula/*.rb differs from a fresh regeneration from
# generator/manifest.json + generator/generate.py — i.e. a generated formula
# was hand-edited without updating the manifest. Catches silent manifest-drift
# before it can be reverted by the next release regen.
#
# Usage:  bash generator/check-drift.sh
# Exit:   0 = no drift · 1 = drift detected · 2 = working tree not clean
#
set -euo pipefail
cd "$(dirname "$0")/.."

# Refuse to run with uncommitted Formula/ changes: we restore via `git checkout`
# below, which would clobber any in-progress work.
if ! git diff --quiet -- Formula/; then
  echo "⚠️  Formula/ has uncommitted changes — commit or stash them first, then re-run."
  exit 2
fi

# Regenerate every formula in place from the source of truth.
python3 generator/generate.py >/dev/null

if git diff --quiet -- Formula/; then
  echo "✅ No drift — every Formula/*.rb matches generator/ + manifest.json."
  exit 0
fi

echo "❌ Formula drift detected — these committed formulas differ from a fresh regen:"
echo ""
git --no-pager diff --stat -- Formula/
echo ""
echo "A generated Formula/*.rb was hand-edited without updating the source."
echo "Fix: move the change into generator/manifest.json (or generator/generate.py),"
echo "then run:  python3 generator/generate.py && git add Formula/ generator/"

# Restore the working tree so a local run leaves no changes behind.
git checkout -- Formula/ 2>/dev/null || true
exit 1
