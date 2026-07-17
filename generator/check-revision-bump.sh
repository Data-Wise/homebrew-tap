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
# Comment-only and whitespace-only diffs are excluded (Task 3) — a rewrapped
# bash comment inside the install/post_install heredoc, or a pure Ruby
# comment change, doesn't affect installed behavior and shouldn't force a
# revision bump.
#
# A PR labeled "revision-exempt" bypasses the check entirely (Task 4) — the
# label is per-PR (never stored in the manifest/codebase, so there's nothing
# to forget and leave permanently bypassed) and only recognized on
# pull_request-triggered runs; a push event has no PR/label context and
# always runs the full check.
#
# Usage:  PR_LABELS="label-one,label-two" bash generator/check-revision-bump.sh <base-ref> [<head-ref>]
#         PR_LABELS is optional (unset/empty on push events); head-ref defaults to HEAD.
# Exit:   0 = no drift (or version/revision bumped, or exempt) · 1 = drift detected · 2 = usage error
#
set -euo pipefail
cd "$(dirname "$0")/.."

if [ $# -lt 1 ]; then
  echo "Usage: PR_LABELS=\"...\" bash generator/check-revision-bump.sh <base-ref> [<head-ref>]" >&2
  exit 2
fi

BASE_REF="$1"
HEAD_REF="${2:-HEAD}"

if ! git rev-parse --verify --quiet "$BASE_REF" >/dev/null; then
  echo "⚠️  base ref '$BASE_REF' not found — is this checkout shallow? (needs fetch-depth: 0)" >&2
  exit 2
fi

if printf '%s' "${PR_LABELS:-}" | tr ',' '\n' | grep -qx "revision-exempt"; then
  echo "⚠️  PR labeled 'revision-exempt' — skipping the revision-bump check entirely."
  exit 0
fi

# Extract a field ("version" or "revision") from a Formula/*.rb file at a given ref.
# Returns empty string if the field isn't present (e.g. no revision line at all).
extract_field() {
  local ref="$1" formula="$2" field="$3"
  git show "$ref:$formula" 2>/dev/null | grep -oE "^\s*${field}\s+\"?[^\"[:space:]]+\"?" \
    | grep -oE '[^ \"]+$' | tr -d '"' || true
}

# True (exit 0) if every added/removed line in the diff is blank or a comment
# (leading '#', after stripping the +/- marker and whitespace). Both Ruby's
# top-level comments and bash comments embedded in the install/post_install
# heredocs use the same '#' prefix, so one check covers both nesting levels —
# no need to parse heredoc boundaries separately.
is_cosmetic_only_diff() {
  local base="$1" head="$2" formula="$3" line content stripped
  while IFS= read -r line; do
    case "$line" in
      diff\ --git*|index\ *|---\ *|+++\ *|@@*) continue ;;
    esac
    content="${line#[+-]}"
    stripped="$(printf '%s' "$content" | sed -E 's/^[[:space:]]*//')"
    if [ -n "$stripped" ] && [ "${stripped:0:1}" != "#" ]; then
      return 1
    fi
  done < <(git diff -U0 "$base" "$head" -- "$formula" 2>/dev/null)
  return 0
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
    if is_cosmetic_only_diff "$BASE_REF" "$HEAD_REF" "$formula"; then
      echo "✅ $name: comment/whitespace-only change — no revision bump needed."
    else
      echo "❌ $name: content changed ($BASE_REF → $HEAD_REF) but version/revision did not."
      echo "   brew upgrade will never detect this change on already-installed machines."
      echo "   Fix: add/bump \"revision\": N on $name's entry in generator/manifest.json,"
      echo "   then run: python3 generator/generate.py $name"
      fail=1
    fi
  else
    echo "✅ $name: version or revision changed ($base_version/$base_revision → $head_version/$head_revision)."
  fi
done

exit "$fail"
