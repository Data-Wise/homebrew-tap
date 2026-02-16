# Quick Start

Get up and running in 30 seconds.

## Add the Tap

```bash
brew tap data-wise/tap
```

## Install a CLI Tool

```bash
brew install data-wise/tap/aiterm
brew install data-wise/tap/flow-cli
```

## Install a Claude Code Plugin

```bash
brew install data-wise/tap/craft
```

After installation, the plugin is automatically:

1. Symlinked to `~/.claude/plugins/`
2. Registered in the local marketplace
3. Enabled in Claude Code settings (if Claude is not running)

## Verify

```bash
brew list --versions | grep data-wise
```

## Next Steps

- [All Formulas](formulas/index.md) - Browse the full catalog
- [Plugin Details](formulas/plugins.md) - How plugin installation works
- [Reference Card](REFCARD.md) - Quick command reference
