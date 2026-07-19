# SPEC: Self-Skipping Required Checks (fix the path-filtered BLOCKED wall)

**Date:** 2026-07-19 · **Status:** Approved — ready to drive
**Grill:** [GRILL-required-checks-self-skip-2026-07-19.md](GRILL-required-checks-self-skip-2026-07-19.md)
**Brainstorm:** [BRAINSTORM-required-checks-path-filtering-2026-07-19.md](../../BRAINSTORM-required-checks-path-filtering-2026-07-19.md)
**Repo:** `homebrew-tap`
**Related:** [#162](https://github.com/Data-Wise/homebrew-tap/pull/162), [#163](https://github.com/Data-Wise/homebrew-tap/pull/163), [#165](https://github.com/Data-Wise/homebrew-tap/pull/165), [#166](https://github.com/Data-Wise/homebrew-tap/pull/166), [SPEC-release-drift-gates-2026-07-16.md](SPEC-release-drift-gates-2026-07-16.md)

## Problem

`main` branch protection (added 2026-07-19, closing SPEC-release-drift-gates-2026-07-16.md's
deferred open question) requires two check-run contexts: `Regen vs committed`
(`formula-drift.yml`) and `Check .STATUS for conflict markers` (`status-guard.yml`). Both
workflows are triggered by `on: pull_request: paths:` filters scoped to their own concern
(`generator/**`/`Formula/**` and `.STATUS` respectively).

GitHub's required-status-checks has no path-awareness: if a required context never reports
because its workflow's trigger didn't match, GitHub doesn't skip it — it waits forever and
`mergeStateStatus` reports `BLOCKED`. In practice this means:

| PR touches | `Regen vs committed` | `Check .STATUS...` | Result |
|---|---|---|---|
| `Formula/**`/`generator/**` only | ran | never started | BLOCKED |
| `.STATUS` only | never started | ran | BLOCKED |
| both | ran | ran | CLEAN |
| neither (docs, workflow YAML, README, etc.) | never started | never started | BLOCKED |

Three of today's four PRs (#162, #163, #166 — all `.STATUS`-only) hit `BLOCKED` and were merged
via `gh pr merge --admin`, bypassing branch protection entirely for that merge (not just the
missing-check gap). Only #165 went `CLEAN`, and only because it happened to touch both path sets
at once (`generator/**` fix bundled with a `.STATUS` note) — not because the gate worked as
designed. A `generator/**`-only PR would reproduce the same `BLOCKED` wall from the other side.

An admin override that's the routine outcome (not the exception) stops functioning as a safety
rail — it reproduces, one layer down, the exact gap SPEC-release-drift-gates-2026-07-16.md was
written to close (CI red should block merges; here, CI never-ran also fails to block merges,
just via a different mechanism than the original problem).

## Scope

### In scope

- Remove the `paths:` filter from `formula-drift.yml`'s and `status-guard.yml`'s `pull_request`
  triggers (keep `push` triggers as-is — they're not part of the required-checks problem).
- Add a job-level path check inside each workflow (plain `git diff --name-only` against the
  merge-base, matching this repo's existing hand-rolled-bash convention — no new third-party
  action dependency) that exits 0 immediately, without running the real check logic, when the
  relevant paths weren't touched by the PR.
- Both job names (`Regen vs committed`, `Check .STATUS for conflict markers`) stay unchanged —
  no branch-protection API changes needed once this ships; the fix is entirely on the workflow
  side.
- E2E verification (per `e2e-before-pr.md`): for each workflow, one real PR/commit that touches
  the relevant path (real check runs) and one that doesn't (check reports fast + green via the
  skip path) — not just YAML lint.
- `.STATUS` record of the change, same pattern as PRs #162/#163/#166.

### Explicitly out of scope

- `Validate all formulas` — already correctly excluded from required checks (2026-07-19, PR
  #163) because it has no `pull_request` trigger at all (`schedule` + `workflow_dispatch` only).
  Giving it a `pull_request` trigger scoped to `Formula/**` is a separate, later decision
  (flagged as a Long-term item in the brainstorm) — not bundled into this fix.
- Branch-protection API changes — this SPEC is workflow-file-only; the required-contexts list
  (`Regen vs committed`, `Check .STATUS for conflict markers`) does not change.
- Any change to `update-formula.yml` or `docs.yml` — unrelated to this gap.

## Acceptance Criteria

- [ ] A PR touching only `.STATUS` (no `Formula/**`/`generator/**`) shows `Regen vs committed` as
      a completed, green, fast (<30s) check — not "expected/waiting" — and `mergeStateStatus`
      reports `CLEAN` without `--admin`.
- [ ] A PR touching only `Formula/**`/`generator/**` (no `.STATUS`) shows `Check .STATUS for
      conflict markers` as a completed, green, fast check, and merges `CLEAN` without `--admin`.
- [ ] A PR touching neither path set (e.g. a docs-only or workflow-YAML-only change) merges
      `CLEAN` without `--admin`.
- [ ] A PR that *does* touch `Formula/**` with an actual drift bug still fails `Regen vs
      committed` for real (skip logic doesn't accidentally swallow real failures) — planted-defect
      regression test.
- [ ] A PR that *does* introduce a conflict marker in `.STATUS` still fails `Check .STATUS for
      conflict markers` for real — planted-defect regression test.
- [ ] No new third-party GitHub Action dependency introduced (matches existing repo convention of
      hand-rolled bash for this class of check — see `check-revision-bump.sh`,
      `check-status-conflict-markers.sh`).

## Resolution (see grill)

All open questions resolved via [GRILL-required-checks-self-skip-2026-07-19.md](GRILL-required-checks-self-skip-2026-07-19.md):

1. Diff-base resolution: extend `formula-drift.yml`'s existing "Determine revision-drift check
   inputs" step (not a separate one).
2. Fail closed on ambiguity — a diff-resolution error must fail the job, never silently skip.
3. Rollout order: `status-guard.yml` self-skip fix ships first, in its own PR, as a proof of the
   pattern; `formula-drift.yml` follows in a second PR once validated.
4. CI-minutes cost accepted as negligible; noted for a post-rollout glance, not gated on now.
5. `Validate all formulas` PR-trigger question stays explicitly out of scope (separate future
   decision).
