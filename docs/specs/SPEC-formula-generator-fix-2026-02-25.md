# SPEC: Formula Generator Fix — Nested Plugin Directories + Auto-Install

**Status:** draft
**Created:** 2026-02-25
**From:** himalaya-mcp installation brainstorm (deep + agent research)
**Priority:** Critical (bug fix) + High (auto-install parity)

---

## Overview

Fix the formula generator's handling of plugins with nested source structures (e.g., himalaya-mcp's `himalaya-mcp-plugin/skills/`), add auto-install to `post_install` for all plugin formulas, sync stale manifest versions, and regenerate all 6 plugin formulas.

## Problem

### Bug: Skills/Agents Nesting

himalaya-mcp's repo has skills nested under `himalaya-mcp-plugin/`:
```
himalaya-mcp/
├── himalaya-mcp-plugin/
│   ├── .claude-plugin/plugin.json
│   ├── skills/       ← 7 skills here
│   └── agents/       ← 1 agent here
├── dist/
└── .mcp.json
```

The manifest has:
```json
"libexec_paths": [".claude-plugin", ".mcp.json", "plugin", "dist"]
```

The generator produces:
```ruby
libexec.install "plugin"   # → libexec/plugin/skills/ (WRONG)
```

Claude Code expects `skills/` at plugin root (`libexec/skills/`), not nested.

### Gap: Missing Auto-Install in post_install

The generator's `post_install` for `schema_cleanup: true` formulas only strips plugin.json keys — it does NOT run the install script or sync the Claude plugin registry. craft's live formula has this (added manually), but the generator doesn't produce it. This means regenerating craft's formula would **regress** its post_install.

### Drift: Manifest Version Stale

| Formula | Manifest Version | Live Version | Gap |
|---------|-----------------|-------------|-----|
| craft | 2.19.0 | 2.28.0 | 9 versions behind |
| himalaya-mcp | 1.2.0 | 1.3.0 | 1 version behind |
| scholar | ? | ? | Check |
| rforge | ? | ? | Check |
| workflow | ? | ? | Check |
| rforge-orchestrator | ? | ? | Check |

CI's `update-formula.yml` patches version+SHA directly in the `.rb` files via sed, but doesn't update `manifest.json`. Over time, the manifest drifts.

---

## Changes Required

### 1. Generator: Support Path Mapping (libexec_copy_map)

**File:** `generator/generate.py`

Add a new manifest field `libexec_copy_map` for plugins that need source→dest mapping:

```json
"libexec_copy_map": {
  "himalaya-mcp-plugin/skills": "skills",
  "himalaya-mcp-plugin/agents": "agents",
  "himalaya-mcp-plugin/hooks": "hooks"
}
```

In `generate_formula()`, after processing `libexec_paths`, handle `libexec_copy_map`:

```python
# Existing: direct paths
if "libexec_paths" in config:
    for path in config["libexec_paths"]:
        lines.append(f'    libexec.install "{path}"')

# New: mapped paths (source → dest)
if "libexec_copy_map" in config:
    for src, dest in config["libexec_copy_map"].items():
        lines.append(f'    cp_r "{src}", libexec/"{dest}"')
```

Also add conditional existence check for optional paths (e.g., hooks):

```python
# For optional mapped paths
if "libexec_copy_map_optional" in config:
    for src, dest in config["libexec_copy_map_optional"].items():
        lines.append(f'    cp_r "{src}", libexec/"{dest}" if (buildpath/"{src}").exist?')
```

### 2. Generator: Fix post_install to Include Auto-Install

**File:** `generator/generate.py` — `post_install` section

The current code for `schema_cleanup: true` formulas generates:

```ruby
def post_install
  require "json"
  # ... strip keys ...
rescue
  nil
end
```

This is broken in two ways:
1. The bare `rescue` catches errors from ALL code, not just JSON parsing
2. No install script execution or Claude registry sync

**Fix:** Generate craft's 3-step pattern for ALL `claude-plugin` type formulas:

```ruby
def post_install
  # Step 1: Strip keys (in own begin/rescue block)
  begin
    require "json"
    plugin_json = libexec/".claude-plugin/plugin.json"
    if plugin_json.exist?
      allowed_keys = %w[name version description author]
      data = JSON.parse(plugin_json.read)
      cleaned = data.slice(*allowed_keys)
      plugin_json.write("#{JSON.pretty_generate(cleaned)}\n") if cleaned.size < data.size
    end
  rescue
    nil
  end

  # Step 2: Auto-install plugin with 30s timeout
  begin
    require "timeout"
    pid = Process.spawn("#{bin}/<name>-install")
    Timeout.timeout(30) { Process.waitpid(pid) }
  rescue Timeout::Error
    Process.kill("TERM", pid) rescue nil
    Process.waitpid(pid) rescue nil
    opoo "<name>-install timed out after 30 seconds (skipping)"
  rescue
    nil
  end

  # Step 3: Sync Claude Code plugin registry (optional)
  begin
    system "claude", "plugin", "update", "<name>@local-plugins" if which("claude")
  rescue
    nil
  end
end
```

### 3. Manifest: Update himalaya-mcp Entry

**File:** `generator/manifest.json`

```json
"himalaya-mcp": {
  "version": "1.3.0",
  "sha256": "35662a9ffbe046e7f9208d64dae0d28bfa4f46c2c129f64e14813614f83be35e",
  "libexec_paths": [
    ".claude-plugin",
    ".mcp.json",
    "dist"
  ],
  "libexec_copy_map": {
    "himalaya-mcp-plugin/skills": "skills",
    "himalaya-mcp-plugin/agents": "agents"
  },
  "libexec_copy_map_optional": {
    "himalaya-mcp-plugin/hooks": "hooks"
  },
  "test_paths": [
    {"path": ".claude-plugin/plugin.json", "type": "file"},
    {"path": "dist/index.js", "type": "file"},
    {"path": "skills", "type": "directory"},
    {"path": "agents", "type": "directory"}
  ],
  "caveats_extra": "7 email skills for Claude Code:\n  /email:inbox   /email:triage   /email:digest\n  /email:reply   /email:compose  /email:attachments\n  /email:help\n\n19 MCP tools available.\n\nFor Claude Desktop: himalaya-mcp setup\nOr download .mcpb from GitHub Releases.\n\nAfter upgrades, sync Claude Code registry:\n  claude plugin update email@local-plugins\n\nIf symlink failed (macOS permissions), run manually:\n  ln -sf $(brew --prefix)/opt/himalaya-mcp/libexec ~/.claude/plugins/himalaya-mcp\n\nRequires himalaya CLI with at least one configured account.\nSee: https://github.com/Data-Wise/himalaya-mcp"
}
```

(Keep all other fields unchanged; only update version, sha256, libexec_paths, add copy_map, update test_paths, update caveats)

### 4. Manifest: Sync All Versions

Sync all 6 formulas to their current live versions. Get versions from:
```bash
for f in craft himalaya-mcp scholar rforge rforge-orchestrator workflow; do
  echo "$f: $(brew info data-wise/tap/$f 2>/dev/null | head -1 | awk '{print $NF}')"
done
```

### 5. Regenerate All Formulas

```bash
python3 generator/generate.py --diff      # Preview all changes
python3 generator/generate.py --validate  # Syntax check
python3 generator/generate.py             # Write all
```

### 6. Test

```bash
# Copy to tap dir for testing
cp Formula/*.rb /opt/homebrew/Library/Taps/data-wise/homebrew-tap/Formula/

# Test himalaya-mcp specifically
brew install --build-from-source data-wise/tap/himalaya-mcp
brew test data-wise/tap/himalaya-mcp

# Verify skills at correct path
ls /opt/homebrew/opt/himalaya-mcp/libexec/skills/

# Audit all
for f in Formula/*.rb; do
  name=$(basename "$f" .rb)
  brew audit --strict "data-wise/tap/$name" 2>&1
done
```

---

## Review Checklist

- [ ] `generate.py` supports `libexec_copy_map` field
- [ ] `generate.py` generates 3-step `post_install` for all plugin formulas
- [ ] `manifest.json` himalaya-mcp entry updated (v1.3.0, copy_map, test_paths, caveats)
- [ ] All 6 manifest versions synced to live
- [ ] `python3 generate.py --validate` passes for all 6
- [ ] `python3 generate.py --diff` shows expected changes only
- [ ] `brew install --build-from-source` works for himalaya-mcp
- [ ] `brew test` passes for himalaya-mcp
- [ ] `ls ~/.claude/plugins/himalaya-mcp/skills/` shows 7 files after install
- [ ] `brew audit --strict` passes for all regenerated formulas
- [ ] Craft formula regeneration doesn't regress (post_install, branch guard)

---

## History

| Date | Change |
|------|--------|
| 2026-02-25 | Initial spec |
