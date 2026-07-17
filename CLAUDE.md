# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A Homebrew tap (`brew tap data-wise/tap`) distributing CLI tools, Claude Code plugins, and desktop apps. All packages are for macOS.

## Repository Layout

- `Formula/*.rb` — 14 Homebrew formulas (CLI tools, plugins)
- `Casks/*.rb` — Homebrew casks (scribe, scribe-dev)
- `generator/` — Python formula generator for plugin formulas
  - `generate.py` — Reads manifest, produces `Formula/*.rb`
  - `manifest.json` — Single source of truth for all 14 formulas
  - `blocks/` — Composable bash/ruby fragments (symlink, schema-cleanup, marketplace, etc.)
- `docs/` — MkDocs Material documentation site (adhd-focus preset)
- `mkdocs.yml` — MkDocs configuration
- `tests/` — Shell-based test scripts
- `.github/workflows/update-formula.yml` — Reusable workflow for auto-updates on release
- `.github/workflows/validate-formulas.yml` — Weekly formula validation
- `.github/workflows/docs.yml` — GitHub Pages deployment (on push to main, docs/** changes)

## Formula Categories

There are three distinct formula patterns in use:

1. **Python virtualenv formulas** (aiterm, nexus-cli): Use `include Language::Python::Virtualenv`, depend on `python@3.12`, install via `venv.pip_install` or `virtualenv_install_with_resources`
2. **Claude Code plugin formulas** (craft, himalaya-mcp, rforge, scholar, workflow, rforge-orchestrator): Install to `libexec`, generate `*-install` and `*-uninstall` bash scripts that symlink into `~/.claude/plugins/`, handle Claude Code running detection and `settings.json` modification
3. **Simple install formulas** (flow-cli, atlas, mcp-bridge, examark): Direct file installation with minimal logic

## Claude Code Plugin Formula Pattern

Plugin formulas share a complex install pattern — when editing one, keep them consistent:

- Files install to `libexec` (including hidden `.claude-plugin` dir)
- A `<name>-install` script handles: symlink creation (3 fallback methods), marketplace manifest registration via `jq`, auto-enable in `settings.json`, Claude-running detection (`lsof`/`pgrep`) to skip file modifications
- A `<name>-uninstall` script reverses the install
- `post_install` uses 3-step pattern: (1) strip unrecognized plugin.json keys in own begin/rescue/end, (2) run install script with 30s timeout, (3) claude plugin update registry sync. Each step is independently error-isolated.
- Use `$(brew --prefix)/opt/<name>/libexec` (stable path) not versioned Cellar paths

## Commands

```bash
# Audit a formula (MUST use tap name, not file path)
brew audit --strict data-wise/tap/aiterm

# Style check (accepts file paths)
brew style Formula/aiterm.rb

# Install from source and test
brew install --build-from-source data-wise/tap/aiterm
brew test data-wise/tap/aiterm

# Audit all formulas (reads from /opt/homebrew/Library/Taps/, NOT worktree)
for f in Formula/*.rb; do name=$(basename "$f" .rb); brew audit --strict "data-wise/tap/$name" 2>&1; done

# To audit worktree changes: copy to tap dir first
cp Formula/*.rb /opt/homebrew/Library/Taps/data-wise/homebrew-tap/Formula/

# Run shell tests
bash tests/test_craft_install_timeout.sh

# Documentation site
mkdocs serve              # Local preview at localhost:8000
mkdocs build --strict     # Build and validate
```

## Formula Generator

7 plugin formulas are generated from `generator/manifest.json`. The generator owns structure; CI owns version/SHA. Key manifest fields include `libexec_copy_map` for directory layout, `extra_scripts` for CLI wrappers, and a `features` object gating optional install-script blocks (`schema_cleanup`, `branch_guard`, `marketplace`, `claude_detection`).

**`features.marketplace` and `features.claude_detection` are required for every `claude-plugin` entry**, not optional extras — omitting either silently drops the corresponding install-script block with no error at generate- or install-time (folio#18: a new entry shipped with no `features` key at all, so `brew install` reported success but never registered the plugin with Claude Code). `tests/test_manifest_required_features.sh` gates this in CI.

```bash
python3 generator/generate.py              # Generate all 7 plugin formulas
python3 generator/generate.py craft        # Generate one formula
python3 generator/generate.py --diff       # Diff vs existing (no overwrite)
python3 generator/generate.py --validate   # Validate output with ruby -c
python3 generator/generate.py --list       # List all formulas in manifest
```

Generated formulas: craft, himalaya-mcp, scholar, rforge, rforge-orchestrator, workflow, folio. The other 8 are hand-crafted (different enough to not benefit from generation).

When editing a plugin formula, edit `manifest.json` + `blocks/` then regenerate — do NOT edit the generated `.rb` directly.

## Automated Updates

Other Data-Wise repos call `.github/workflows/update-formula.yml` on release. It accepts `formula_name`, `version`, `sha256`, `source_type` (github|pypi|npm|cran), and `auto_merge`. The workflow uses `sed` to update version/SHA in the formula file, then either pushes directly to main or creates a PR. Authentication uses the GitHub App "Data-Wise Homebrew Automation" (App ID: 2874502) with PAT fallback.

Weekly validation (`validate-formulas.yml`) runs `brew style` + `ruby -c` on all 14 formulas every Monday at 06:00 UTC.

## Cask Conventions

Casks use architecture-specific blocks (`on_arm`/`on_intel`) with separate SHA256 hashes and URLs. Include `livecheck`, `conflicts_with` for dev/stable variants, `uninstall quit:`, and `zap trash:` for cleanup paths.

- **`depends_on macos:` must use the bare-symbol form** — `depends_on macos: :catalina`, NOT the string-comparison form `depends_on macos: ">= :catalina"`. Homebrew deprecated the string form; a bare symbol already means "this version or newer" (minimum requirement). `brew style` flags the string form.
- Cask templates for desktop apps are emitted by craft's `dist:homebrew` generator (`craft/commands/dist/homebrew.md`). When a cask convention changes, fix that template too — otherwise regenerated casks reintroduce the old form.

## Version Update Checklist

When manually updating a formula version:
1. Update `url` with new tag/version
2. Update `sha256` (download tarball and `shasum -a 256`)
3. Update version in `test` block's `assert_match` if present
4. Update any version references in `caveats` or `desc` (e.g., command counts)
5. For casks: update both `on_arm` and `on_intel` blocks if applicable
