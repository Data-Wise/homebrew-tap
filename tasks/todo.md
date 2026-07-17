# Task List: Release Drift Gates

Full context/rationale in `tasks/plan.md`. Spec: `docs/specs/SPEC-release-drift-gates-2026-07-16.md`.

## Task 1: Fix checkout depth in `formula-drift.yml`

**Description:** `actions/checkout@v4` in this workflow currently defaults to `fetch-depth: 1`
(no history) — Task 2's diff script can't reach the base ref without it. Fix this first, alone,
before writing any diff logic that depends on it.

**Acceptance criteria:**
- [ ] `formula-drift.yml`'s checkout step sets a fetch depth sufficient for both trigger types:
      `pull_request` (needs the PR's base commit) and `push` (needs `github.event.before`) —
      `fetch-depth: 0` is the simplest correct choice for a repo this size; a narrower depth is
      acceptable if justified in the commit message
- [ ] Existing `check-drift.sh` and `test_no_symlink_install.sh` steps in the same job still pass
      unchanged (this task touches only the checkout step)

**Verification:**
- [ ] `gh run list --repo Data-Wise/homebrew-tap --workflow formula-drift.yml --limit 1` shows a
      green run on a throwaway PR after this change lands
- [ ] Manual check: `git log --oneline | wc -l` inside the CI run's logs (add a debug echo
      temporarily, or check the checkout step's own log output) shows more than 1 commit fetched

**Dependencies:** None

**Files likely touched:**
- `.github/workflows/formula-drift.yml`

**Estimated scope:** XS (1 file, one line)

---

## Task 2: Write `check-revision-bump.sh` (minimal — no cosmetic filter, no label escape hatch)

**Description:** New script, sibling to `generator/check-drift.sh`, following its structure
(`set -euo pipefail`, numbered exit codes, restore-working-tree-on-exit). Takes a base ref and a
head ref (or defaults to `HEAD` + `git merge-base`), regenerates nothing itself — it diffs the
**committed** `Formula/*.rb` files between the two refs directly (no regeneration needed, unlike
`check-drift.sh` — this script compares two already-committed states, not committed-vs-regen).
For any formula that differs at all, parse `version`/`revision` from both refs; fail if both are
unchanged.

**Acceptance criteria:**
- [ ] Script accepts two ref arguments (or sensible defaults), diffs `Formula/*.rb` between them
- [ ] For each differing formula, extracts `version "X"` and `revision N` (regex against the
      Ruby source, same style as `post_install_check.py`'s `_extract_def_body` pattern in craft)
- [ ] Fails (exit 1) if version AND revision are both unchanged for any differing formula, naming
      the formula and suggesting `revision: N` in `generator/manifest.json` as the fix
- [ ] Passes (exit 0) if version or revision changed, or if no formula differs at all

**Verification:**
- [ ] Local dry run against two real refs (e.g. `4bd7402` and `5c084759` — the pre/post #143
      commits) reproduces the exact gap this SPEC exists to catch: script reports FAIL for
      `folio.rb`
- [ ] Same script against `5c084759` and the post-#147 commit reports PASS (revision bumped)

**Dependencies:** Task 1 (needs the fetch-depth fix to be meaningful in CI, though this task's
own local dev/testing doesn't strictly require it)

**Files likely touched:**
- `generator/check-revision-bump.sh` (new)

**Estimated scope:** S (1 file)

---

## Task 3: Comment/whitespace-only diff exclusion

**Description:** Extend Task 2's script so a diff consisting only of Ruby comments (`# ...` at
the top level) or embedded-bash comments (`# ...` inside the `install`/`post_install` heredocs)
doesn't trigger a failure. This is the adversarial review's flagged risk — the generated file
nests two comment syntaxes in one text blob.

**Acceptance criteria:**
- [ ] A diff where every changed line matches `^\s*#` (in either syntax context) is treated as
      "no meaningful change" — script passes even without a version/revision bump
- [ ] A diff that changes even one non-comment line still fails as before (Task 2's behavior
      unchanged for real changes)

**Verification:**
- [ ] Planted test: craft a synthetic `Formula/*.rb` diff that only rewraps a bash comment inside
      the `post_install` heredoc — script passes
- [ ] Planted test: craft a diff that changes one line of actual bash logic — script still fails
      (regression check against Task 2's core behavior)

**Dependencies:** Task 2

**Files likely touched:**
- `generator/check-revision-bump.sh`

**Estimated scope:** S (1 file, adds a filter function)

---

## Task 4: `revision-exempt` PR-label escape hatch

**Description:** Allow a PR to bypass the revision-bump requirement via a `revision-exempt`
GitHub label — checked at CI-run time via `github.event.pull_request.labels`, never stored in the
manifest or codebase (per the plan's "scoped per-PR, not a standing flag" decision).

**Acceptance criteria:**
- [ ] The new workflow step (Task 5) passes the PR's labels into the script (env var or CLI arg)
- [ ] Script exits 0 without checking version/revision at all if `revision-exempt` is present
- [ ] `push` events (no labels available) never see this bypass — label-based exemption only
      applies to `pull_request`-triggered runs

**Verification:**
- [ ] Real PR test: apply `revision-exempt` to a throwaway PR with a content-only, no-bump
      formula change — CI passes
- [ ] Same PR content without the label — CI fails (confirms the label is what's doing the work,
      not an accidental universal pass)

**Dependencies:** Task 2 (script must exist first); loosely coupled to Task 5 (needs the
workflow step to actually pass label data in)

**Files likely touched:**
- `generator/check-revision-bump.sh`
- `.github/workflows/formula-drift.yml`

**Estimated scope:** XS (small addition to an existing script + workflow step)

---

## Task 5: Wire the new step into `formula-drift.yml`

**Description:** Add a step to the existing "Regen vs committed" job that runs
`check-revision-bump.sh`, passing the base/head refs and PR label data.

**Acceptance criteria:**
- [ ] New step added after the existing `check-drift.sh` step, same job
- [ ] Correctly derives base ref for both `pull_request` (`github.event.pull_request.base.sha`)
      and `push` (`github.event.before`) trigger types
- [ ] No new workflow file created (per the SPEC's corrected integration point)

**Verification:**
- [ ] `formula-drift.yml`'s YAML is valid (`yamllint` or GitHub's own validation on push)
- [ ] A real throwaway PR triggers both the existing `check-drift.sh` step and the new step in
      the same job run

**Dependencies:** Task 1, Task 2 (Task 4's label-passing can land in the same step or a fast
follow — doesn't block this task's core wiring)

**Files likely touched:**
- `.github/workflows/formula-drift.yml`

**Estimated scope:** XS (1 file, one step block)

---

## Task 6: `tests/test_revision_bump_check.sh` — planted-defect suite

**Description:** New test file, following the naming/structure of
`tests/test_manifest_required_features.sh`. Exercises Tasks 2-4's behavior locally (not a CI
integration test — this validates the script directly against synthetic fixtures).

**Acceptance criteria:**
- [ ] Case: content changed, no bump → script fails
- [ ] Case: content changed, revision bumped → script passes
- [ ] Case: comment-only diff, no bump → script passes (Task 3)
- [ ] Case: content changed, no bump, but PR has `revision-exempt` → script passes (Task 4,
      mocked label input)
- [ ] Case: no diff at all → script passes trivially

**Verification:**
- [ ] `bash tests/test_revision_bump_check.sh` — all 5 cases pass
- [ ] Added to whatever CI job runs the existing shell test suite (confirm it's actually invoked,
      not just present on disk)

**Dependencies:** Tasks 2, 3, 4 (tests the combined behavior)

**Files likely touched:**
- `tests/test_revision_bump_check.sh` (new)

**Estimated scope:** S (1 file, 5 fixture cases)

---

## Task 7: Dogfood replay of PR #143

**Description:** Prove the gate would have caught the actual incident. Concrete SHAs: base =
`4bd7402` (pre-#143, last known-good main), head = `5c084759` (PR #143's merge commit, the
content-changed-no-revision-bump state).

**Acceptance criteria:**
- [ ] Running `check-revision-bump.sh 4bd7402 5c084759` locally reports FAIL for `folio.rb`
- [ ] Running it again with head = the post-#147 commit (revision bumped) reports PASS

**Verification:**
- [ ] Both runs' actual output pasted into the eventual PR body as evidence (per this session's
      own e2e-before-pr convention — quote the transcript, don't just assert it passed)

**Dependencies:** Task 2 (minimum), ideally after Task 3 too so the replay reflects final behavior

**Files likely touched:** None (this is a verification run, not a code change)

**Estimated scope:** XS (no files — a documented CLI run)

---

## Task 8: `.STATUS` conflict-marker guard script + test

**Description:** Independent of Tasks 1-7. New script that fails if `.STATUS` contains a literal
`<<<<<<<`, `=======`, or `>>>>>>>` line.

**Acceptance criteria:**
- [ ] `grep -n '^<<<<<<<\|^=======\|^>>>>>>>' .STATUS` (or equivalent) — non-empty match → exit 1
      with the matching line numbers named
- [ ] Clean file → exit 0
- [ ] Planted-defect test: scratch copy of `.STATUS` with an injected conflict block → fails;
      unmodified `.STATUS` → passes

**Verification:**
- [ ] `bash generator/check-status-conflict-markers.sh` (or wherever it lands) run locally against
      both a planted-defect scratch file and the real `.STATUS`

**Dependencies:** None (fully independent of Phase 1-3)

**Files likely touched:**
- New script (exact path TBD — `generator/` for consistency with sibling scripts, or a
  repo-root `scripts/` if that convention is preferred at implementation time)
- New test file

**Estimated scope:** XS (trivial grep-based check, per the SPEC's own risk assessment)

---

## Task 9: Wire the `.STATUS` guard into CI

**Description:** No existing workflow currently touches `.STATUS` — decide the home (new
lightweight workflow triggered on any push/PR touching `.STATUS`, or a step folded into
`validate-formulas.yml`'s weekly cron) and wire it in.

**Acceptance criteria:**
- [ ] Guard runs automatically on any PR/push that touches `.STATUS`
- [ ] A throwaway PR with a planted conflict marker in `.STATUS` shows the check failing in the
      GitHub PR checks UI

**Verification:**
- [ ] Real PR test, same as Task 5's verification pattern

**Dependencies:** Task 8

**Files likely touched:**
- New or existing `.github/workflows/*.yml` (decision made at implementation time)

**Estimated scope:** XS (1 file, small addition)

---

## Task 10: `CLAUDE.md` documentation

**Description:** One paragraph in the Formula Generator section covering the revision-drift gate
and the `revision-exempt` label escape hatch — same location/convention as the existing
`features`-flag-requirement paragraph added after #143.

**Acceptance criteria:**
- [ ] Paragraph explains: what triggers the gate, what `revision-exempt` does and its audit-trail
      caveat (per `tasks/plan.md`'s Risks table), where the script lives
- [ ] Placed adjacent to the existing `features` flag paragraph, not a disconnected new section

**Verification:**
- [ ] Read-through: could a future contributor who hits this gate for the first time find the fix
      without asking anyone, using only this paragraph?

**Dependencies:** Tasks 1-5 (documents the shipped behavior, not the plan)

**Files likely touched:**
- `CLAUDE.md`

**Estimated scope:** XS (prose only)
