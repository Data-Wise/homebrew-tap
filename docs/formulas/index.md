# Formula Overview

The tap contains 14 formulas and 2 casks, organized into three categories:

## Categories

### 1. Python Virtualenv Formulas

**aiterm**, **nexus-cli**

Use `Language::Python::Virtualenv`, depend on `python@3.12`. Installed via `venv.pip_install` or `virtualenv_install_with_resources`.

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
