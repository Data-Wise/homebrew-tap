# BRAINSTORM: Release Drift Gates — Missing Revision Bumps + .STATUS Staleness

**Date:** 2026-07-16 · **Depth:** default · **Focus:** ops

## Context

Two real gaps surfaced today while shipping folio#18's fix ([PR #143](https://github.com/Data-Wise/homebrew-tap/pull/143)):

1. **No gate caught a content-only formula change with no version/revision bump.** #143 edited
   `manifest.json`'s `features` + regenerated `Formula/folio.rb`, but nothing in CI or
   `bump-version.sh` flagged that `brew upgrade` would never detect the change on
   already-installed machines — it took a manual `brew reinstall` + `brew outdated` check
   (post-merge, in a separate session) to notice, then a follow-up fix
   ([PR #147](https://github.com/Data-Wise/homebrew-tap/pull/147)) to add the missing
   `revision: 1`.
2. **`.STATUS` in both `folio` and `homebrew-tap` needed manual, ad-hoc updates** each time —
   including once catching an actual unresolved git-conflict-marker artifact left in
   `homebrew-tap`'s `.STATUS` from a prior stash/pull collision. Nothing flagged that the file
   was stale or malformed until a human happened to open it.

Neither gap is hypothetical or one-off — both are structurally repeatable: any future formula
edit that changes `post_install`/`install` logic without a version bump reproduces gap 1; any
session that forgets (or doesn't know) to update `.STATUS` reproduces gap 2.

## Expert Question Answers (captured from this session)

- **Check location:** homebrew-tap CI (not `/craft:release` alone) — a content-diff gate belongs
  at the source, catching it for every formula regardless of which pipeline touched it.
- **.STATUS handling:** flagged, not auto-written — a human writes the actual entry; the pipeline
  only blocks/reminds on staleness, avoiding generic auto-generated prose and merge-conflict risk
  on a frequently-touched file.

## Option 1: Homebrew-Tap CI — "Revision Drift" Gate

**Approach:** A new CI job (or a check appended to existing `validate-formulas.yml` / a new
`revision-drift-check.yml`) that, on every PR touching `Formula/*.rb` or `generator/manifest.json`:

1. Regenerates all formulas from `generator/manifest.json` at the PR's HEAD.
2. Diffs each regenerated formula against its content at the PR's base ref (`git show
   origin/main:Formula/<name>.rb`).
3. For any formula whose content differs: parse out `version` and `revision` from both sides.
   If `version` is unchanged AND `revision` is unchanged (or absent) AND the content differs in
   any way *other than* whitespace-only/comment-only lines → **FAIL** with a clear message
   naming the exact formula and pointing at `revision: N` as the fix.
4. If `version` bumped, or `revision` bumped, or the only diff is comments/whitespace → pass.

**Why this shape:** it's the same "generate, diff, assert" pattern already used by
`generator/generate.py --diff` and the existing `tests/test_manifest_required_features.sh` /
`test_marketplace_sync_resilience.sh` guards — no new tooling paradigm, just one more structural
assertion in the same family.

**Risk:** comment-only or formatting-only regenerations (e.g. a `desc` string rewrap) would
false-positive without the whitespace/comment exclusion in step 3 — needs a real diff test with
a planted comment-only change to confirm it doesn't fire.

## Option 2: `/craft:release` Step 2 Pre-Flight Addition

**Approach:** For any project releasing via `/craft:release` that also owns a Homebrew
formula (detected via `.craft/homebrew.json` per Step 10's existing detection), add a pre-flight
check: if files under the project's own repo that the formula's `install`/`post_install`
logic depends on changed since the last release tag, but the corresponding `homebrew-tap`
formula's `revision`/`version` didn't change in the same window, warn (not block — craft doesn't
own the tap repo) with the exact manual-fix command.

**Why weaker alone:** only fires when releasing *through* `/craft:release` — doesn't catch a
direct hand-edit to `homebrew-tap` (like #143/#147 both were, from a homebrew-tap-native
session). This is advisory-only value-add, not a substitute for Option 1's hard gate.

## Recommendation: Both, Option 1 as the real gate

Ship Option 1 in `homebrew-tap` as the actual enforcement (catches every path, including direct
manifest/formula edits). Option 2 is a cheap advisory add-on in craft's release pipeline for
projects that release *through* it — lower priority, do it only if Option 1 proves out first.

## Option 3: `.STATUS` Staleness Reminder (not auto-write)

**Approach:** A lightweight check — could live in either repo's `SessionStart`/pre-commit hook
space, or as a `craft:check` addition — that flags (not blocks) when:

- `.STATUS`'s `last_session:` field is more than N days older than the most recent commit to the
  repo, OR
- `.STATUS` contains literal `<<<<<<<` / `=======` / `>>>>>>>` conflict markers (the exact defect
  found and fixed today) — this one **should block**, not just warn, since it's an unambiguous
  file-corruption signal with zero legitimate reason to exist.

**Why not auto-write:** per this session's confirmed preference, a human-authored entry carries
signal (what mattered, why) that a templated auto-entry can't — and `.STATUS` already has a
memory-dedup convention (`memory-write-dedup-guard.md`) that assumes deliberate, single-source
authorship per fact. Auto-writing risks duplicating what a session's actual commit messages
already say.

**Scope for the conflict-marker check specifically:** trivial to implement (`grep -l
'^<<<<<<<\|^=======\|^>>>>>>>' .STATUS`) and has zero false-positive risk — worth doing
regardless of what happens with the broader staleness-age check.

## Risks / Edge Cases

- **Option 1 false positives on legitimate no-bump changes** — e.g. a typo fix in a `desc`
  string that Homebrew's `brew audit` cares about but doesn't affect installed behavior. Needs an
  explicit "cosmetic-only, no revision needed" escape hatch (a magic PR label, or a manifest
  field like `"cosmetic_only": true` on that specific regeneration) rather than forcing every
  formula edit through a revision bump.
- **`.STATUS` age-based staleness check needs a sensible threshold** — too aggressive (e.g. "1
  day") produces noise on quiet repos; too loose (e.g. "30 days") misses real drift. No strong
  opinion yet — this is the kind of judgment call that benefits from real usage data, not
  up-front guessing.
- **Whichever gate ships first should be dogfooded on this exact incident** — replay #143 (no
  revision bump) as the planted-defect positive control for Option 1, replay the conflict-marker
  `.STATUS` state as the positive control for Option 3's blocking half.

## Test Plan

| Tier | What |
|---|---|
| `unit`/`generator` | Option 1: planted-defect test — regenerate a formula with a content-only change and no revision bump, assert the gate fails; regenerate with a revision bump, assert it passes; regenerate with comment-only diff, assert it passes (no false positive). |
| `e2e`/`dogfood` | Replay PR #143's actual diff (content change, no revision) against the new gate — confirm it would have failed before #147 shipped. |
| `unit` | Option 3 conflict-marker check: planted `<<<<<<<` in a scratch `.STATUS`, assert block; clean file, assert pass. |
| `count-cascade` | N/A — no command/skill/agent surface change. |

## Documentation

Doc-impact score below threshold for guide/refcard/demo (internal CI tooling, no user-facing
command). If Option 1 ships, add one paragraph to `homebrew-tap/CLAUDE.md`'s Formula Generator
section (already documents the `features` flag requirement from #143 — this is the same kind of
"required convention" note, same location).

- [ ] Guide — N/A, score <3
- [ ] Refcard — N/A, score <3
- [ ] Demo — N/A, score <3
- [ ] Mermaid — N/A, score <3
- [x] CLAUDE.md paragraph (if Option 1 ships)

## Next Command

If you want to move forward: capture this as a SPEC (`save` action) scoped to Option 1 +
Option 3's conflict-marker check (the two concretely actionable, low-risk items), leaving
Option 2 and the staleness-age threshold as explicitly deferred/open questions rather than
committing to specifics now.
