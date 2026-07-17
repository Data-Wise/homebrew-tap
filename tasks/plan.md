# Implementation Plan: Release Drift Gates (Revision Check + .STATUS Conflict-Marker Guard)

**Spec:** `docs/specs/SPEC-release-drift-gates-2026-07-16.md`
**Adversarial review findings incorporated:** see Architecture Decisions and Open Questions below —
this plan folds in the review's two 🔴 findings (required-status-checks gap, shallow-clone gap)
as explicit tasks/decisions rather than leaving them implicit.

## Overview

Two independent CI guards, both born from the same incident (folio#18 / PR #143 / PR #147): a
**revision-drift check** that fails when a formula's content changes without a matching
`version`/`revision` bump, and a **`.STATUS` conflict-marker guard** that fails when the file
contains unresolved git-conflict markers. Neither depends on the other — they can be built and
merged independently, in either order.

## Architecture Decisions

- **Extend `formula-drift.yml`, don't create a new workflow** — it already triggers on the right
  paths (`generator/**`, `Formula/**`) and already runs the sibling `check-drift.sh` regen+diff
  pattern (per the SPEC's corrected integration point).
- **Fix `fetch-depth` before writing the diff logic, not after** — the adversarial review found
  `actions/checkout@v4` in this workflow has no `fetch-depth` override (default: 1, no history).
  The revision-drift script's core operation (`git diff <base>..HEAD -- Formula/`) cannot run
  without the base commit present. This is Task 1, not an afterthought — writing the diff script
  first and discovering it can't fetch its own input would be wasted work.
- **Required-status-checks is a repo-settings decision, not an implementation detail** — the
  review found `main` has no `required_status_checks` at all (guardrails-only protection,
  documented tradeoff for `update-formula.yml`'s `auto_merge: true`). Adding this check to
  required contexts is a **human decision** (Open Question below), not something to silently
  assume or silently skip. The gate ships either way; whether it *blocks* merge is a separate,
  explicit choice.
- **Cosmetic-only escape hatch is scoped per-PR, not a standing manifest flag** — mechanism:
  a `revision-exempt` PR label, checked by the workflow step via `github.event.pull_request.labels`.
  A label is inherently PR-scoped (never persists past that PR, visible in the PR history for
  audit, no manifest-file bypass that could be forgotten and left permanently enabled). This
  directly answers the adversarial review's "what clears the marker" question — nothing needs to
  clear it, because it's attached to the PR, not the codebase.

## Task List

### Phase 1: Foundation — make the diff mechanically possible

- [ ] Task 1: Fix checkout depth in `formula-drift.yml`
- [ ] Task 2: Write `check-revision-bump.sh` — no-bump-fails / bump-passes only (no cosmetic
      escape hatch yet, no comment-filtering yet — smallest thing that can be wrong)

### Checkpoint: After Tasks 1-2
- [ ] `bash generator/check-revision-bump.sh <fake-base-sha> <fake-head-sha>` runs against a
      local planted-defect scenario without erroring on missing refs
- [ ] Manual dry run confirms it would have failed on PR #143's actual diff (using real SHAs)

### Phase 2: Refine detection — cosmetic-only + comment handling

- [ ] Task 3: Add comment/whitespace-only diff exclusion (Ruby `#` and embedded-bash `#` both
      handled — the adversarial review's heredoc-nesting concern)
- [ ] Task 4: Add the `revision-exempt` PR-label escape hatch

### Checkpoint: After Tasks 3-4
- [ ] Planted-defect test suite (Task 6, pulled forward for this checkpoint) passes: no-bump-fails,
      bump-passes, comment-only-passes, labeled-exempt-passes

### Phase 3: Wire in + test + dogfood

- [ ] Task 5: Add the new step to `formula-drift.yml`
- [ ] Task 6: Write `tests/test_revision_bump_check.sh` (planted-defect suite — write this
      alongside Tasks 2-4, not strictly after; listed here for dependency-order clarity in the
      checklist)
- [ ] Task 7: Dogfood replay of PR #143 (concrete SHAs pinned — see Task 7 below)

### Checkpoint: After Tasks 5-7
- [ ] Full existing test suite still green (`test_manifest_required_features.sh`,
      `test_marketplace_sync_resilience.sh`, `test_no_symlink_install.sh`,
      `test_craft_install_timeout.sh`)
- [ ] New workflow step passes on a clean PR, fails on a planted-defect PR (real CI run, not just
      local script execution)
- [ ] **Human checkpoint: resolve the required-status-checks Open Question before merging** —
      this determines whether the gate is enforced or advisory-only from day one

### Phase 4: `.STATUS` conflict-marker guard (independent of Phases 1-3)

- [ ] Task 8: Write `check-status-conflict-markers.sh` + planted-defect test
- [ ] Task 9: Wire into CI (new lightweight workflow, or a step in an existing one — TBD at
      implementation time; no existing workflow currently touches `.STATUS`)

### Checkpoint: After Tasks 8-9
- [ ] Planted `<<<<<<<` in a scratch file → check fails; clean file → check passes
- [ ] Real CI run confirms it fires on a PR

### Phase 5: Documentation

- [ ] Task 10: `CLAUDE.md` Formula Generator section — one paragraph covering the revision-drift
      gate + `revision-exempt` label escape hatch

### Checkpoint: Complete
- [ ] All SPEC Acceptance Criteria checked off
- [ ] Required-status-checks decision recorded (whatever it was) in the SPEC or a follow-up note
- [ ] Ready for review

## Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Required-status-checks decision gets skipped/forgotten, gate ships advisory-only without anyone deciding that on purpose | High | Phase 3's checkpoint explicitly names this as a human gate — do not proceed to Phase 4/5 silently past it |
| `fetch-depth` fix increases checkout time/cost across all `formula-drift.yml` runs (not just this new step) | Low | `fetch-depth: 0` on a small repo (16 formulas, modest history) is cheap; measure actual CI time delta once merged, not a blocker |
| Comment/heredoc-aware diffing (Task 3) is genuinely hard to get exactly right | Medium | Ship Phase 1 (no comment filtering) first if Task 3 stalls — a gate with occasional false positives on comment-only changes is still strictly better than no gate; don't let Task 3 block Phase 3's real value |
| `revision-exempt` label could be applied reflexively to dodge a real failure | Medium | Label is visible in PR history (audit trail) — this is a social/review-process safeguard, not a technical one; call this out explicitly in the CLAUDE.md doc (Task 10) so reviewers know to check for label misuse |

## Open Questions

- **Required-status-checks:** should this new check (and/or the existing `formula-drift.yml`
  job) be added to `main`'s required status checks? This trades the documented `auto_merge: true`
  convenience (direct-push from `update-formula.yml`) against actually enforcing the gate. Needs
  a human decision — do not implement Phase 3's checkpoint past this without an explicit answer.
- **`.STATUS` guard's CI home (Task 9):** no existing workflow currently reads `.STATUS` — new
  lightweight workflow, or folded into an existing one (e.g. `validate-formulas.yml`'s weekly
  cron, or a new `push`/`pull_request` trigger)? Lower stakes than the required-status-checks
  question; can be decided at implementation time rather than blocking planning.
