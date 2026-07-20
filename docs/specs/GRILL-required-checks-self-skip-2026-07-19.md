# GRILL: Self-Skipping Required Checks

**Date:** 2026-07-19 · **Target:** [SPEC-required-checks-self-skip-2026-07-19.md](SPEC-required-checks-self-skip-2026-07-19.md)
**Brainstorm:** [BRAINSTORM-required-checks-path-filtering-2026-07-19.md](https://github.com/Data-Wise/homebrew-tap/blob/ba80d91/BRAINSTORM-required-checks-path-filtering-2026-07-19.md) (removed from the working tree 2026-07-20 as stale — fully superseded by this SPEC + GRILL)

## Decision Ledger

### 1. Diff-base resolution for the skip check (weakest recommendation)

**Decision:** Extend `formula-drift.yml`'s existing "Determine revision-drift check inputs" step
rather than writing a separate minimal one.

**Reasoning:** That step already hardened PR-vs-push event branching (reads
`$GITHUB_EVENT_PATH` via `jq`, all-zeros sentinel for new branches) for the revision-bump check.
Reusing it gives the skip-check and the revision-bump check one shared source of truth for "what
changed" — avoids a second, potentially-divergent copy of event-type branching logic in the same
file.

**Consequence accepted:** Touches an already-delicate step; needs careful review so the skip-path
addition doesn't regress the revision-bump logic it currently serves alone. `status-guard.yml` has
no equivalent existing step (it's a much simpler workflow), so this specific risk doesn't apply
there — see Decision 3.

### 2. Silent-skip safety (riskiest assumption)

**Decision:** Fail closed on ambiguity. If the diff-base/path resolution itself errors (can't
determine base ref, event payload malformed, etc.), the job **fails**, never silently skips.
"I don't know what changed" must never be treated as "nothing changed."

**Reasoning:** A required check that's always green because its own skip-detection is silently
broken is worse than today's loud `BLOCKED` wall — it looks like coverage while providing none.

**Consequence accepted / promoted to Acceptance Criteria:** The SPEC's existing planted-defect
Acceptance Criteria (a real `Formula/**` drift bug still fails `Regen vs committed`; a real
`.STATUS` conflict marker still fails its check) now double as the CI-enforced regression test for
this fail-closed invariant — not just a manual PR-time spot check.

### 3. Rollout order (implementation regret)

**Decision:** Ship `status-guard.yml`'s self-skip fix first, in its own PR, before touching
`formula-drift.yml`.

**Reasoning:** `status-guard.yml` is small and has no pre-existing delicate multi-branch logic —
it's the cheap place to validate the self-skip pattern (both directions: path touched → real
check runs; path not touched → fast green skip) end-to-end. If the pattern itself has a flaw,
it surfaces here first, before it's combined with the already-fragile
"Determine revision-drift check inputs" step in `formula-drift.yml` (Decision 1).

**Consequence accepted:** Two PRs instead of one; a brief window where only one of the two
required checks is fixed (the other still hits the `BLOCKED`-on-`.STATUS`-only-PR /
`BLOCKED`-on-`Formula`-only-PR wall from the opposite direction than before, until the second PR
lands).

### 4. CI-minutes blast radius

**Decision:** Proceed as scoped; explicitly note to glance at CI-minutes usage a few weeks after
rollout, not gate the change on it now.

**Reasoning:** `formula-drift.yml` moving from paths-filtered to unconditional `pull_request`
means it now runs (briefly) on every PR, including automation-generated ones (e.g. craft's
`homebrew-release.yml` auto-merge PRs). A `git diff --name-only` + exit is sub-second; this repo's
PR volume and CI-minutes budget don't currently make this a real cost.

**Consequence accepted:** No monitoring mechanism added — this is a manual "keep an eye on it"
note, not a metric or alert. Acceptable given the repo's small scale; revisit only if PR volume or
CI cost materially changes.

### 5. Scope boundary — `Validate all formulas`

**Decision:** Confirmed out of scope. `Validate all formulas` stays without a `pull_request`
trigger; giving it one (to make it a real per-PR formula-audit gate) is a separate, later design
decision, not folded into this SPEC.

**Reasoning:** It's a heavier macOS job historically shaped as a weekly cron check, not a PR gate
— whether every PR should run a full formula-audit is a different question than "make the two
already-required checks self-skip correctly." Bundling it would grow this SPEC's diff and defer
shipping the two already-designed fixes.

**Consequence accepted:** The brainstorm's Long-term item (`Validate all formulas` PR-scoped
trigger) remains open and unscheduled — no regression, just explicitly not addressed here.

## Open Questions

None remaining — all 5 branches from the SPEC's "Open Questions" section and grill's attack
angles resolved above. `Validate all formulas` PR-trigger question is explicitly deferred (Decision
5), not unresolved.

## Handoff

SPEC status should move from "Draft — grill before driving" to "Approved — ready to drive."
Suggested next step: `/craft:plan docs/specs/SPEC-required-checks-self-skip-2026-07-19.md` (or
implement directly per the rollout order in Decision 3 — `status-guard.yml` first, own PR,
E2E-verified per its Acceptance Criteria, before touching `formula-drift.yml`).
