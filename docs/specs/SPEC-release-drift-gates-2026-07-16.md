# SPEC: Release Drift Gates — Revision Check + .STATUS Conflict-Marker Guard

**Date:** 2026-07-16 · **Status:** Draft — ready to drive
**Brainstorm:** [docs/brainstorm/BRAINSTORM-release-drift-gates-2026-07-16.md](../brainstorm/BRAINSTORM-release-drift-gates-2026-07-16.md)
**Repo:** `homebrew-tap`
**Related:** [#143](https://github.com/Data-Wise/homebrew-tap/pull/143), [#147](https://github.com/Data-Wise/homebrew-tap/pull/147)

## Problem

Two structurally-repeatable gaps surfaced while shipping folio#18's fix, both caught only by
manual post-hoc inspection rather than any automated gate:

1. PR #143 changed `Formula/folio.rb`'s content (via a `manifest.json` edit + regenerate)
   without bumping `version` or `revision` — meaning `brew upgrade` could never detect the
   change on already-installed machines. Nothing in CI or `bump-version.sh` catches this class
   of change; it took a manual `brew reinstall` + `brew outdated` check in a later session to
   notice, followed by a separate fix (PR #147).
2. `homebrew-tap`'s `.STATUS` file contained unresolved `<<<<<<<`/`=======`/`>>>>>>>` git
   conflict markers from a prior stash/pull collision, undetected until a human happened to open
   the file during an unrelated update.

## Integration point (corrected 2026-07-16, post-merge)

The original draft proposed a new CI workflow for the revision-drift gate. **`homebrew-tap`
already has one** — `.github/workflows/formula-drift.yml` ("Formula Drift Guard") already
triggers on exactly the right paths (`generator/**`, `Formula/**`, both `push` and
`pull_request`) and already runs `generator/check-drift.sh`, which regenerates every formula and
diffs against what's committed. It's the same job that passed as "Regen vs committed" on both
#143 and #147. The revision-drift gate belongs as a **second script + step in this same
workflow**, not a new one — `check-drift.sh` checks "does committed match a regen at this
commit" (catches hand-edits bypassing the generator); the new script checks "if content changed
since the base ref, did version/revision also change" (catches exactly the #143 gap). Sibling
scripts, sibling steps, same trigger — no new workflow file needed.

## Scope

### In scope

- **Revision-drift check** (Option 1 from the brainstorm, revised integration point above): a
  new script (e.g. `generator/check-revision-bump.sh`), added as a step in the existing
  `formula-drift.yml` workflow, that diffs each `Formula/*.rb` between the PR's base ref (or
  `git merge-base`) and HEAD and fails if any formula differs (excluding whitespace/comment-only
  diffs) while `version` and `revision` are both unchanged.
- **`.STATUS` conflict-marker guard** (the blocking half of Option 3): a check — CI job, or a
  pre-commit/local hook, whichever integrates more cleanly with the existing hook stack — that
  fails/blocks if `.STATUS` contains a literal `<<<<<<<`, `=======`, or `>>>>>>>` line.
- A "cosmetic-only" escape hatch for the revision-drift gate (see Acceptance Criteria) so a pure
  `desc`-string typo fix or similar doesn't force an unnecessary revision bump.
- Planted-defect tests for both gates, including replaying PR #143's actual diff shape as the
  revision-drift gate's positive control.

### Explicitly out of scope

- `/craft:release` Step 2 pre-flight addition (Option 2) — advisory-only value-add for projects
  releasing *through* craft; doesn't catch direct `homebrew-tap` edits (which is how both #143
  and #147 actually happened). Deferred; revisit only if Option 1 proves out and craft-side
  coverage is still wanted.
- `.STATUS` age-based staleness check (the "last_session: N days stale" half of Option 3) — no
  settled threshold, needs real usage data before committing to a number. This SPEC ships only
  the conflict-marker half, which has zero false-positive risk and needs no threshold tuning.
- Auto-writing `.STATUS` entries — explicitly rejected in the brainstorm; stays a human-authored
  file, this SPEC only adds a corruption-detection gate, not a content-generation feature.

## Acceptance Criteria

- [ ] A new step in `.github/workflows/formula-drift.yml` runs `generator/check-revision-bump.sh`
      (new script, sibling to `check-drift.sh`), which diffs each `Formula/*.rb` between the PR
      base ref and HEAD and fails if any formula differs (non-whitespace/comment lines) while
      both `version` and `revision` are unchanged — the failure message names the exact formula
      and states `revision: N` as the fix. No new workflow file — this reuses
      `formula-drift.yml`'s existing `generator/**`/`Formula/**` path triggers.
- [ ] A "cosmetic-only" escape hatch exists — e.g. a manifest-level marker consumed by the gate
      for that specific regeneration — so a genuinely behavior-inert change (comment rewrap,
      `desc` typo fix) doesn't force a revision bump. Document what counts as cosmetic in the
      gate's own code comments, not just this SPEC.
- [ ] Planted-defect test: regenerate a formula with a content-only change and no revision bump
      → gate FAILS. Regenerate with `revision` bumped → gate PASSES. Regenerate with a
      comment-only diff and the cosmetic-only marker set → gate PASSES (no false positive).
- [ ] Dogfood test: replay PR #143's actual `Formula/folio.rb` diff (content changed, revision
      absent) against the new gate on the pre-#147 commit — confirm it FAILS, proving this gate
      would have caught the exact incident that motivated it.
- [ ] A check (CI job or hook) fails/blocks when `.STATUS` contains any of `<<<<<<<`, `=======`,
      `>>>>>>>` as a line-start literal.
- [ ] Planted-defect test for the conflict-marker check: a scratch `.STATUS` with a planted
      `<<<<<<<` block → check FAILS. A clean `.STATUS` → check PASSES.
- [ ] Existing test suite (`test_manifest_required_features.sh`, `test_marketplace_sync_resilience.sh`,
      `test_no_symlink_install.sh`, `test_craft_install_timeout.sh`) still passes — no regression
      to the 7 existing formulas from adding this gate.

## Review Checklist

- [ ] The revision-drift gate's diff comparison correctly ignores comment-only and
      whitespace-only changes — verified by the planted comment-only test, not just asserted.
- [ ] The cosmetic-only escape hatch can't be used to silently bypass a *behavioral* change —
      spot-check that the marker is scoped per-regeneration (tied to a specific commit/PR), not a
      standing manifest flag that permanently disables the gate for a formula.
- [ ] `CLAUDE.md`'s Formula Generator section gets one paragraph documenting the revision-drift
      gate and the cosmetic-only escape hatch, alongside the existing `features` flag
      requirement paragraph from #143 (same section, same convention).

## Key Files

- `homebrew-tap/.github/workflows/formula-drift.yml` — add the new step here (no new workflow)
- `homebrew-tap/generator/check-drift.sh` — read-only reference for the sibling script's
  structure/conventions (`set -euo pipefail`, exit codes 0/1/2, restore-working-tree-on-exit)
- `homebrew-tap/generator/check-revision-bump.sh` — new script, this SPEC's actual deliverable
- `homebrew-tap/generator/generate.py` — read-only reference for the existing `--diff` pattern
  this gate reuses
- `homebrew-tap/tests/` — new test file(s) for both gates, following the existing
  `test_manifest_required_features.sh` naming/structure convention
- `homebrew-tap/.STATUS` — read-only reference for what a conflict-marker defect actually looks
  like (already cleaned up in a prior session; do not reintroduce for testing — use a scratch
  file instead)
- `homebrew-tap/CLAUDE.md` — Formula Generator section (doc addition per Review Checklist)

## Test Plan

| Tier | What |
|---|---|
| `unit`/`generator` | Revision-drift gate: 3 planted-defect cases (no-bump-fails, bump-passes, cosmetic-only-passes) per Acceptance Criteria. |
| `e2e`/`dogfood` | Replay PR #143's diff against the pre-#147 commit — gate must fail. |
| `unit` | Conflict-marker check: planted-marker-fails, clean-passes. |
| `count-cascade` | N/A — no command/skill/agent surface change. |
| `dependency` | N/A — no new external dependency (reuses existing `generator/generate.py` + `git diff`). |

Stub both gates' tests red-first (failing placeholder against the not-yet-built gate), confirm
red, then build the gate to green.

## Documentation

Doc-impact score below threshold for guide/refcard/demo (internal CI tooling). One `CLAUDE.md`
paragraph per Review Checklist — same location as the existing `features`-flag-requirement
paragraph added after #143.

- [ ] Guide — N/A, score <3
- [ ] Refcard — N/A, score <3
- [ ] Demo — N/A, score <3
- [ ] Mermaid — N/A, score <3
- [x] CLAUDE.md paragraph

## How to drive this

```bash
# homebrew-tap repo (single-integration: main ← feature/*, no dev branch)
cd ~/projects/dev-tools/homebrew-tap
git worktree add ~/.git-worktrees/homebrew-tap/feature-release-drift-gates \
  -b feature/release-drift-gates main
cd ~/.git-worktrees/homebrew-tap/feature-release-drift-gates
# implement per Acceptance Criteria above, or hand this SPEC to a driving skill if
# homebrew-tap has one available.
```
