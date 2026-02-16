# Homebrew Tap Refactor Orchestration Plan

> **Branch:** `feature/homebrew-refactor`
> **Base:** `main`
> **Worktree:** `~/.git-worktrees/homebrew-tap/feature-refactor`
> **Companion:** craft repo worktree at `~/.git-worktrees/craft/feature-homebrew-refactor`
> **Spec:** `~/projects/dev-tools/craft/docs/specs/SPEC-homebrew-refactor-2026-02-15.md`

## Objective

Fix security vulnerabilities, build a Python formula generator, expand CI workflows, and retrofit plugin formulas. Target: all 14 formulas pass `brew audit --strict` (was 1/14, now 14/14 pass `brew style`).

## This Repo's Phases

Only phases that touch this repo are listed. Phases 2 and 6 are craft-only.

| Phase | Increment | Priority | Effort | Status |
|-------|----------|----------|--------|--------|
| 1 | Security & Reliability Fixes | Critical | < 2h | ✅ Complete |
| 3 | Python Formula Generator | High | 4-8h | ✅ Complete |
| 4 | CI Workflow Expansion + GitHub App | Medium | 4-6h | ✅ Complete (except manual App creation) |
| 5 | Retrofit Plugin Formulas | Medium | 2-4h | ✅ Complete |

## Phase 1: Security & Reliability Fixes

**Scope:** Formula fixes in this repo + caller workflow fixes in 7 project repos

### This repo (Formula/*.rb)

- [x] 1.4 Fix bare `rescue` in `Formula/scholar.rb` post_install
- [x] 1.5 Add Claude-running guard to `Formula/rforge-orchestrator.rb` install script
- [x] 1.6 Fix 57 brew audit issues across 13 formulas (auto-fixable subset) → **14/14 pass `brew style`**

### Other repos (caller workflows)

These callers live in their respective project repos, NOT here:

- [x] 1.1 Fix script injection in `aiterm`, `atlas`, `flow-cli` callers (env: indirection) — already done
- [x] 1.2 Standardize SHA: `sha256sum` everywhere (not `shasum -a 256`) — craft was the only holdout, fixed
- [x] 1.3 Add retry + empty-SHA guard to `craft`, `aiterm`, `atlas`, `flow-cli` callers — craft was the only holdout, fixed

**Caller workflow locations:**
- `~/projects/dev-tools/craft/.github/workflows/homebrew-release.yml`
- `~/projects/dev-tools/aiterm/.github/workflows/homebrew-release.yml`
- `~/projects/dev-tools/atlas/.github/workflows/homebrew-release.yml`
- `~/projects/dev-tools/flow-cli/.github/workflows/homebrew-release.yml`

### Live Audit Results (brew audit --strict)

| Formula | Issues | Key Problems |
|---------|--------|-------------|
| craft | 0 | CLEAN |
| scholar | 1 | modifier `if` |
| himalaya-mcp | 2 | redundant begin, annotation |
| rforge | 3 | license order, Array#include?, assert |
| rforge-orchestrator | 2 | assert, caveats order |
| workflow | 9 | redundant version, 6x assert_predicate |
| aiterm | 3 | URL refs/tags, pkgshare |
| atlas | 4 | desc length, dep order, spacing, assert |
| nexus-cli | 3 | PyPI URL, missing libyaml, caveats order |
| examark | 1 | deprecated npm args |
| examify | 1 | deprecated npm args |
| flow-cli | 1 | man page location |
| mcp-bridge | 16 | desc starts with name, whitespace, npm args |
| scribe-cli | 11 | empty SHA, version redundancy, whitespace |

## Phase 3: Python Formula Generator

**Scope:** `generator/` directory in this repo

- [x] 3.1 Create `generator/manifest.json` with all 14 formula entries (JSON, not YAML — stdlib only)
- [x] 3.2 Create composable bash blocks in `generator/blocks/` (9 blocks)
- [x] 3.3 Build `generator/generate.py` (Python 3, stdlib only)
- [x] 3.4 Add `--diff` mode (show changes vs existing formula)
- [x] 3.5 Add validation: `ruby -c` via `--validate` flag
- [x] 3.6 Test: generate all 6 plugin formulas, all pass ruby -c

**Key files (all new):**
```
generator/
  generate.py           # Reads manifest, produces Formula/*.rb
  manifest.yml          # Single source of truth for all 14 formulas
  blocks/               # Composable bash/ruby blocks
    install-header.sh
    schema-cleanup.sh
    symlink.sh
    marketplace.sh
    claude-detection.sh
    branch-guard.sh
    uninstall.sh
```

**Generator principle:** Generator owns structure. CI workflow owns version numbers.

## Phase 4: CI Workflow Expansion + GitHub App

**Scope:** `.github/workflows/` in this repo + 4 project repos

### This repo

- [x] 4.1 Add `npm` and `cran` source types to `update-formula.yml`
- [x] 4.3 Update `update-formula.yml` to use `actions/create-github-app-token@v1`
- [x] 4.5 Create weekly validation workflow (`validate-formulas.yml`)
- [x] 4.6 Add `brew style` step to `update-formula.yml` (non-blocking initially)

### Other repos (new caller workflows)

- [x] 4.4a Create caller for `examark` (pushed via gh API)
- [x] 4.4b Create caller for `mcp-bridge` (pushed via gh API)
- [x] 4.4c Create caller for `rforge-orchestrator` (claude-plugins monorepo, pushed via gh API)
- [x] 4.4d Create caller for `workflow` (claude-plugins monorepo, pushed via gh API)

### GitHub App setup (manual)

- [ ] 4.2 Create GitHub App "Data-Wise Homebrew Automation" (Contents + PR permissions)

## Phase 5: Retrofit Plugin Formulas

**Scope:** `Formula/` in this repo

- [x] 5.1 Generate `craft.rb` from manifest, diff and merge
- [x] 5.2 Generate `scholar.rb`, fix bare rescue, add schema cleanup
- [x] 5.3 Generate `rforge.rb` (head-only, no versioned releases)
- [x] 5.4 Rewrite `workflow.rb` from old-gen (cp -r) to new patterns
- [x] 5.5 Verify all 6 plugin formulas pass `brew style` (14/14 total)
- [x] 5.6 Test with `brew install --build-from-source` locally (scholar + craft verified)

**Reference formula:** `Formula/himalaya-mcp.rb` (gold standard — passes audit, has all patterns)

## Codified Patterns (from himalaya-mcp)

1. **macOS Sandbox**: `post_install` CANNOT write to `$HOME`. All symlink/registration in install script.
2. **Schema Cleanup**: Dual defense — Ruby `JSON.parse` + `slice(*allowed_keys)` in `post_install`, Python one-liner fallback in install script.
3. **Claude Detection**: `pgrep -x "claude"` before modifying `settings.json`.
4. **Marketplace Registration**: Symlink + manifest + settings.json auto-enable.
5. **Retry + SHA Guard**: 5 attempts, check against empty-file SHA, 15s backoff.

## Acceptance Criteria (this repo)

- [x] All 14 formulas pass `brew style` (14/14)
- [x] All 14 formulas pass `brew audit --strict` (14/14)
- [x] Python generator produces valid formulas for 6 plugin archetypes
- [x] Weekly validation workflow created (`validate-formulas.yml`)
- [x] `update-formula.yml` supports github, pypi, npm, cran sources

## What's Left — This Branch Only

| Task | Status | Notes |
|------|--------|-------|
| ~~4.3 GitHub App token in workflow~~ | **Done** | Workflow supports both App + PAT fallback |
| ~~5.6 Local build-from-source test~~ | **Done** | scholar + craft verified |
| ~~Rebase on main~~ | **Done** | Up to date |
| ~~`brew audit --strict` all 14~~ | **Done** | 14/14 pass |
| ~~4.4a-d Caller workflows~~ | **Done** | Pushed to 3 repos via gh API |

**Not this branch** (manual):
- 4.2 Create GitHub App (manual, github.com UI)

## Rebase Strategy (CRITICAL)

`main` receives automated formula updates (version bumps, SHA changes) from CI callers. The feature branch MUST stay rebased to avoid merge conflicts.

**Before every work session:**
```bash
cd ~/.git-worktrees/homebrew-tap/feature-refactor
git fetch origin
git rebase origin/main
```

**If a conflict occurs during rebase:**
- Version/SHA conflicts: accept `main`'s values (CI owns those fields)
- Structural conflicts (install method, test block): accept feature branch's values (we own structure)
- When in doubt: `git rebase --abort` and ask

**After completing a batch of work:**
```bash
git fetch origin
git rebase origin/main
# Verify: brew audit --strict on changed formulas still passes
```

**Rule:** Never let the feature branch drift more than a few days from main without rebasing.

## Session Instructions

### Context

You are working in the `homebrew-tap` repo — the Homebrew tap containing 14 formulas for Data-Wise projects. This is a cross-repo refactor; the companion craft repo handles command/skill changes (Phases 2, 6). Your job here is Phases 1, 3, 4, 5.

**Spec location:** `~/projects/dev-tools/craft/docs/specs/SPEC-homebrew-refactor-2026-02-15.md` — read it for full architectural details, manifest schema, and generator design.

**Brainstorm location:** `~/projects/dev-tools/craft/docs/brainstorm/BRAINSTORM-homebrew-refactor-2026-02-15.md` — has decision rationale and all expert Q&A.

### How to Start

```bash
cd ~/.git-worktrees/homebrew-tap/feature-refactor
claude
```

CLAUDE.md points here automatically. On session start, paste:

> First, rebase on main: `git fetch origin && git rebase origin/main`. Then read `ORCHESTRATE-homebrew-refactor.md` and the spec at `~/projects/dev-tools/craft/docs/specs/SPEC-homebrew-refactor-2026-02-15.md`. Start Phase 1 — fix brew audit issues formula-by-formula.

### Phase 1 Instructions (Security & Reliability — start here)

**Goal:** Fix brew audit issues across 13 formulas + fix bare rescue + add Claude guard.

**Step-by-step:**

1. **Run `brew audit --strict` on each formula** to get current errors:
   ```bash
   brew audit --strict Formula/<name>.rb 2>&1
   ```

2. **Fix audit issues formula-by-formula** starting with lowest count:
   - `scholar.rb` (1 issue) — modifier `if` style
   - `examark.rb` (1 issue) — deprecated npm args
   - `examify.rb` (1 issue) — deprecated npm args
   - `flow-cli.rb` (1 issue) — man page location
   - `himalaya-mcp.rb` (2 issues) — redundant begin, annotation
   - `rforge-orchestrator.rb` (2 issues) — assert, caveats order
   - `rforge.rb` (3 issues) — license order, Array#include?, assert
   - `aiterm.rb` (3 issues) — URL refs/tags, pkgshare
   - `nexus-cli.rb` (3 issues) — PyPI URL, missing libyaml, caveats order
   - `atlas.rb` (4 issues) — desc length, dep order, spacing, assert
   - `workflow.rb` (9 issues) — redundant version, 6x assert_predicate
   - `scribe-cli.rb` (11 issues) — empty SHA, version redundancy, whitespace
   - `mcp-bridge.rb` (16 issues) — desc starts with name, whitespace, npm args

3. **Fix bare `rescue` in `scholar.rb`** (task 1.4):
   - Find the bare `rescue` in `post_install` and wrap each independent step in its own `begin/rescue/end` block
   - Reference: `himalaya-mcp.rb` post_install for the correct pattern

4. **Add Claude-running guard to `rforge-orchestrator.rb`** (task 1.5):
   - Add `pgrep -x "claude"` check before modifying `settings.json` in the install script
   - Pattern from himalaya-mcp:
     ```bash
     CLAUDE_RUNNING=false
     if pgrep -x "claude" >/dev/null 2>&1; then
         CLAUDE_RUNNING=true
     fi
     # Skip auto-enable if Claude is running
     ```

5. **Verify all fixes:** Re-run `brew audit --strict` on each changed formula

6. **Commit per-formula or in logical groups** using conventional commits:
   ```
   fix(scholar): wrap post_install steps in individual rescue blocks
   fix(formulas): resolve brew audit issues across 13 formulas
   feat(rforge-orchestrator): add Claude-running guard to install script
   ```

**After Phase 1 in this repo**, the caller workflow fixes (tasks 1.1-1.3) need to happen in 4 separate project repos. Those are small targeted fixes — read the caller at each path and apply:
- **Script injection fix**: Move `${{ github.event.inputs.version }}` from `run:` to `env:` block
- **SHA standardization**: Replace `shasum -a 256` with `sha256sum`
- **Retry + empty-SHA guard**: Add the 5-attempt retry loop from the Codified Patterns section

### Phase 3 Instructions (Python Formula Generator)

**Goal:** Build `generator/` that produces valid Ruby formulas from a YAML manifest.

**Read the spec first** — it has the full manifest schema and block composition design.

**Key decisions:**
- Python 3, stdlib only (no dependencies)
- Generator owns structure (Ruby class, install method, test block, install script)
- CI workflow owns version numbers (url, sha256, version — updated via sed)
- Generate only 5 plugin formulas (craft, scholar, rforge, workflow, himalaya-mcp)
- Other 9 formulas are different enough to stay hand-crafted
- `--diff` mode shows changes vs existing formula without overwriting

**Reference:** `Formula/himalaya-mcp.rb` is the gold standard — all 5 codified patterns are present.

**Build order:**
1. `manifest.yml` — define all 14 formula entries (even hand-crafted ones need metadata)
2. `blocks/*.sh` — composable bash fragments (schema-cleanup, symlink, marketplace, claude-detection, etc.)
3. `generate.py` — reads manifest + blocks, outputs Formula/*.rb
4. Test: generate all 5 plugin formulas, diff against existing, iterate until clean
5. Add `ruby -c` syntax validation on generated output

### Phase 4 Instructions (CI Expansion)

**Goal:** Expand `update-formula.yml` with npm/cran sources, create 4 new callers, add weekly validation.

**Key decisions:**
- GitHub App creation is manual (task 4.2) — do it via github.com UI
- New source types: `npm` (tgz URL pattern), `cran` (tar.gz URL pattern)
- Weekly validation: `validate-formulas.yml` on `macos-latest`, runs `brew audit --strict` on all 14
- `brew audit --strict` step in `update-formula.yml` should be non-blocking initially (`continue-on-error: true`)

### Phase 5 Instructions (Retrofit Formulas)

**Goal:** Use the Phase 3 generator to produce updated formulas, diff/merge with existing.

**Prerequisites:** Phase 3 generator must be working first.

**Order:**
1. `craft.rb` — already passes audit, so diff should be clean
2. `scholar.rb` — Phase 1 fixes bare rescue, Phase 5 adds schema cleanup
3. `rforge.rb` — needs release tagging first (may be blocked)
4. `workflow.rb` — full rewrite from old cp-r pattern to new generator output

### Commit Strategy

- Atomic commits per formula or logical group
- Conventional commit format: `fix:`, `feat:`, `refactor:`, `chore:`
- One commit per audit fix batch is fine (e.g., `fix(formulas): resolve brew audit issues`)
- Generator work gets its own commits: `feat(generator): add manifest.yml`, etc.

### Verification

After each phase, run:
```bash
# Count passing formulas
pass=0; fail=0; for f in Formula/*.rb; do brew audit --strict "$f" >/dev/null 2>&1 && ((pass++)) || ((fail++)); done; echo "Pass: $pass  Fail: $fail"
```

Target: 14/14 pass by end of Phase 5.
