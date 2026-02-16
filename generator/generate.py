#!/usr/bin/env python3
"""Generate Homebrew formulas for Claude Code plugins from manifest.json.

Usage:
    python3 generate.py                    # Generate all plugin formulas
    python3 generate.py craft              # Generate one formula
    python3 generate.py --diff             # Show diff vs existing
    python3 generate.py --validate         # Validate generated output with ruby -c
    python3 generate.py --list             # List all formulas in manifest
"""

import json
import os
import subprocess
import sys
import textwrap
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent
REPO_DIR = SCRIPT_DIR.parent
FORMULA_DIR = REPO_DIR / "Formula"
BLOCKS_DIR = SCRIPT_DIR / "blocks"
MANIFEST_FILE = SCRIPT_DIR / "manifest.json"


def load_manifest():
    with open(MANIFEST_FILE) as f:
        return json.load(f)


def load_block(name):
    path = BLOCKS_DIR / name
    if not path.exists():
        raise FileNotFoundError(f"Block not found: {path}")
    return path.read_text()


def ruby_class_name(formula_name):
    """Convert formula name to Ruby class name (e.g., himalaya-mcp -> HimalayaMcp)."""
    return "".join(part.capitalize() for part in formula_name.split("-"))


def indent(text, spaces=6):
    """Indent text by given number of spaces."""
    prefix = " " * spaces
    lines = text.rstrip().split("\n")
    return "\n".join(prefix + line if line.strip() else "" for line in lines)


def format_block(template, **kwargs):
    """Replace {placeholders} in a block template."""
    result = template
    for key, value in kwargs.items():
        result = result.replace(f"{{{key}}}", str(value))
    return result


def generate_install_script(formula_name, config):
    """Generate the <name>-install bash script content."""
    plugin_name = formula_name
    display_name = ruby_class_name(formula_name).replace("Mcp", " MCP").replace("Rforge", "RForge")
    features = config.get("features", {})

    # Header
    script = format_block(
        load_block("header.sh"),
        plugin_name=plugin_name,
        formula_name=formula_name,
    )

    # Schema cleanup (optional)
    if features.get("schema_cleanup"):
        script += "\n" + load_block("schema-cleanup.sh")

    # Symlink
    script += "\n" + format_block(
        load_block("symlink.sh"),
        display_name=display_name,
    )

    # Success path (if LINK_SUCCESS)
    script += "\nif [ \"$LINK_SUCCESS\" = true ]; then\n"

    # Marketplace registration (optional)
    if features.get("marketplace"):
        script += format_block(
            load_block("marketplace.sh"),
            install_script_desc=config.get("install_script_desc", config["desc"]),
        )

    # Claude detection (optional)
    if features.get("claude_detection"):
        script += "\n" + load_block("claude-detection.sh")

    # Branch guard (optional, craft only)
    if features.get("branch_guard"):
        script += "\n" + load_block("branch-guard.sh")

    # Success message
    summary_lines = config.get("install_script_summary", [])
    summary_echo = "\n".join(f'    echo "{line}"' for line in summary_lines)

    hook_msg = ""
    if features.get("branch_guard"):
        hook_msg = '    if [ "$HOOK_INSTALLED" = true ]; then\n        echo "Branch guard hook installed (protects main/dev branches)."\n    fi'

    script += "\n" + format_block(
        load_block("success.sh"),
        display_name=display_name,
        plugin_name=plugin_name,
        hook_message=hook_msg,
        summary_lines=summary_echo,
    )

    # Else (fallback)
    script += "else\n"
    script += format_block(
        load_block("fallback.sh"),
        display_name=display_name,
    )
    script += "fi\n"

    return script


def generate_uninstall_script(formula_name, config):
    """Generate the <name>-uninstall bash script content."""
    display_name = ruby_class_name(formula_name).replace("Mcp", " MCP").replace("Rforge", "RForge")
    return format_block(
        load_block("uninstall.sh"),
        plugin_name=formula_name,
        display_name=display_name,
    )


def generate_formula(formula_name, config, defaults):
    """Generate a complete Ruby formula file for a Claude Code plugin."""
    class_name = ruby_class_name(formula_name)
    features = config.get("features", {})
    deps = config.get("dependencies", {})

    head_only = config.get("head_only", False)

    # Build the formula
    lines = [
        "# typed: false",
        "# frozen_string_literal: true",
        "",
        f"# {class_name} formula for the {defaults['tap']} Homebrew tap.",
        f"class {class_name} < Formula",
        f'  desc "{config["desc"]}"',
        f'  homepage "{config["homepage"]}"',
    ]

    if head_only:
        lines.append(f'  license "{defaults["license"]}"')
        lines.append(f'  head "{config["head"]}", branch: "main"')
    else:
        # URL
        if "url_override" in config:
            url = config["url_override"].replace("{version}", config["version"])
        else:
            url = f"https://github.com/{config['repo']}/archive/refs/tags/v{config['version']}.tar.gz"
        lines.append(f'  url "{url}"')
        lines.append(f'  sha256 "{config["sha256"]}"')
        lines.append(f'  license "{defaults["license"]}"')

        # Head (if present — i.e., formula has both url and head)
        if "head" in config:
            lines.append(f'  head "{config["head"]}", branch: "main"')

    lines.append("")

    # Dependencies
    for dep in deps.get("runtime", []):
        lines.append(f'  depends_on "{dep}"')
    for dep in deps.get("optional", []):
        lines.append(f'  depends_on "{dep}" => :optional')

    lines.append("")
    lines.append("  def install")

    # Build steps (for formulas that need npm build etc.)
    if "build_steps" in config:
        for step in config["build_steps"]:
            lines.append(f"    {step}")
        lines.append("")

    # Libexec install
    if "libexec_paths" in config:
        for path in config["libexec_paths"]:
            lines.append(f'    libexec.install "{path}"')
    elif "libexec_subdir" in config:
        lines.append(f'    libexec.install Dir["{config["libexec_subdir"]}/*"]')
    else:
        lines.append('    libexec.install Dir["*", ".*"].reject { |f| %w[. .. .git].include?(f) }')

    lines.append("")

    # Install script
    install_script = generate_install_script(formula_name, config)
    lines.append(f'    (bin/"{formula_name}-install").write <<~EOS')
    for line in install_script.split("\n"):
        lines.append(f"      {line}" if line.strip() else "")
    lines.append("    EOS")

    lines.append("")

    # Uninstall script
    uninstall_script = generate_uninstall_script(formula_name, config)
    lines.append(f'    (bin/"{formula_name}-uninstall").write <<~EOS')
    for line in uninstall_script.split("\n"):
        lines.append(f"      {line}" if line.strip() else "")
    lines.append("    EOS")

    lines.append("")
    lines.append(f'    chmod "+x", bin/"{formula_name}-install"')
    lines.append(f'    chmod "+x", bin/"{formula_name}-uninstall"')
    lines.append("  end")

    # post_install
    lines.append("")
    lines.append("  def post_install")
    if features.get("schema_cleanup"):
        lines.append("    # Step 1: Strip keys not recognized by Claude Code's strict plugin.json schema")
        lines.append("    require \"json\"")
        lines.append('    plugin_json = libexec/".claude-plugin/plugin.json"')
        lines.append("    if plugin_json.exist?")
        lines.append('      allowed_keys = %w[name version description author]')
        lines.append("      data = JSON.parse(plugin_json.read)")
        lines.append("      cleaned = data.slice(*allowed_keys)")
        lines.append('      plugin_json.write("#{JSON.pretty_generate(cleaned)}\\n") if cleaned.size < data.size')
        lines.append("    end")
        lines.append("  rescue")
        lines.append("    nil")
    else:
        lines.append("    begin")
        lines.append(f'      system bin/"{formula_name}-install"')
        lines.append("    rescue")
        lines.append("      nil")
        lines.append("    end")
        lines.append("")
        lines.append("    begin")
        lines.append(f'      system "claude", "plugin", "update", "{formula_name}@local-plugins" if which("claude")')
        lines.append("    rescue")
        lines.append("      nil")
        lines.append("    end")
    lines.append("  end")

    # post_uninstall
    lines.append("")
    lines.append("  def post_uninstall")
    lines.append(f'    system bin/"{formula_name}-uninstall" if (bin/"{formula_name}-uninstall").exist?')
    lines.append("  end")

    # caveats
    lines.append("")
    lines.append("  def caveats")
    lines.append("    <<~EOS")
    caveats_text = config.get("caveats_extra", f"The {class_name} plugin has been installed to:\n  ~/.claude/plugins/{formula_name}")
    for line in caveats_text.split("\n"):
        lines.append(f"      {line}" if line.strip() else "")
    lines.append("")
    lines.append(f"      For more information:")
    lines.append(f'        {config["homepage"]}')
    lines.append("    EOS")
    lines.append("  end")

    # test
    lines.append("")
    lines.append("  test do")
    for tp in config.get("test_paths", []):
        if isinstance(tp, dict):
            path = tp["path"]
            if tp["type"] == "directory":
                lines.append(f'    assert_predicate libexec/"{path}", :directory?')
            else:
                lines.append(f'    assert_path_exists libexec/"{path}"')
        else:
            lines.append(f'    assert_path_exists libexec/"{tp}"')
    lines.append("  end")

    lines.append("end")
    lines.append("")

    return "\n".join(lines)


def main():
    manifest = load_manifest()
    defaults = manifest["defaults"]
    formulas = manifest["formulas"]

    # Parse args
    args = sys.argv[1:]
    diff_mode = "--diff" in args
    validate_mode = "--validate" in args
    list_mode = "--list" in args

    # Remove flags
    names = [a for a in args if not a.startswith("--")]

    if list_mode:
        for name, cfg in formulas.items():
            gen = "generated" if cfg.get("generated", True) and cfg.get("type") == "claude-plugin" else "hand-crafted"
            print(f"  {name:25s}  {cfg['type']:20s}  {gen}")
        return

    # Filter to plugin formulas only (or specific names)
    if names:
        targets = {n: formulas[n] for n in names if n in formulas}
    else:
        targets = {n: c for n, c in formulas.items() if c.get("type") == "claude-plugin" and c.get("generated", True)}

    if not targets:
        print("No formulas to generate. Use --list to see available formulas.")
        return

    errors = []
    for name, config in targets.items():
        print(f"Generating {name}.rb ...", end=" ")
        try:
            output = generate_formula(name, config, defaults)
        except Exception as e:
            print(f"ERROR: {e}")
            errors.append(name)
            continue

        output_path = FORMULA_DIR / f"{name}.rb"

        if diff_mode and output_path.exists():
            existing = output_path.read_text()
            if existing == output:
                print("IDENTICAL")
            else:
                print("DIFFERS")
                # Show diff
                import tempfile
                with tempfile.NamedTemporaryFile(mode="w", suffix=".rb", delete=False) as tmp:
                    tmp.write(output)
                    tmp_path = tmp.name
                result = subprocess.run(
                    ["diff", "-u", str(output_path), tmp_path],
                    capture_output=True, text=True,
                )
                print(result.stdout[:3000])
                os.unlink(tmp_path)
        else:
            output_path.write_text(output)
            print("WRITTEN")

        if validate_mode:
            result = subprocess.run(
                ["ruby", "-c", str(output_path)],
                capture_output=True, text=True,
            )
            if result.returncode != 0:
                print(f"  SYNTAX ERROR: {result.stderr.strip()}")
                errors.append(name)
            else:
                print(f"  Syntax OK")

    if errors:
        print(f"\nErrors in: {', '.join(errors)}")
        sys.exit(1)
    else:
        print(f"\n{len(targets)} formula(s) processed successfully.")


if __name__ == "__main__":
    main()
