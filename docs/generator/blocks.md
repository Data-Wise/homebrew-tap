# Block Templates

Composable bash fragments in `generator/blocks/` that the generator assembles into install scripts.

## Available Blocks

| Block | File | Description |
|-------|------|-------------|
| Header | `header.sh` | Script header with variables (PREFIX, SOURCE_DIR) |
| Schema Cleanup | `schema-cleanup.sh` | Python one-liner to strip invalid JSON keys |
| Symlink | `symlink.sh` | 3-method fallback for macOS symlink creation |
| Marketplace | `marketplace.sh` | jq-based marketplace registration |
| Claude Detection | `claude-detection.sh` | `pgrep -x "claude"` guard |
| Branch Guard | `branch-guard.sh` | Hook installation (craft only) |
| Success | `success.sh` | Success message template |
| Fallback | `fallback.sh` | Fallback message if symlink fails |
| Uninstall | `uninstall.sh` | Uninstall script template |

## Composition Order

The install script is assembled in this order:

1. **Header** - Sets PREFIX, SOURCE_DIR variables
2. **Schema Cleanup** - Strips unrecognized keys (if enabled)
3. **Symlink** - Creates plugin symlink with 3 fallbacks
4. **Marketplace** - Registers in local-marketplace (if enabled)
5. **Branch Guard** - Installs git hook (craft only)
6. **Claude Detection** - Checks if Claude is running
7. **Settings Modification** - Auto-enables plugin (if Claude not running)
8. **Success/Fallback** - Status messages

## Placeholders

Blocks use `{placeholder}` syntax, replaced by `generate.py`:

| Placeholder | Example Value |
|------------|---------------|
| `{name}` | `craft` |
| `{prefix}` | `$(brew --prefix)/opt/craft` |
| `{source_dir}` | `$PREFIX/libexec` |
| `{desc}` | `Workflow orchestration plugin` |
