#!/usr/bin/env bash
#
# .STATUS conflict-marker guard.
#
# Fails if the target file contains an unresolved git merge-conflict marker
# (a leftover from a botched rebase/merge that was committed by mistake).
# `.STATUS` is hand-edited frequently across concurrent worktrees/sessions in
# this repo, making it a plausible place for a stray marker to slip through.
#
# Usage:  bash generator/check-status-conflict-markers.sh [<file>]
#         <file> defaults to .STATUS at the repo root.
# Exit:   0 = clean · 1 = conflict marker(s) found · 2 = usage/file-not-found error
#
set -euo pipefail
cd "$(dirname "$0")/.."

TARGET="${1:-.STATUS}"

if [ ! -f "$TARGET" ]; then
  echo "⚠️  file not found: $TARGET" >&2
  exit 2
fi

matches=$(grep -n '^<<<<<<<\|^=======\|^>>>>>>>' "$TARGET" || true)

if [ -n "$matches" ]; then
  echo "❌ conflict marker(s) found in $TARGET:"
  echo "$matches"
  exit 1
fi

echo "✅ $TARGET: no conflict markers."
exit 0
