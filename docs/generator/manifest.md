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

## Special Fields

| Field | Type | Description |
|-------|------|-------------|
| `head_only` | boolean | No releases, head-only install (rforge) |
| `head` | string | Git URL for head installs |
| `url_override` | string | Custom URL pattern (monorepo releases) |
| `install_script_desc` | string | Description for marketplace manifest |
| `install_script_summary` | array | Usage hints shown after install |
