# Update Formula Workflow

Reusable workflow called by project repos on release.

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `formula_name` | Yes | - | Formula name (e.g., `aiterm`) |
| `version` | Yes | - | Version without `v` prefix |
| `sha256` | Yes | - | SHA256 hash of tarball |
| `source_type` | No | `github` | `github`, `pypi`, `npm`, or `cran` |
| `auto_merge` | No | `false` | PR + GitHub native auto-merge (true) or PR for manual review (false) |
| `command_count` | No | - | Dynamic command count for desc |
| `agent_count` | No | - | Dynamic agent count for desc |
| `skill_count` | No | - | Dynamic skill count for desc |

## Source Types

| Type | URL Pattern | Example |
|------|-------------|---------|
| `github` | `/v{version}.tar.gz` | `/v1.0.0.tar.gz` |
| `pypi` | `/{package}-{version}.tar.gz` | `/nexus_cli-0.5.1.tar.gz` |
| `npm` | `/-/{package}-{version}.tgz` | `/-/examark-0.6.6.tgz` |
| `cran` | `/{package}_{version}.tar.gz` | `/mypackage_1.0.0.tar.gz` |

## Steps

1. Generate GitHub App token (if configured)
2. Checkout homebrew-tap main branch
3. Update version and SHA via `sed` based on source type
4. Run `brew style` (non-blocking)
5. Open a PR against `main` (always — `main`'s branch protection requires a PR, direct pushes
   are rejected regardless of required-approval count). `auto_merge: true` additionally enables
   GitHub's native auto-merge on the PR, so it merges itself once the required checks
   ([Regen vs committed](drift-guard.md), [Check .STATUS for conflict markers](status-guard.md))
   pass — no human click needed, but the checks still gate it.

## Caller Example

```yaml
# In your project's .github/workflows/homebrew-release.yml
name: Update Homebrew Formula
on:
  release:
    types: [published]

jobs:
  update:
    uses: Data-Wise/homebrew-tap/.github/workflows/update-formula.yml@main
    with:
      formula_name: myproject
      version: ${{ github.event.release.tag_name }}
      sha256: ${{ needs.build.outputs.sha256 }}
      source_type: github
      auto_merge: true
    secrets:
      app_id: ${{ secrets.APP_ID }}
      app_private_key: ${{ secrets.APP_PRIVATE_KEY }}
```
