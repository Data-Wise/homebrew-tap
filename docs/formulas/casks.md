# Casks

## scribe

ADHD-friendly distraction-free writing app for academics and researchers.

```bash
brew install --cask data-wise/tap/scribe
```

**Features:** HybridEditor, 10 ADHD-friendly themes, LaTeX math, citation autocomplete, Pandoc export.

| Shortcut | Action |
|----------|--------|
| Cmd+Shift+N | Open Scribe from anywhere |
| Cmd+K | Command palette |
| Cmd+Shift+F | Toggle focus mode |

!!! note "Apple Silicon only"
    Scribe currently requires Apple Silicon (M1/M2/M3/M4).

## scribe-dev

Development channel for Scribe. Receives alpha/beta releases.

```bash
brew install --cask data-wise/tap/scribe-dev
```

!!! warning "Conflicts with stable"
    `scribe` and `scribe-dev` cannot be installed simultaneously.
