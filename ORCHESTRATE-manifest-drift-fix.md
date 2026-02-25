# ORCHESTRATE: Fix Manifest Version Drift in CI

**Branch:** `feature/manifest-drift-fix`
**Base:** `main`
**PR Target:** `main`
**Repo:** homebrew-tap

---

## Context

CI workflow `update-formula.yml` updates version/SHA256 in `.rb` files via `sed` but never touches `generator/manifest.json`. Over time, the manifest drifts behind live versions (craft was 9 versions behind in PR #99).

---

## Increments

### Increment 1: Add manifest.json update step to CI workflow
**File:** `.github/workflows/update-formula.yml` (after line ~184)

Add conditional step using `jq` to update manifest for generated formulas only:

```yaml
    - name: Update manifest.json (generated formulas only)
      run: |
        MANIFEST="generator/manifest.json"
        if ! jq -e ".formulas[\\"$FORMULA_NAME\\"]" "$MANIFEST" >/dev/null 2>&1; then
          echo "Not in manifest (hand-crafted) -- skipping"
          exit 0
        fi
        jq --arg name "$FORMULA_NAME" --arg ver "$VERSION" --arg sha "$SHA256" \
           '.formulas[$name].version = $ver | .formulas[$name].sha256 = $sha' \
           "$MANIFEST" > tmp.json && mv tmp.json "$MANIFEST"
```

Also update `git add` line (207) to include `generator/manifest.json`.

### Increment 2: Test with dry run
1. Verify `jq -e '.formulas["craft"]'` finds generated formulas
2. Verify `jq -e '.formulas["aiterm"]'` correctly skips hand-crafted
3. Test version/SHA update produces valid JSON
4. Verify idempotent re-runs

### Increment 3: Update docs
- Update CLAUDE.md to note CI keeps manifest in sync
- Update docs/ci/update-formula.md if it exists

---

## Risk Assessment

| Risk | Mitigation |
|------|------------|
| `jq` not on runner | `ubuntu-latest` includes it |
| Malformed JSON | tmp file + mv (atomic write) |
| Hand-crafted formula triggers update | `jq -e` early exit |

---

## Verification Checklist

- [ ] Only 6 generated formulas trigger manifest update
- [ ] 8 hand-crafted formulas skip cleanly
- [ ] Version + SHA256 updated correctly
- [ ] `git add` includes `generator/manifest.json`
- [ ] Idempotent re-runs handled
