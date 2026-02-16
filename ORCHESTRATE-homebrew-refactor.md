# Homebrew Tap Refactor Orchestration Plan

> **Status:** ✅ COMPLETE — Merged to main via PR #91 on 2026-02-16
> **Branch:** `feature/homebrew-refactor` (deleted)
> **Worktree:** removed
> **PR:** https://github.com/Data-Wise/homebrew-tap/pull/91

## Objective

Fix security vulnerabilities, build a Python formula generator, expand CI workflows, and retrofit plugin formulas. Target: all 14 formulas pass `brew audit --strict`.

**Result:** 14/14 formulas pass `brew audit --strict`. All phases complete.

## Phases

| Phase | Increment | Status |
|-------|----------|--------|
| 1 | Security & Reliability Fixes | ✅ Complete |
| 3 | Python Formula Generator | ✅ Complete |
| 4 | CI Workflow Expansion + GitHub App | ✅ Complete |
| 5 | Retrofit Plugin Formulas | ✅ Complete |
| — | Code review fixes | ✅ Complete |

## What Shipped

- **54+ brew audit issues fixed** across all 14 formulas
- **Formula generator** (`generator/generate.py` + `manifest.json` + 9 composable blocks)
- **6 plugin formulas** retrofitted via generator (craft, himalaya-mcp, rforge, rforge-orchestrator, scholar, workflow)
- **CI/CD**: npm/cran source types, GitHub App auth (App ID: 2874502), weekly `brew audit --strict` validation
- **MkDocs documentation site** with adhd-focus preset
- **CLAUDE.md** and **README** updated

## Remaining Items

- [ ] Replace scribe-cli placeholder SHA when v0.3.0 release is created
- [ ] Verify GitHub Pages deploys docs site after merge
- [ ] Verify update-formula workflow uses App token correctly
