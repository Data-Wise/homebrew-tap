# Data-Wise Homebrew Tap

Homebrew formulae and casks for Data-Wise tools.

## Install

```bash
brew tap data-wise/tap
```

## Packages

### CLI Tools (Formulas)

| Formula | Description |
|---------|-------------|
| **atlas** | ADHD-friendly project state engine with sessions, captures, and context |
| **nexus-cli** | Knowledge workflow CLI for research, teaching, and writing |
| **examify** | Create exams from Markdown and export to Canvas QTI format |
| **examark** | Create exams from Markdown and export to Canvas QTI format |
| **aiterm** | Terminal optimizer for AI-assisted development |

```bash
brew install data-wise/tap/atlas
brew install data-wise/tap/nexus-cli
brew install data-wise/tap/aiterm
```

### Desktop Apps (Casks)

| Cask | Description | Status |
|------|-------------|--------|
| **scribe** | ADHD-friendly distraction-free writer | 🧪 Alpha |

```bash
brew install --cask data-wise/tap/scribe
```

## Scribe (Alpha)

> ⚠️ **Pre-release**: This is an alpha version intended for testing.

**Scribe** is an ADHD-friendly distraction-free writing app for academics and researchers.

### Features

- HybridEditor (Markdown + Preview)
- 10 ADHD-friendly themes
- 14 recommended fonts with one-click install
- Wiki-links and tags
- Focus mode
- Global hotkey (⌘⇧N)

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| ⌘⇧N | Open Scribe from anywhere |
| ⌘K | Command palette |
| ⌘⇧F | Toggle focus mode |
| ⌘E | Toggle write/preview mode |

### Install Scribe

```bash
# Add tap (if not already added)
brew tap data-wise/tap

# Install Scribe
brew install --cask data-wise/tap/scribe

# Update to latest version
brew upgrade --cask scribe
```

### Report Issues

- [Scribe Issues](https://github.com/Data-Wise/scribe/issues)
- [Tap Issues](https://github.com/Data-Wise/homebrew-tap/issues)

## More Info

- [Atlas Documentation](https://github.com/Data-Wise/atlas#readme)
- [Nexus CLI Documentation](https://data-wise.github.io/nexus-cli/)
- [Examify Documentation](https://data-wise.github.io/examify/)
- [Examark Documentation](https://data-wise.github.io/examark/)
- [aiterm Repository](https://github.com/Data-Wise/aiterm)
- [Scribe Repository](https://github.com/Data-Wise/scribe)
