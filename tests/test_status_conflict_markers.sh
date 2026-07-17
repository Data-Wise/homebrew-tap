#!/usr/bin/env bash
#
# Planted-defect test for generator/check-status-conflict-markers.sh (Task 8
# of tasks/todo.md, SPEC-release-drift-gates-2026-07-16.md).
#
# Usage:  bash tests/test_status_conflict_markers.sh
# Exit:   0 = all cases passed · 1 = at least one case failed

set -uo pipefail
cd "$(dirname "$0")/.."

SCRATCH_DIR="$(mktemp -d)"
fail=0

cleanup() {
  rm -rf "$SCRATCH_DIR"
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

# --- Case 1: unmodified real .STATUS passes ---

check "Case 1: real .STATUS is clean" 0 \
  bash generator/check-status-conflict-markers.sh .STATUS

# --- Case 2: planted conflict marker fails ---

CONFLICT_FILE="$SCRATCH_DIR/STATUS-with-conflict"
cp .STATUS "$CONFLICT_FILE"
cat >>"$CONFLICT_FILE" <<'EOF'
<<<<<<< HEAD
some local change
=======
some incoming change
>>>>>>> feature/other-branch
EOF

check "Case 2: planted conflict marker FAILS" 1 \
  bash generator/check-status-conflict-markers.sh "$CONFLICT_FILE"

# --- Case 3: missing file is a usage error, not a silent pass ---

check "Case 3: missing file exits 2 (usage error)" 2 \
  bash generator/check-status-conflict-markers.sh "$SCRATCH_DIR/does-not-exist"

exit "$fail"
