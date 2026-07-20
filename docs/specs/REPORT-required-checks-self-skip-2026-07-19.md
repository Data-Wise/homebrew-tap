# REPORT: Self-Skipping Required Checks

> ADHD-friendly restructuring of [SPEC-required-checks-self-skip-2026-07-19.md](SPEC-required-checks-self-skip-2026-07-19.md)
> and [GRILL-required-checks-self-skip-2026-07-19.md](GRILL-required-checks-self-skip-2026-07-19.md).
> Generated content only — no new analysis or opinions beyond the source docs.

**Status:** Approved — ready to drive

## tl;dr

| Metric | Value |
|---|---|
| Required checks affected | 2 (`Regen vs committed`, `Check .STATUS for conflict markers`) |
| Prior PRs that hit `BLOCKED` | 3 of 4 (#162, #163, #166) |
| Grill decision branches resolved | 5 |
| Acceptance criteria | 6 |
| Workflow files in scope | 2 (`formula-drift.yml`, `status-guard.yml`) |
| Rollout stages | 2 (status-guard first, formula-drift second) |

## Problem

GitHub's required-status-checks has no path-awareness: if a required check-run context never
reports because its workflow's `paths:` trigger didn't match, GitHub doesn't skip it — it waits
forever and `mergeStateStatus` reports `BLOCKED`. Both `Regen vs committed` and `Check .STATUS
for conflict markers` were path-filtered to their own concern, so any PR touching only one path
set (or neither) hit the wall. 3 of 4 prior PRs (#162, #163, #166 — all `.STATUS`-only) were
merged via `gh pr merge --admin`, bypassing branch protection entirely rather than just the
missing-check gap. Only #165 went `CLEAN`, and only by coincidence of touching both path sets at
once.

## Scope

**In scope:**
- Drop the `paths:` filter from both workflows' `pull_request` triggers (push stays filtered).
- Add a job-level path check that exits 0 (skip) when the relevant path wasn't touched — plain
  `git diff --name-only`, no new third-party action.
- Job names stay unchanged — no branch-protection API changes needed.
- E2E verification per workflow: real-path-touched case and path-not-touched case.
- `.STATUS` record of the change.

**Explicitly out of scope:**
- `Validate all formulas` (already correctly non-required — no `pull_request` trigger at all).
- Any branch-protection API changes.
- `update-formula.yml` or `docs.yml`.

## Acceptance Criteria

- [ ] `.STATUS`-only PR: `Regen vs committed` completes green, fast (<30s), `mergeStateStatus` `CLEAN` without `--admin`.
- [ ] `Formula/**`/`generator/**`-only PR: `Check .STATUS for conflict markers` completes green, fast, merges `CLEAN` without `--admin`.
- [ ] PR touching neither path set merges `CLEAN` without `--admin`.
- [ ] Real `Formula/**` drift bug still fails `Regen vs committed` (planted-defect regression).
- [ ] Real `.STATUS` conflict marker still fails its check (planted-defect regression).
- [ ] No new third-party GitHub Action dependency.

## Decisions (Grill Ledger)

### Diff-base resolution for the skip check
| | |
|---|---|
| **Finding** | Weakest recommendation: the skip check needs a diff base, and `formula-drift.yml` already has a hardened PR-vs-push event-branching step for the revision-bump check. |
| **Problem** | A second, separately-written base-ref resolution risks diverging from the existing hardened one over time. |
| **Fix** | Extend the existing "Determine revision-drift check inputs" step rather than writing a new one. Accepted cost: touches an already-delicate step (`status-guard.yml` has no equivalent step, so this risk doesn't apply there). |

### Silent-skip safety
| | |
|---|---|
| **Finding** | Riskiest assumption: if the skip-check's own diff-resolution logic has a bug, the job could always skip — required check always green, checking nothing. |
| **Problem** | Silent, permanently-passing coverage is worse than the loud `BLOCKED` wall it replaces. |
| **Fix** | Fail closed — a diff-resolution error fails the job, never treated as "nothing changed." Promoted into the SPEC's planted-defect Acceptance Criteria as a CI-enforced invariant, not just a manual spot check. |

### Rollout order
| | |
|---|---|
| **Finding** | Implementation regret: `status-guard.yml` is small with no pre-existing delicate logic; `formula-drift.yml` already has the fragile step being extended (Decision 1). |
| **Problem** | Shipping both at once risks combining a flaw in the new self-skip pattern with the existing fragile step, in the same change. |
| **Fix** | `status-guard.yml` ships first, own PR, as proof of the pattern; `formula-drift.yml` follows once validated. Accepted cost: two PRs, brief window where only one check is fixed. |

### CI-minutes blast radius
| | |
|---|---|
| **Finding** | `formula-drift.yml` moving to an unconditional `pull_request` trigger means it now runs (briefly) on every PR, including automation-generated ones. |
| **Problem** | Is the added CI-minutes cost worth monitoring or gating on? |
| **Fix** | Proceed as scoped — a `git diff --name-only` + exit is sub-second and this repo's PR volume doesn't make it a real cost. No monitoring added; noted for a manual glance later. |

### Scope boundary — `Validate all formulas`
| | |
|---|---|
| **Finding** | `Validate all formulas` currently has no `pull_request` trigger at all — could it be given one scoped to `Formula/**` as part of this fix? |
| **Problem** | It's a heavier, historically weekly-cron-shaped job; whether every PR should run a full formula audit is a separate design question from "make the two already-required checks self-skip." |
| **Fix** | Confirmed out of scope — stays deferred as a separate future decision, not bundled here. |

## Next Steps (from Handoff)

1. Move SPEC status from "Draft — grill before driving" to "Approved — ready to drive."
2. Drive via `/craft:plan docs/specs/SPEC-required-checks-self-skip-2026-07-19.md`, or implement
   directly per the rollout order: `status-guard.yml` first, own PR, E2E-verified per its
   Acceptance Criteria, before touching `formula-drift.yml`.
