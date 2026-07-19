# BRAINSTORM: Required-checks path-filtering vs. unconditional/self-skipping

**Date:** 2026-07-19
**Depth:** quick | **Focus:** ops
**Context:** Follow-up to PRs #162/#163/#165/#166 (main branch-protection setup + fix + live verification)

## What the question actually means

GitHub's `required_status_checks.contexts` is a flat list of check-run
*names*. It has **no path-awareness of its own** — GitHub just waits for a
check run with that exact name to report on the PR's head commit. If the
name never shows up (because the underlying workflow's own `on: pull_request:
paths:` filter didn't match), GitHub doesn't skip it — it sits in the PR's
"Some checks haven't completed yet" state **forever**, and `mergeStateStatus`
reports `BLOCKED`.

That's exactly what happened today: `Regen vs committed` (triggers only on
`generator/**`/`Formula/**`) and `Check .STATUS for conflict markers`
(triggers only on `.STATUS`) are both **required**, but any single PR only
ever touches one of those path sets (or neither). Two live data points from
today:

- PR #162/#163/#166 (`.STATUS`-only) → `Check .STATUS...` ran and passed,
  `Regen vs committed` never started → `BLOCKED` → merged with `--admin`.
- PR #165 (`generator/**`) → `Regen vs committed` ran and passed,
  `Check .STATUS...` never started → but this one went `CLEAN`.

Wait — why did #165 go `CLEAN` but #162 went `BLOCKED`, if both are missing
one of two required checks? Because #165 *also* touched `.STATUS` (every one
of today's PRs did, since they were all `.STATUS`-recording PRs) — so it
happened to satisfy both contexts. A PR that touches `generator/**` *only*
(no `.STATUS` edit) would reproduce the same `BLOCKED` state #162 hit, just
from the other direction. **The gate is currently only reliably satisfiable
by PRs that happen to touch both path sets at once** — which is a narrow and
accidental intersection, not a real property of the workflow design.

So the actual production behavior right now:

| PR touches | `Regen vs committed` | `Check .STATUS...` | Result |
|---|---|---|---|
| `Formula/**` only | ran | never started | BLOCKED |
| `.STATUS` only | never started | ran | BLOCKED |
| both | ran | ran | CLEAN (today's lucky case) |
| neither (e.g. docs, workflow YAML, README) | never started | never started | BLOCKED |

Every single-purpose PR gets blocked. Today's PRs merged "clean" by
coincidence of always bundling a `.STATUS` note with the code change — not
because the gate is actually working as designed.

## The two paths forward

### Option A — Path-filtered, accept `--admin` (current state)

Keep both workflows path-filtered as-is; keep both required. Any PR that
doesn't hit the lucky intersection needs `--admin` to merge on green.

- **Quick win, zero extra work** — already the current state, nothing to do.
- **Cost:** `--admin` bypasses **all** branch protection for that merge, not
  just the missing-check problem — including `enforce_admins`-adjacent
  guarantees. It's a blunt instrument used routinely, which is the opposite
  of what required-checks were added for (SPEC's whole point was "CI red
  should block merges" — an admin override on every other PR erodes that).
- Every future contributor (not just this session) hits the same BLOCKED
  wall and needs to know `--admin` is the sanctioned workaround — that's
  tribal knowledge, not a control.

### Option B — Unconditional triggers, job-level skip (self-skipping)

Remove the `paths:` filter from `on: pull_request:` in both
`formula-drift.yml` and `status-guard.yml` (and drop `Validate all formulas`
from required — already done, correctly, since it's structurally
unfixable via this pattern — it has no PR trigger to begin with, only
`schedule`/`workflow_dispatch`). Add a path-check *inside* the job (e.g.
`dorny/paths-filter` or a plain `git diff --name-only` grep) that exits 0
immediately when the relevant paths weren't touched.

- **Every PR gets a real, fast-completing check result** — no more BLOCKED
  wall, no more `--admin`, ever, for these two checks.
- **Cost:** touches 3 files (`formula-drift.yml`, `status-guard.yml`, plus
  the `.STATUS` doc-only record of the change) instead of one API call.
  Needs its own E2E verification per `e2e-before-pr.md` (a PR that touches
  neither path — genuine skip case — plus one that does, for both
  workflows) before it can be trusted.
- Slightly more moving parts to maintain (a skip-condition in the job,
  rather than relying on the trigger's own `paths:` block) — but this is a
  small, well-known GitHub Actions pattern, not novel risk.

## Recommended Next Step

**→ Option B (self-skipping), because the `--admin` habit is the actual
risk, not the extra workflow-file edits.** Today's session already needed
`--admin` three times in a row (#162, #163, #166) — that's not a one-off
inconvenience, it's the *default* outcome for any PR that doesn't happen to
touch both path sets, and `.STATUS`-only PRs (routine, frequent in this
repo per its own `.STATUS` history) will hit it every time. An admin
override that's routine stops functioning as a safety rail — the SPEC this
whole thread traces back to (`SPEC-release-drift-gates-2026-07-16.md`)
existed specifically to make CI red block merges; a required-but-usually-
bypassed check reproduces the exact gap that SPEC closed, just one layer
down.

Option A is the cheaper immediate choice but only defers the cost — it will
resurface on the next `.STATUS`-only or `generator`-only PR that isn't
bundled with the other path.

## Quick Wins (< 30 min)

1. **Add `dorny/paths-filter`-based skip to `status-guard.yml`** — smaller
   of the two workflows, good first proof of the pattern before touching
   `formula-drift.yml`.

## Medium Effort (1-2 hrs)

- [ ] Apply the same unconditional-trigger + job-skip pattern to
      `formula-drift.yml`.
- [ ] E2E-verify both directions per workflow (path touched → real check;
      path not touched → check still reports, fast, green) before opening
      the PR — required by `e2e-before-pr.md` since this changes CI
      behavior, not just docs.
- [ ] Record the fix in `.STATUS`, same pattern as PRs #162/#163/#166.

## Long-term (future sessions)

- [ ] Reconsider `Validate all formulas` (currently non-required, `schedule`-
      only) — could gain a lightweight `pull_request` trigger scoped to
      `Formula/**` too, if formula-audit-on-PR is ever wanted as a gate.
