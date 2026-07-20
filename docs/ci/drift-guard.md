# Formula Drift Guard

Required check on every pull request. Job name: **Regen vs committed**.

## What It Checks

1. **Regen vs committed** (`generator/check-drift.sh`) — regenerates every formula from
   `generator/manifest.json` and fails if any committed `Formula/*.rb` differs. Catches a
   generated formula hand-edited without updating the manifest (the next release regen would
   silently revert the hand edit).
2. **No-symlink install contract** (`tests/test_no_symlink_install.sh`) — the 6 generated
   `claude-plugin` formulas must install real copies, never symlinks, and depend on `jq` as
   required (not optional).
3. **Revision-drift check** (`generator/check-revision-bump.sh`) — fails if a formula's content
   changed since the PR's base ref but neither `version` nor `revision` did. `brew upgrade`
   compares only `version`+`revision` against the installed receipt, not file content, so a
   content-only change is otherwise invisible to already-installed machines.

## Escape Hatch: `revision-exempt` Label

A PR can bypass the revision-drift check entirely by adding the `revision-exempt` label —
for changes that are genuinely cosmetic but not caught by the check's own comment/whitespace-diff
exclusion. The label is per-PR, not persisted anywhere; the PR's label history is the audit trail.
`push` events (no labels available) never see this bypass.

## Self-Skipping (Path-Aware Without a Path Filter)

The `pull_request` trigger has **no path filter** — it runs on every PR. A job-level step
(`Determine formula-drift check inputs`) diffs the PR against its base ref and skips all three
real checks fast (a few seconds) when the PR touches neither `generator/**` nor `Formula/**`.

This matters because **required status checks have no path-awareness of their own**: a
path-filtered trigger left this check permanently "expected — waiting" (and the PR permanently
blocked) on any PR that didn't happen to touch those paths — GitHub doesn't skip a required check
just because its workflow never ran, it waits forever. See
[SPEC-required-checks-self-skip-2026-07-19.md](https://github.com/Data-Wise/homebrew-tap/blob/main/docs/specs/SPEC-required-checks-self-skip-2026-07-19.md)
for the full incident and fix.

**Fail-closed contract:** if the base-ref/diff resolution itself errors, the job **fails** rather
than skips — an unresolvable "what changed?" is never treated as "nothing changed," which would
make this required check always green while checking nothing.

`push` events stay path-filtered (`generator/**`, `Formula/**`,
`.github/workflows/formula-drift.yml`) — unaffected by the self-skip change; only `pull_request`
runs unconditionally.

## Running Locally

```bash
# Regen-vs-committed
bash generator/check-drift.sh

# No-symlink contract
bash tests/test_no_symlink_install.sh

# Revision-drift (compare against a base ref, e.g. origin/main)
bash generator/check-revision-bump.sh origin/main
```
