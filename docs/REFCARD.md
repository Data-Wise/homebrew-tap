# Reference Card

## All Formulas

### CLI Tools

| Formula | Type | Source | Description |
|---------|------|--------|-------------|
| aiterm | Python virtualenv | GitHub | Terminal optimizer for AI-assisted development |
| atlas | Node npm | GitHub | ADHD-friendly project state engine |
| examark | Node npm | npm | Create exams from Markdown, export to Canvas QTI |
| flow-cli | Shell (ZSH) | GitHub | ZSH workflow tools for ADHD brains |
| mcp-bridge | Node npm | GitHub | Connect Claude.ai to local MCP servers via SSE |
| nexus-cli | Python virtualenv | PyPI | Knowledge workflow CLI for research and teaching |
| scribe-cli | Swift | GitHub | Scribe document conversion CLI |

### Claude Code Plugins

| Formula | Features | Description |
|---------|----------|-------------|
| craft | marketplace, branch-guard, schema-cleanup | Workflow orchestration (109 commands) |
| himalaya-mcp | marketplace, schema-cleanup, build | Email MCP server via himalaya |
| rforge | marketplace, schema-cleanup (head-only) | R package ecosystem orchestrator |
| rforge-orchestrator | marketplace, schema-cleanup | Auto-delegation orchestrator |
| scholar | marketplace, schema-cleanup | Academic research toolkit (28 commands) |
| workflow | marketplace, schema-cleanup | ADHD-friendly workflow automation |

### Casks

| Cask | Arch | Description |
|------|------|-------------|
| scribe | Apple Silicon | Distraction-free writer (stable) |
| scribe-dev | Apple Silicon | Distraction-free writer (dev channel) |

## Common Commands

```bash
# Install
brew tap data-wise/tap
brew install data-wise/tap/<formula>

# Update
brew update && brew upgrade data-wise/tap/<formula>

# Audit (must use tap name)
brew audit --strict data-wise/tap/<formula>

# Style check (accepts file path)
brew style Formula/<formula>.rb

# Install from source
brew install --build-from-source data-wise/tap/<formula>

# Test
brew test data-wise/tap/<formula>
```

## Generator Commands

```bash
python3 generator/generate.py              # Generate all plugin formulas
python3 generator/generate.py <name>       # Generate one formula
python3 generator/generate.py --diff       # Show diff vs existing
python3 generator/generate.py --validate   # Validate with ruby -c
python3 generator/generate.py --list       # List all formulas
```

## CI Workflows

| Workflow | Trigger | What it does |
|----------|---------|-------------|
| update-formula.yml | Called by project repos on release | Updates version/SHA via sed |
| validate-formulas.yml | Weekly (Monday 06:00 UTC) | brew style + ruby -c on all 14 |
