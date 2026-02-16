# Data-Wise Homebrew Tap

> Homebrew formulas for CLI tools and Claude Code plugins

## What's in the Tap

| | Category | Count | Description |
|---|----------|-------|-------------|
| :material-console: | [**CLI Tools**](formulas/cli-tools.md) | 8 formulas | Terminal optimizers, workflow tools, exam generators |
| :material-puzzle: | [**Claude Code Plugins**](formulas/plugins.md) | 6 formulas | Auto-registering plugins via Homebrew |
| :material-cog: | [**Formula Generator**](generator/index.md) | 1 tool | Produces plugin formulas from a single manifest |
| :material-sync: | [**Automated CI/CD**](ci/index.md) | 2 workflows | Version updates + weekly validation |

## Install

```bash
brew tap data-wise/tap
brew install data-wise/tap/<formula>
```

## Popular Formulas

=== "CLI Tools"

    ```bash
    brew install data-wise/tap/aiterm       # Terminal optimizer
    brew install data-wise/tap/flow-cli     # ZSH workflow tools
    brew install data-wise/tap/nexus-cli    # Knowledge workflow
    brew install data-wise/tap/examark      # Exam generator
    ```

=== "Claude Code Plugins"

    ```bash
    brew install data-wise/tap/craft        # 109 commands, 80+ skills
    brew install data-wise/tap/himalaya-mcp # Email MCP server
    brew install data-wise/tap/scholar      # Academic research
    ```

=== "Desktop Apps"

    ```bash
    brew install --cask data-wise/tap/scribe  # Distraction-free writer
    ```

## Quick Links

- [Quick Start](QUICK-START.md) - Get running in 30 seconds
- [Reference Card](REFCARD.md) - All formulas at a glance
- [GitHub](https://github.com/Data-Wise/homebrew-tap)
