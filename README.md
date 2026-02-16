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
| **aiterm** | Terminal optimizer for AI-assisted development |
| **atlas** | ADHD-friendly project state engine with sessions, captures, and context |
| **examark** | Create exams from Markdown and export to Canvas QTI format |
| **flow-cli** | ZSH workflow tools designed for ADHD brains |
| **mcp-bridge** | Connect Claude.ai to local MCP servers via SSE |
| **nexus-cli** | Knowledge workflow CLI for research, teaching, and writing |
| **scribe-cli** | Scribe document conversion CLI |
| ~~examify~~ | *Deprecated: renamed to examark* |

### Claude Code Plugins (Formulas)

| Formula | Description |
|---------|-------------|
| **craft** | Workflow orchestration plugin (109 commands, 80+ skills) |
| **himalaya-mcp** | Email MCP server for Claude Code via himalaya |
| **rforge** | R package ecosystem orchestrator |
| **rforge-orchestrator** | Auto-delegation orchestrator for RForge MCP tools |
| **scholar** | Academic research toolkit (28 commands) |
| **workflow** | ADHD-friendly workflow automation plugin |

```bash
# Install any formula
brew install data-wise/tap/aiterm
brew install data-wise/tap/craft
brew install data-wise/tap/himalaya-mcp
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

## Formula Generator

Plugin formulas are generated from a single manifest using the Python generator:

```bash
cd generator
python3 generate.py              # Generate all plugin formulas
python3 generate.py craft        # Generate one formula
python3 generate.py --diff       # Show diff vs existing
python3 generate.py --validate   # Validate with ruby -c
```

The generator reads `generator/manifest.json` and composes bash blocks from `generator/blocks/` to produce consistent Ruby formulas. CI workflows own version/SHA updates; the generator owns formula structure.

## CI/CD

- **update-formula.yml** — Reusable workflow called by project repos on release. Supports `github`, `pypi`, `npm`, and `cran` source types. Uses GitHub App token (Data-Wise Homebrew Automation) with PAT fallback.
- **validate-formulas.yml** — Weekly `brew style` + `ruby -c` validation of all 14 formulas (Monday 06:00 UTC).

## More Info

- [aiterm](https://github.com/Data-Wise/aiterm) - Terminal optimizer
- [Atlas](https://github.com/Data-Wise/atlas) - Project state engine
- [Craft](https://github.com/Data-Wise/craft) - Workflow orchestration plugin
- [Examark](https://data-wise.github.io/examark/) - Exam generator
- [flow-cli](https://data-wise.github.io/flow-cli/) - ZSH workflow tools
- [Himalaya MCP](https://github.com/Data-Wise/himalaya-mcp) - Email MCP server
- [MCP Bridge](https://data-wise.github.io/mcp-bridge/) - Claude.ai MCP connector
- [Nexus CLI](https://data-wise.github.io/nexus-cli/) - Knowledge workflow
- [Scribe](https://github.com/Data-Wise/scribe) - Distraction-free writer

## Issues

- [Tap Issues](https://github.com/Data-Wise/homebrew-tap/issues)
