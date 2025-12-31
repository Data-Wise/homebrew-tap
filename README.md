# Data-Wise Homebrew Tap

Homebrew formulae and casks for Data-Wise tools.

## Install

```bash
brew tap data-wise/tap
```

## Packages

### CLI Tools (Formulas)

| Formula | Version | Description |
|---------|---------|-------------|
| **aiterm** | v0.6.0 | Terminal optimizer for AI-assisted development |
| **atlas** | v0.8.0 | ADHD-friendly project state engine with sessions, captures, and context |
| **examark** | v0.6.6 | Create exams from Markdown and export to Canvas QTI format |
| **flow-cli** | v4.5.5 | ZSH workflow tools designed for ADHD brains |
| **mcp-bridge** | v1.0.0 | Connect Claude.ai to local MCP servers via SSE |
| **nexus-cli** | v0.5.1 | Knowledge workflow CLI for research, teaching, and writing |
| **rforge-orchestrator** | v0.1.0 | Auto-delegation orchestrator for RForge MCP tools |
| **workflow** | v0.1.0 | ADHD-friendly workflow automation - Claude Code plugin |
| ~~examify~~ | v0.5.0 | *Deprecated: renamed to examark* |

```bash
# Install any formula
brew install data-wise/tap/aiterm
brew install data-wise/tap/atlas
brew install data-wise/tap/flow-cli
brew install data-wise/tap/mcp-bridge
brew install data-wise/tap/nexus-cli
```

### Desktop Apps (Casks)

| Cask | Version | Description | Arch |
|------|---------|-------------|------|
| **scribe** | v1.1.0 | ADHD-friendly distraction-free writer (stable) | Apple Silicon |
| **scribe-dev** | v1.1.0 | ADHD-friendly distraction-free writer (dev channel) | Apple Silicon |

```bash
# Stable channel (recommended)
brew install --cask data-wise/tap/scribe

# Development channel (alpha/beta releases)
brew install --cask data-wise/tap/scribe-dev
```

> **Note:** Scribe requires Apple Silicon (M1/M2/M3). Intel support coming soon.

## Featured Tools

### aiterm

Terminal optimizer for AI-assisted development with Claude Code and Gemini CLI.

```bash
brew install data-wise/tap/aiterm

# Usage
ait doctor      # Check installation
ait detect      # Show project context
ait switch      # Apply context to terminal
```

[Documentation](https://data-wise.github.io/aiterm/)

### Scribe

ADHD-friendly distraction-free writing app for academics and researchers.

**Features:**
- HybridEditor (Markdown + Preview)
- 10 ADHD-friendly themes
- LaTeX math (KaTeX)
- Citation autocomplete
- Export via Pandoc

**Keyboard Shortcuts:**
| Shortcut | Action |
|----------|--------|
| ⌘⇧N | Open Scribe from anywhere |
| ⌘K | Command palette |
| ⌘⇧F | Toggle focus mode |

[Documentation](https://github.com/Data-Wise/scribe)

### MCP Bridge

Chrome extension + SSE server for connecting Claude.ai to local MCP servers.

```bash
brew install data-wise/tap/mcp-bridge

# Start the bridge server
brew services start mcp-bridge
```

[Documentation](https://data-wise.github.io/mcp-bridge/)

### flow-cli

ZSH workflow tools designed for ADHD brains.

```bash
brew install data-wise/tap/flow-cli

# Usage
g status        # Git status
g feature start # Start feature branch
tm switch       # Context switching
```

[Documentation](https://data-wise.github.io/flow-cli/)

## More Info

- [aiterm](https://github.com/Data-Wise/aiterm) - Terminal optimizer
- [Atlas](https://github.com/Data-Wise/atlas) - Project state engine
- [Examark](https://data-wise.github.io/examark/) - Exam generator
- [flow-cli](https://data-wise.github.io/flow-cli/) - ZSH workflow tools
- [MCP Bridge](https://data-wise.github.io/mcp-bridge/) - Claude.ai MCP connector
- [Nexus CLI](https://data-wise.github.io/nexus-cli/) - Knowledge workflow
- [Scribe](https://github.com/Data-Wise/scribe) - Distraction-free writer

## Issues

- [Tap Issues](https://github.com/Data-Wise/homebrew-tap/issues)
