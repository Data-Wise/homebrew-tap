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
| `revision` | integer | No | Bump when formula/install-script content changes with no version bump — `brew upgrade` compares version+revision only, not file content, so a content-only edit is invisible to it without this |
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
| `caveats_extra` | string | Additional caveats text (plugin-specific; the Claude Code setup section is appended automatically) |
| `claude_plugin` | string | Claude Code plugin id `<plugin>@<marketplace>` (e.g. `rforge@data-wise`, `himalaya@data-wise`). Caveats print `claude plugin marketplace update <marketplace>` + `claude plugin install/update <id>`. Omit when the plugin is in no marketplace — caveats then point to `<name>-install` |
| `claude_setup` | boolean | Default `true`. `false` suppresses the Claude Code setup section (deprecated formulas that keep legacy caveats) |

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

Homebrew runs `post_install` in a sandbox with an isolated temporary `HOME` and `deny_read_home`; it may write only to the Cellar, the prefix link dirs, temp and cache. Nothing in `post_install` can reach the user's `~/.claude`, so generated formulas keep only the step that stays inside the Cellar:

- **JSON schema cleanup** (only when `features.schema_cleanup` is set) — strips unrecognized keys from `libexec/.claude-plugin/plugin.json`. Formulas without it have no `post_install`.

Claude Code setup is the user's step, printed in the caveats (see `claude_plugin` below). The former auto-install, registry-sync, cache-prune and version-drift steps ran against the throwaway `HOME` — the copy "succeeded" into a directory Homebrew then deleted, and `claude plugin marketplace update local-plugins` saw no marketplaces at all. `tests/test_post_install_sandbox_safe.sh` gates this in CI.

## Special Fields

| Field | Type | Description |
|-------|------|-------------|
| `head_only` | boolean | No releases, head-only install (rforge) |
| `head` | string | Git URL for head installs |
| `url_override` | string | Custom URL pattern (monorepo releases) |
| `install_script_desc` | string | Description for marketplace manifest |
| `install_script_summary` | array | Usage hints shown after install |
