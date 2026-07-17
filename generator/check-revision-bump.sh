#!/usr/bin/env bash
#
# Revision-drift guard.
#
# Fails if any Formula/*.rb's content changed between a base ref and a head
# ref while neither `version` nor `revision` changed — that class of edit is
# invisible to `brew upgrade` (it compares version+revision against the
# installed receipt, not file content), so an already-installed formula would
# never pick up the fix. See generator/manifest.json's `revision` field and
# docs/generator/manifest.md.
#
# This is a minimal first pass (Task 2 of tasks/todo.md): no cosmetic-only
# diff exclusion yet (Task 3), no revision-exempt label escape hatch yet
# (Task 4). Any content diff at all, without a version/revision bump, fails.
#
# Usage:  bash generator/check-revision-bump.sh <base-ref> [<head-ref>]
#         head-ref defaults to HEAD.
# Exit:   0 = no drift (or version/revision bumped) · 1 = drift detected · 2 = usage error
#
set -euo pipefail
cd "$(dirname "$0")/.."

if [ $# -lt 1 ]; then
  echo "Usage: bash generator/check-revision-bump.sh <base-ref> [<head-ref>]" >&2
  exit 2
fi

BASE_REF="$1"
HEAD_REF="${2:-HEAD}"

if ! git rev-parse --verify --quiet "$BASE_REF" >/dev/null; then
  echo "⚠️  base ref '$BASE_REF' not found — is this checkout shallow? (needs fetch-depth: 0)" >&2
  exit 2
fi

# Extract a field ("version" or "revision") from a Formula/*.rb file at a given ref.
# Returns empty string if the field isn't present (e.g. no revision line at all).
extract_field() {
  local ref="$1" formula="$2" field="$3"
  git show "$ref:$formula" 2>/dev/null | grep -oE "^\s*${field}\s+\"?[^\"[:space:]]+\"?" \
    | grep -oE '[^ \"]+$' | tr -d '"' || true
}

fail=0
changed_formulas=$(git diff --name-only "$BASE_REF" "$HEAD_REF" -- Formula/ 2>/dev/null || true)

if [ -z "$changed_formulas" ]; then
  echo "✅ No Formula/*.rb changes between $BASE_REF and $HEAD_REF."
  exit 0
fi

for formula in $changed_formulas; do
  name=$(basename "$formula" .rb)

  base_version=$(extract_field "$BASE_REF" "$formula" version)
  head_version=$(extract_field "$HEAD_REF" "$formula" version)
  base_revision=$(extract_field "$BASE_REF" "$formula" revision)
  head_revision=$(extract_field "$HEAD_REF" "$formula" revision)

  if [ "$base_version" = "$head_version" ] && [ "$base_revision" = "$head_revision" ]; then
    echo "❌ $name: content changed ($BASE_REF → $HEAD_REF) but version/revision did not."
    echo "   brew upgrade will never detect this change on already-installed machines."
    echo "   Fix: add/bump \"revision\": N on $name's entry in generator/manifest.json,"
    echo "   then run: python3 generator/generate.py $name"
    fail=1
  else
    echo "✅ $name: version or revision changed ($base_version/$base_revision → $head_version/$head_revision)."
  fi
done

exit "$fail"
