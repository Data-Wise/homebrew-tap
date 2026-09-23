#!/usr/bin/env bash
#
# Planted-defect suite for generator/check-revision-bump.sh (Tasks 2-4 of
# tasks/todo.md, SPEC-release-drift-gates-2026-07-16.md).
#
# Cases 1-2 replay the actual folio#18/#143/#147 incident against real repo
# history (this is also Task 7's dogfood proof — the gate would have caught
# #143). Cases 3-5 use synthetic scratch commits on a disposable branch,
# cleaned up on exit regardless of test outcome.
#
# Usage:  bash tests/test_revision_bump_check.sh
# Exit:   0 = all cases passed · 1 = at least one case failed

set -uo pipefail
cd "$(dirname "$0")/.."

# This suite checks out a scratch branch in the CURRENT working tree, so any
# uncommitted edit would be carried into (or clobbered by) the checkouts.
if [ -n "$(git status --porcelain)" ]; then
  echo "❌ working tree is dirty — commit or stash first (this test switches branches)" >&2
  exit 2
fi

SCRATCH_BRANCH="_test-revision-bump-scratch-$$"
ORIGINAL_BRANCH="$(git branch --show-current)"
fail=0

cleanup() {
  git checkout --quiet "$ORIGINAL_BRANCH" 2>/dev/null || true
  git branch -D "$SCRATCH_BRANCH" >/dev/null 2>&1 || true
}
trap cleanup EXIT

check() {
  local desc="$1" expected_exit="$2"
  shift 2
  local actual_exit=0
  "$@" >/dev/null 2>&1 || actual_exit=$?
  if [ "$actual_exit" = "$expected_exit" ]; then
    echo "✅ $desc"
  else
    echo "❌ $desc (expected exit $expected_exit, got $actual_exit)"
    fail=1
  fi
}

# --- Case 1 & 2: real incident replay (real repo history; PR #143 / #147) ---

check "Case 1 (dogfood #143): pre-fix diff FAILS for folio" 1 \
  bash generator/check-revision-bump.sh 8fb7bc9 5c08475

# Case 2 (dogfood #147): the script's overall exit code for this range is
# NOT asserted as 0 — an unrelated real gap in atlas's formula (a separate,
# already-known, out-of-scope finding from PR #157) also lives in this range
# and makes the script correctly exit 1. What this case actually verifies is
# that folio *specifically* passes (its revision was bumped) — check the
# captured output rather than the aggregate exit code.
case2_output=$(bash generator/check-revision-bump.sh 5c08475 dcecd5c 2>/dev/null || true)
if printf '%s' "$case2_output" | grep -q "✅ folio:"; then
  echo "✅ Case 2 (dogfood #147): folio specifically passes (revision bumped)"
else
  echo "❌ Case 2 (dogfood #147): folio does not show as passing"
  fail=1
fi

# --- Case 3: cosmetic-only synthetic change passes without a bump ---

git checkout --quiet -b "$SCRATCH_BRANCH"
sed -i.bak 's/# Install a REAL copy of the Homebrew-managed files/# Install a REAL copy of the Homebrew managed files/' Formula/folio.rb
rm -f Formula/folio.rb.bak
if git diff --quiet -- Formula/folio.rb; then
  echo "❌ Case 3 setup: the comment-only sed matched nothing in Formula/folio.rb"
  exit 1
fi
git add Formula/folio.rb
git commit --quiet -m "test: cosmetic-only comment change"
COSMETIC_SHA=$(git rev-parse HEAD)

check "Case 3: comment-only change PASSES without a revision bump" 0 \
  bash generator/check-revision-bump.sh HEAD~1 "$COSMETIC_SHA"

# --- Case 4: real logic change (no bump) still fails ---

git checkout --quiet "$SCRATCH_BRANCH"
sed -i.bak 's/mkdir -p "\$HOME\/.claude\/plugins" 2>\/dev\/null || true/mkdir -p "$HOME\/.claude\/plugins_test" 2>\/dev\/null || true/' Formula/folio.rb
rm -f Formula/folio.rb.bak
if git diff --quiet -- Formula/folio.rb; then
  echo "❌ Case 4 setup: the logic-change sed matched nothing in Formula/folio.rb"
  exit 1
fi
git add Formula/folio.rb
git commit --quiet -m "test: real logic change, no revision bump"
LOGIC_SHA=$(git rev-parse HEAD)

check "Case 4: real logic change (no bump) still FAILS" 1 \
  bash generator/check-revision-bump.sh "$COSMETIC_SHA" "$LOGIC_SHA"

# --- Case 5: revision-exempt label bypasses even a real, unbumped change ---

check "Case 5: PR_LABELS=revision-exempt bypasses the check entirely" 0 \
  env PR_LABELS="revision-exempt" bash generator/check-revision-bump.sh "$COSMETIC_SHA" "$LOGIC_SHA"

check "Case 5b: an unrelated label does NOT bypass" 1 \
  env PR_LABELS="some-other-label" bash generator/check-revision-bump.sh "$COSMETIC_SHA" "$LOGIC_SHA"

# --- Case 6: URL-tag-versioned formula (no explicit `version` field) ---
#
# craft.rb has no `version "..."` line — Homebrew infers the version from the
# `url`'s git tag. Before the extract_version() fallback, base/head version
# both read as "" for every bump, so a real logic change alongside a version
# bump false-positived as "content changed but version did not" (the
# incident that forced the "revision-exempt" label workaround on v4.2.0).

git checkout --quiet "$SCRATCH_BRANCH"
CRAFT_BASE_SHA=$(git rev-parse HEAD)
# Derive the tag from the formula instead of hardcoding it: a hardcoded
# v4.2.0 silently stopped matching once craft moved on, leaving only the desc
# edit — a content change with no version change — so the case failed.
CRAFT_TAG=$(grep -oE 'refs/tags/v[0-9]+\.[0-9]+\.[0-9]+\.tar\.gz' Formula/craft.rb | head -1 | sed -E 's#refs/tags/v##; s#\.tar\.gz##')
IFS=. read -r C_MAJ C_MIN _ <<< "$CRAFT_TAG"
CRAFT_NEXT="${C_MAJ}.$((C_MIN + 1)).0"
sed -i.bak \
  -e "s#refs/tags/v${CRAFT_TAG}\.tar\.gz#refs/tags/v${CRAFT_NEXT}.tar.gz#" \
  -e 's/^\(  desc "[^"]*\)"/\1 (test)"/' \
  Formula/craft.rb
rm -f Formula/craft.rb.bak
if ! grep -qF "refs/tags/v${CRAFT_NEXT}.tar.gz" Formula/craft.rb || ! grep -q '^  desc ".* (test)"' Formula/craft.rb; then
  echo "❌ Case 6 setup: could not bump craft's url tag (${CRAFT_TAG:-none found}) or desc"
  exit 1
fi
git add Formula/craft.rb
git commit --quiet -m "test: url-tag version bump + real content change"
CRAFT_BUMP_SHA=$(git rev-parse HEAD)

check "Case 6: url-tag version bump is recognized (no false positive)" 0 \
  bash generator/check-revision-bump.sh "$CRAFT_BASE_SHA" "$CRAFT_BUMP_SHA"

exit "$fail"
