# Manifest Schema

The manifest (`generator/manifest.json`) is the single source of truth for all formula metadata.

## Structure

```json
{
  "defaults": {
    "license": "MIT",
    "tap": "data-wise/tap"
  },
  "formulas": {
    "<name>": { ... }
  }
}
```

## Common Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | string | Yes | `claude-plugin`, `python-virtualenv`, `node-npm`, `shell`, `swift` |
| `desc` | string | Yes | One-line description |
| `homepage` | string | Yes | Project homepage URL |
| `source` | string | Yes | `github`, `pypi`, `npm`, `cran` |
| `repo` | string | Yes | GitHub repo slug (e.g., `Data-Wise/craft`) |
| `version` | string | Yes | Current version (CI updates this in formula, not manifest) |
| `sha256` | string | Yes | SHA256 of release tarball |
| `generated` | boolean | Yes | Whether the generator produces this formula |

## Plugin-Specific Fields

| Field | Type | Description |
|-------|------|-------------|
| `features.schema_cleanup` | boolean | Strip unrecognized plugin.json keys |
| `features.branch_guard` | boolean | Install git hook (craft only) |
| `features.marketplace` | boolean | Register in local-marketplace |
| `features.claude_detection` | boolean | Check if Claude is running |
| `dependencies.runtime` | array | Homebrew runtime deps |
| `dependencies.optional` | array | Optional deps (e.g., jq) |
| `build_steps` | array | Build commands (e.g., `npm install`) |
| `libexec_paths` | array | Explicit files to install to libexec |
| `libexec_subdir` | string | Install all files from subdirectory |
| `test_paths` | array | Files/dirs to verify in test block |
| `caveats_extra` | string | Additional caveats text |

## Install Layout Fields

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `libexec_copy_map` | object | Source→dest directory mapping for `cp_r` into libexec | `{"himalaya-mcp-plugin/skills": "skills"}` |
| `libexec_copy_map_optional` | object | Like `copy_map` but only copies if source directory exists | `{"himalaya-mcp-plugin/hooks": "hooks"}` |
| `libexec_mkdir` | array | Directories to pre-create in libexec before copying | `["skills", "agents"]` |
| `libexec_copy_files` | object | Individual file copies (src→dest) into libexec | `{"src/config.json": "config.json"}` |
| `extra_scripts` | array of objects | CLI wrapper scripts installed to `bin/`. Each object has `name` (string) and `body` (string) keys | `[{"name": "himalaya-mcp", "body": "exec node ..."}]` |

These fields replace the older `libexec_paths` approach with a more flexible layout system. Use `libexec_copy_map` for directory trees, `libexec_copy_files` for individual files, and `libexec_mkdir` to ensure target directories exist before copies run.

## post_install Pattern

All generated plugin formulas use a 3-step `post_install` pattern, with each step in its own `begin/rescue/end` block for independent error isolation:

1. **JSON schema cleanup** (conditional on `features.schema_cleanup`) — strips unrecognized keys from `plugin.json`
2. **Auto-install** — runs the `<name>-install` script with a 30-second timeout using `Process.spawn` + `Timeout`
3. **Registry sync** — runs `claude plugin update` to refresh the plugin registry

If any step fails, the remaining steps still execute.

## Special Fields

| Field | Type | Description |
|-------|------|-------------|
| `head_only` | boolean | No releases, head-only install (rforge) |
| `head` | string | Git URL for head installs |
| `url_override` | string | Custom URL pattern (monorepo releases) |
| `install_script_desc` | string | Description for marketplace manifest |
| `install_script_summary` | array | Usage hints shown after install |
