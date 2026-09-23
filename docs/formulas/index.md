# Formula Overview

The tap contains 15 formulas and 2 casks, organized into three categories:

## Categories

### 1. Python Virtualenv Formulas

**agy**, **aiterm**, **nexus-cli**, **obsidian-cli-ops**

Use `Language::Python::Virtualenv`, depend on `python@3.12`. Installed via virtualenv patterns.

### 2. Claude Code Plugin Formulas

**craft**, **himalaya-mcp**, **rforge**, **rforge-orchestrator**, **workflow**, **folio**

These are [generated](../generator/index.md) from a single manifest. They share a complex install pattern:

- Files install to `libexec`
- A user-run `<name>-install` script copies the plugin and registers it through its marketplace (`claude_plugin`, e.g. `rforge@data-wise`; else a `local-plugins` marketplace it creates and registers)
- A `<name>-uninstall` script reverses the install
- `post_install` only strips unrecognized `plugin.json` keys (Homebrew's sandbox blocks `~/.claude`); the caveats print the `claude plugin` commands to run

### 3. Simple Install Formulas

**atlas**, **examark**, **flow-cli**, **mcp-bridge**, **scribe-cli**

Direct file installation with minimal logic. Each has its own URL pattern and build steps.

## Audit Status

All 15 formulas pass `brew audit --strict` and `brew style`.

!!! note "Audit reads from tap directory"
    `brew audit` reads formulas from `/opt/homebrew/Library/Taps/data-wise/homebrew-tap/`, not the current working directory. To audit local changes, copy formulas to the tap dir first.
