# Caveats Prose Drift — Spec

**Generated:** 2026-08-15
**Context:** homebrew-tap `generator/manifest.json`'s `caveats_extra` prose (shown on `brew
install`/`brew upgrade`) hardcodes counts/feature lists in some formulas — same staleness class
craft's `docs-staleness-check.sh` Phase 7 just fixed inside craft's own docs.
**Status:** brainstormed 2026-08-15 (default depth, arch focus). Not yet grilled.

---

## Problem

`generate.py` has no network/git access to source repos at generation time — it only does
local template substitution on `manifest.json` fields. So the craft-style fix (compare prose
against a live authority inside the same repo) doesn't apply here; there is no live authority
to compare against.

Scan of all 15 formulas' `caveats_extra` found:

| Formula | Issue | Evidence |
|---|---|---|
| himalaya-mcp | Hardcoded "15 email skills" / "22 MCP tools" | Source repo `README.md:7` states **29 MCP tools** — confirmed drift |
| workflow | Hardcoded "3 auto-activating skills" / "8 modes" / "60+ proven design patterns" | Source is a 2024-12-24 v0.1.0 plugin with its own `WORKFLOW-PLUGIN-STATUS.md` gap analysis showing only 1 of 5 documented commands was ever implemented at authoring time — numbers may describe never-shipped features |
| rforge-orchestrator | Hardcoded "0 features", "15 commands" inside a DEPRECATED notice | Low-stakes (notice's job is "stop using this"), but still wrong |
| craft, rforge | `{command_count}` templated | Already safe, no action needed |
| 10 others | empty `caveats_extra` | N/A |

## Decisions (locked from brainstorm)

| # | Decision | Chosen |
|---|----------|--------|
| D1 | Fix mechanism | Manual correction now + new `caveats_verified: <date>` field per formula in `manifest.json`. Rejected: cross-repo live fetch at generation time (too big — new dependency, network/CI implications for a 3-formula problem); template-only with no verification date (silent re-drift, no signal). |
| D2 | rforge-orchestrator (deprecated) | Fix it too — a deprecation notice shouldn't carry wrong numbers even though its job is migration, not description. |
| D3 | workflow formula | Include it, but implementer must re-verify against the **live** `claude-plugins` repo state before writing new numbers — not just bump old numbers to newer-looking ones, and not trust the 1+ year old gap-analysis doc as still-current either. |

## Scope

**In:**
- `generator/manifest.json`: correct `caveats_extra` for himalaya-mcp, workflow, rforge-orchestrator; add `caveats_verified` date field to every formula that has non-empty `caveats_extra` (craft, rforge, himalaya-mcp, workflow, rforge-orchestrator — 5 formulas)
- New `scripts/audit-caveats.sh`: advisory, non-gating, flags any `caveats_verified` date past a staleness threshold (suggest 6 months, confirm during grill)
- Regenerate `Formula/*.rb` for the 3 corrected formulas via `generator/generate.py`
- `homebrew-tap/CLAUDE.md` or `docs/`: brief note on the `caveats_verified` convention

**Out:**
- Cross-repo live-fetch mechanism (D1 rejected it)
- The other 10 formulas with empty `caveats_extra` (nothing to fix)
- Deeper investigation/rebuild of the `workflow` plugin itself — this spec only touches its
  homebrew caveats text, not craft-plugins' `workflow` plugin source
- craft's own `docs-staleness-check.sh` — unrelated repo, already fixed (PR #335)

## Acceptance Criteria

- [ ] himalaya-mcp's caveats state the verified current MCP-tool and skill counts (re-checked
      against the live repo at fix time, not the "29" figure quoted here — that itself could be
      stale by the time this is implemented)
- [ ] workflow's caveats are re-verified against the live `claude-plugins` workflow plugin
      state, not just old-numbers-for-new-numbers
- [ ] rforge-orchestrator's deprecation notice carries corrected counts
- [ ] Every formula with non-empty `caveats_extra` has a `caveats_verified` date field
- [ ] `scripts/audit-caveats.sh` flags a planted-stale fixture and passes a fresh one (positive
      control, not just "runs without error")
- [ ] `generator/generate.py` still produces valid `Formula/*.rb` for all touched formulas —
      `brew audit`/`brew style` clean
- [ ] Advisory only — `audit-caveats.sh` never blocks a release, per D1

## Test Plan

| Tier | Coverage |
|---|---|
| e2e | `audit-caveats.sh` against planted-stale + fresh fixtures |
| dogfood | `generate.py` regen + `brew audit --strict` + `brew style` on all touched formulas |
| negative | revert one formula's corrected count, confirm the audit script's target assertion fails for the documented reason |

## Risks

- **workflow's real current state is the biggest unknown** — needs its own mini-investigation
  during implementation, not just a manifest.json edit. Budget more time for this formula than
  the other two.
- **`caveats_verified` is honor-system** unless the audit script actually checks recency (not
  just presence) — see brainstorm's Risks section.

## Next Step

`/craft:grill docs/specs/SPEC-caveats-prose-drift-2026-08-15.md`
