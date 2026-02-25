# ORCHESTRATE: Formula Generator Fix — Nested Plugin Dirs + Auto-Install

**Branch:** `feature/generator-fix`
**Base:** `main`
**PR Target:** `main`
**Spec:** `docs/specs/SPEC-formula-generator-fix-2026-02-25.md`

---

## Context

The formula generator produces broken layouts for plugins with nested source dirs (himalaya-mcp). It also lacks the 3-step `post_install` pattern that craft's live formula has (added manually, not through generator). This feature fixes both issues, syncs stale manifest versions, and regenerates all 6 plugin formulas.

---

## Increments

### Increment 1: Generator — Add libexec_copy_map Support
**Estimated:** 20-30 min | **Files:** 1

1. Edit `generator/generate.py`:
   - In `generate_formula()`, after the `libexec_paths` loop (line ~192), add handling for `libexec_copy_map`:
     ```python
     if "libexec_copy_map" in config:
         for src, dest in config["libexec_copy_map"].items():
             lines.append(f'    cp_r "{src}", libexec/"{dest}"')
     if "libexec_copy_map_optional" in config:
         for src, dest in config["libexec_copy_map_optional"].items():
             lines.append(f'    cp_r "{src}", libexec/"{dest}" if (buildpath/"{src}").exist?')
     ```
2. Test with `python3 generator/generate.py himalaya-mcp --diff`
3. Commit: `feat: add libexec_copy_map support to formula generator`

### Increment 2: Generator — Fix post_install 3-Step Pattern
**Estimated:** 30-45 min | **Files:** 1

1. Edit `generator/generate.py` — rewrite `post_install` section (lines ~222-248):
   - For ALL `claude-plugin` type formulas, generate:
     - Step 1: JSON cleanup in own `begin/rescue/end` block
     - Step 2: Run install script with 30s timeout in own `begin/rescue/end` block
     - Step 3: `claude plugin update` in own `begin/rescue/end` block
   - Remove the old branching logic (`if features.get("schema_cleanup")` vs else)
   - The `schema_cleanup` feature flag should control whether Step 1 is included, but Steps 2+3 should always be present
2. Test: `python3 generator/generate.py craft --diff` — verify post_install matches live craft formula
3. Commit: `fix: generate 3-step post_install for all plugin formulas`

### Increment 3: Manifest — Update himalaya-mcp + Sync Versions
**Estimated:** 20-30 min | **Files:** 1

1. Get current live versions:
   ```bash
   for f in craft himalaya-mcp scholar rforge rforge-orchestrator workflow; do
     v=$(brew info data-wise/tap/$f 2>/dev/null | head -1 | awk '{print $3}')
     sha=$(grep sha256 /opt/homebrew/Library/Taps/data-wise/homebrew-tap/Formula/$f.rb | head -1 | awk -F'"' '{print $2}')
     echo "$f: version=$v sha256=$sha"
   done
   ```
2. Edit `generator/manifest.json`:
   - Update himalaya-mcp: version, sha256, libexec_paths, add libexec_copy_map, test_paths, caveats
   - Sync all other formula versions + sha256 to match live
3. Commit: `chore: sync manifest versions and fix himalaya-mcp layout`

### Increment 4: Regenerate + Validate + Test
**Estimated:** 30-45 min | **Files:** 6 (.rb files)

1. Preview: `python3 generator/generate.py --diff`
2. Validate: `python3 generator/generate.py --validate`
3. Generate: `python3 generator/generate.py`
4. Copy to tap: `cp Formula/*.rb /opt/homebrew/Library/Taps/data-wise/homebrew-tap/Formula/`
5. Test himalaya-mcp:
   ```bash
   brew install --build-from-source data-wise/tap/himalaya-mcp
   brew test data-wise/tap/himalaya-mcp
   ls /opt/homebrew/opt/himalaya-mcp/libexec/skills/   # Should show 7 files
   ls /opt/homebrew/opt/himalaya-mcp/libexec/agents/   # Should show 1 file
   ```
6. Audit all:
   ```bash
   for f in Formula/*.rb; do
     name=$(basename "$f" .rb)
     brew audit --strict "data-wise/tap/$name" 2>&1
   done
   ```
7. Verify craft didn't regress: `python3 generator/generate.py craft --diff` should show minimal/no changes
8. Commit: `feat: regenerate all 6 plugin formulas with fixed layout + auto-install`

### Increment 5: PR
**Estimated:** 10 min

1. Push branch
2. Create PR: `gh pr create --base main --title "fix: generator nested dirs + auto-install post_install"`
3. PR body should include before/after for himalaya-mcp layout

---

## Key Files

| File | What Changes |
|------|-------------|
| `generator/generate.py` | Add copy_map support, fix post_install |
| `generator/manifest.json` | Fix himalaya-mcp entry, sync all versions |
| `Formula/himalaya-mcp.rb` | Regenerated — skills at root, auto-install |
| `Formula/craft.rb` | Regenerated — post_install now from generator |
| `Formula/scholar.rb` | Regenerated — version sync + auto-install |
| `Formula/rforge.rb` | Regenerated — version sync + auto-install |
| `Formula/rforge-orchestrator.rb` | Regenerated — version sync + auto-install |
| `Formula/workflow.rb` | Regenerated — version sync + auto-install |

---

## Verification Checklist

- [ ] `python3 generator/generate.py --validate` — all 6 pass
- [ ] himalaya-mcp: `skills/` at libexec root (not `plugin/skills/`)
- [ ] himalaya-mcp: post_install runs install script with timeout
- [ ] craft: post_install matches current live formula behavior
- [ ] craft: branch guard hook still included
- [ ] All 6: `brew audit --strict` passes
- [ ] himalaya-mcp: `brew install --build-from-source` + `brew test` passes

---

## After Merge

1. Existing himalaya-mcp users fix with: `brew update && brew upgrade himalaya-mcp`
2. Proceed to himalaya-mcp docs overhaul (separate PR in himalaya-mcp repo)
3. Proceed to npm publishing (separate PR in himalaya-mcp repo)
