# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Active Work

**Read `ORCHESTRATE-homebrew-refactor.md` in this repo root for the current implementation plan.**

Full spec: `~/projects/dev-tools/craft/docs/specs/SPEC-homebrew-refactor-2026-02-15.md`

**Rebase before every session:** `main` receives automated formula updates. Run `git fetch origin && git rebase origin/main` before starting work. See ORCHESTRATE for conflict resolution rules.

## What This Is

A Homebrew tap (`brew tap data-wise/tap`) distributing CLI tools, Claude Code plugins, and desktop apps. All packages are for macOS.

## Repository Layout

- `Formula/*.rb` — Homebrew formulas (CLI tools, plugins)
- `Casks/*.rb` — Homebrew casks (desktop .app bundles)
- `tests/` — Shell-based test scripts
- `.github/workflows/update-formula.yml` — Reusable workflow called by other repos to auto-update formulas on release

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
- `post_install` strips unrecognized `plugin.json` keys (e.g., `claude_md_budget`) then calls the install script
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

# Audit all formulas at once
for f in Formula/*.rb; do name=$(basename "$f" .rb); brew audit --strict "data-wise/tap/$name" 2>&1; done

# Run shell tests
bash tests/test_craft_install_timeout.sh
```

## Automated Updates

Other Data-Wise repos call `.github/workflows/update-formula.yml` on release. It accepts `formula_name`, `version`, `sha256`, `source_type` (github|pypi), and `auto_merge`. The workflow uses `sed` to update version/SHA in the formula file, then either pushes directly to main or creates a PR. See `.github/WORKFLOW-TEMPLATES.md` for caller-side setup.

## Cask Conventions

Casks use architecture-specific blocks (`on_arm`/`on_intel`) with separate SHA256 hashes and URLs. Include `livecheck`, `conflicts_with` for dev/stable variants, `uninstall quit:`, and `zap trash:` for cleanup paths.

## Version Update Checklist

When manually updating a formula version:
1. Update `url` with new tag/version
2. Update `sha256` (download tarball and `shasum -a 256`)
3. Update version in `test` block's `assert_match` if present
4. Update any version references in `caveats` or `desc` (e.g., command counts)
5. For casks: update both `on_arm` and `on_intel` blocks if applicable
