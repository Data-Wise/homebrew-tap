# Formula Overview

The tap contains 15 formulas and 2 casks, organized into three categories:

## Categories

### 1. Python Virtualenv Formulas

**agy**, **aiterm**, **nexus-cli**

Use `Language::Python::Virtualenv`, depend on `python@3.10` or `python@3.12`. Installed via virtualenv patterns.

### 2. Claude Code Plugin Formulas

**craft**, **himalaya-mcp**, **rforge**, **rforge-orchestrator**, **scholar**, **workflow**

These are [generated](../generator/index.md) from a single manifest. They share a complex install pattern:

- Files install to `libexec`
- A `<name>-install` script handles symlinks, marketplace registration, and settings modification
- A `<name>-uninstall` script reverses the install
- `post_install` strips unrecognized `plugin.json` keys then calls the install script

### 3. Simple Install Formulas

**atlas**, **examark**, **flow-cli**, **mcp-bridge**, **scribe-cli**

Direct file installation with minimal logic. Each has its own URL pattern and build steps.

## Audit Status

All 14 formulas pass `brew audit --strict` and `brew style`.

!!! note "Audit reads from tap directory"
    `brew audit` reads formulas from `/opt/homebrew/Library/Taps/data-wise/homebrew-tap/`, not the current working directory. To audit local changes, copy formulas to the tap dir first.
