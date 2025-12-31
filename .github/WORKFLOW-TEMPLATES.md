# Homebrew Tap Workflow Templates

Reusable workflows for automating Homebrew formula updates when releasing new versions.

## Quick Start

### For GitHub Release Tarballs (aiterm, atlas, flow-cli, etc.)

Add this workflow to your repository at `.github/workflows/homebrew-release.yml`:

```yaml
name: Homebrew Release

on:
  release:
    types: [published]
  workflow_dispatch:
    inputs:
      version:
        description: 'Version to release (e.g., 1.0.0)'
        required: true
        type: string
      auto_merge:
        description: 'Auto-merge the formula PR'
        required: false
        type: boolean
        default: true

jobs:
  prepare:
    name: Prepare Release Info
    runs-on: ubuntu-latest
    outputs:
      version: ${{ steps.release.outputs.version }}
      sha256: ${{ steps.release.outputs.sha256 }}

    steps:
      - name: Get version and calculate SHA
        id: release
        run: |
          if [ "${{ github.event_name }}" = "workflow_dispatch" ]; then
            VERSION="${{ github.event.inputs.version }}"
          else
            VERSION="${GITHUB_REF#refs/tags/}"
            VERSION="${VERSION#v}"
          fi

          echo "version=$VERSION" >> $GITHUB_OUTPUT

          # Replace YOUR_REPO with your repo name
          TARBALL_URL="https://github.com/Data-Wise/YOUR_REPO/archive/v${VERSION}.tar.gz"
          SHA256=$(curl -sL "$TARBALL_URL" | shasum -a 256 | cut -d' ' -f1)

          echo "sha256=$SHA256" >> $GITHUB_OUTPUT

  update-homebrew:
    name: Update Homebrew Formula
    needs: prepare
    uses: Data-Wise/homebrew-tap/.github/workflows/update-formula.yml@main
    with:
      formula_name: YOUR_FORMULA  # e.g., aiterm, atlas
      version: ${{ needs.prepare.outputs.version }}
      sha256: ${{ needs.prepare.outputs.sha256 }}
      source_type: github
      auto_merge: ${{ github.event.inputs.auto_merge == 'true' || github.event_name == 'release' }}
    secrets:
      tap_token: ${{ secrets.HOMEBREW_TAP_GITHUB_TOKEN }}
```

### For PyPI Packages (nexus-cli)

```yaml
name: Homebrew Release

on:
  workflow_run:
    workflows: ["Publish to PyPI"]
    types: [completed]
  workflow_dispatch:
    inputs:
      version:
        description: 'Version to release (e.g., 1.0.0)'
        required: true
        type: string

jobs:
  prepare:
    name: Prepare Release Info
    runs-on: ubuntu-latest
    if: ${{ github.event.workflow_run.conclusion == 'success' || github.event_name == 'workflow_dispatch' }}
    outputs:
      version: ${{ steps.release.outputs.version }}
      sha256: ${{ steps.release.outputs.sha256 }}

    steps:
      - name: Get version from PyPI
        id: release
        run: |
          if [ "${{ github.event_name }}" = "workflow_dispatch" ]; then
            VERSION="${{ github.event.inputs.version }}"
          else
            # Get latest version from PyPI
            VERSION=$(curl -s https://pypi.org/pypi/YOUR_PACKAGE/json | jq -r '.info.version')
          fi

          echo "version=$VERSION" >> $GITHUB_OUTPUT

          # Get SHA256 from PyPI
          PACKAGE_NAME="your_package"  # underscore version
          SHA256=$(curl -s "https://pypi.org/pypi/YOUR_PACKAGE/json" | \
            jq -r ".releases[\"$VERSION\"][] | select(.packagetype==\"sdist\") | .digests.sha256")

          echo "sha256=$SHA256" >> $GITHUB_OUTPUT

  update-homebrew:
    name: Update Homebrew Formula
    needs: prepare
    uses: Data-Wise/homebrew-tap/.github/workflows/update-formula.yml@main
    with:
      formula_name: YOUR_FORMULA
      version: ${{ needs.prepare.outputs.version }}
      sha256: ${{ needs.prepare.outputs.sha256 }}
      source_type: pypi
      auto_merge: true
    secrets:
      tap_token: ${{ secrets.HOMEBREW_TAP_GITHUB_TOKEN }}
```

## Required Secrets

Add this secret to each repository that uses the workflow:

| Secret | Description |
|--------|-------------|
| `HOMEBREW_TAP_GITHUB_TOKEN` | GitHub PAT with `repo` scope for Data-Wise/homebrew-tap |

### Creating the Token

1. Go to GitHub → Settings → Developer settings → Personal access tokens → Fine-grained tokens
2. Create token with:
   - Repository access: `Data-Wise/homebrew-tap`
   - Permissions: `Contents: Read and write`, `Pull requests: Read and write`
3. Add as secret in source repository

## Reusable Workflow Parameters

The `update-formula.yml` workflow accepts:

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `formula_name` | Yes | - | Formula name (e.g., `aiterm`) |
| `version` | Yes | - | Version number without `v` prefix |
| `sha256` | Yes | - | SHA256 hash of tarball |
| `source_type` | No | `github` | `github` or `pypi` |
| `auto_merge` | No | `false` | Auto-merge the PR |

## Current Repositories Using This

| Repository | Formula | Source | Auto-merge |
|------------|---------|--------|------------|
| aiterm | `aiterm.rb` | GitHub | Yes (on release) |
| nexus-cli | `nexus-cli.rb` | PyPI | Yes |

## Troubleshooting

### PR Not Auto-merging

1. Check the token has admin access to homebrew-tap
2. Ensure branch protection allows merge without reviews
3. Check the workflow logs for errors

### SHA256 Mismatch

For PyPI packages, resource URLs can change. The formula may need manual updates for dependencies. Use the PyPI API:

```bash
curl -s https://pypi.org/pypi/PACKAGE/json | jq '.urls[] | {filename, digests}'
```
