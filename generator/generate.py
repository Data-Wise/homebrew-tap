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


def apply_command_count_token(config):
    """Replace {command_count} token in config string fields (in-place on a copy)."""
    import copy
    config = copy.deepcopy(config)
    command_count = config.get("command_count")
    if command_count is None:
        return config

    token = "{command_count}"
    replacement = str(command_count)

    def replace_in_str(s):
        if isinstance(s, str):
            return s.replace(token, replacement)
        return s

    config["desc"] = replace_in_str(config.get("desc", ""))
    if "install_script_summary" in config:
        config["install_script_summary"] = [replace_in_str(s) for s in config["install_script_summary"]]
    if "install_script_desc" in config:
        config["install_script_desc"] = replace_in_str(config["install_script_desc"])
    if "caveats_extra" in config:
        config["caveats_extra"] = replace_in_str(config["caveats_extra"])
    return config


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
    # Apply {command_count} token substitution first
    config = apply_command_count_token(config)

    class_name = ruby_class_name(formula_name)
    features = config.get("features", {})
    deps = config.get("dependencies", {})

    head_only = config.get("head_only", False)

    # Header comment block (custom or default)
    header_comment = config.get("header_comment")
    if header_comment:
        # header_comment is raw text; each non-empty line is prefixed with "# "
        # Preserve leading whitespace within lines for indented code blocks
        raw_lines = header_comment.split("\n")
        comment_lines = []
        for raw_line in raw_lines:
            if raw_line.strip():
                # Preserve the leading whitespace (for indented code blocks like "    brew ...")
                comment_lines.append(f"# {raw_line}")
            else:
                comment_lines.append("#")
        formula_comment = "\n".join(comment_lines)
    else:
        formula_comment = f"# {class_name} formula for the {defaults['tap']} Homebrew tap."

    # Build the formula
    lines = [
        "# typed: false",
        "# frozen_string_literal: true",
        "",
        formula_comment,
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

    # deprecate! directive — after license/head (matches Homebrew convention)
    # Emits a blank line before deprecate! to match standard formatting
    if "deprecate" in config:
        dep = config["deprecate"]
        lines.append("")
        lines.append(f'  deprecate! date: "{dep["date"]}", because: "{dep["reason"]}"')

    lines.append("")

    # Dependencies (sorted — Homebrew's FormulaAudit/DependencyOrder wants alphabetical)
    for dep in sorted(deps.get("runtime", [])):
        lines.append(f'  depends_on "{dep}"')
    for dep in sorted(deps.get("optional", [])):
        lines.append(f'  depends_on "{dep}" => :optional')

    lines.append("")
    lines.append("  def install")

    # bin.mkpath (optional, must come before libexec install)
    if config.get("bin_mkpath"):
        lines.append("    bin.mkpath")
        lines.append("")

    # Build steps (for formulas that need npm build etc.)
    if "build_steps" in config:
        for step in config["build_steps"]:
            lines.append(f"    {step}")
        lines.append("")

    # Pre-install directory creation
    if "libexec_mkdir" in config:
        for dir_path in config["libexec_mkdir"]:
            lines.append(f'    mkdir_p libexec/"{dir_path}"')

    # Individual file copies (cp "src", libexec/"dest")
    # libexec_copy_files supports an optional interleaved cp_r via "libexec_copy_map_inline"
    # by using a special sentinel key "__cp_r_<src>__<dest>__" — or via explicit interleaving.
    # To interleave a cp_r between cp calls, use libexec_copy_files_with_cp_r (ordered list).
    if "libexec_copy_files" in config:
        for src, dest in config["libexec_copy_files"].items():
            lines.append(f'    cp "{src}", libexec/"{dest}"')
            # After each cp, emit any interleaved cp_r entries keyed to this src
            if "libexec_copy_map_after" in config:
                after_key = src
                if after_key in config["libexec_copy_map_after"]:
                    for map_src, map_dest in config["libexec_copy_map_after"][after_key].items():
                        lines.append(f'    cp_r "{map_src}", libexec/"{map_dest}"')

    # Libexec install
    if "libexec_paths" in config:
        for path in config["libexec_paths"]:
            lines.append(f'    libexec.install "{path}"')
    elif "libexec_subdir" in config:
        lines.append(f'    libexec.install Dir["{config["libexec_subdir"]}/*"]')
    else:
        lines.append('    libexec.install Dir["*", ".*"].reject { |f| %w[. .. .git].include?(f) }')

    # Directory copy map (cp_r "src", libexec/"dest")
    if "libexec_copy_map" in config:
        for src, dest in config["libexec_copy_map"].items():
            lines.append(f'    cp_r "{src}", libexec/"{dest}"')

    # Optional directory copy map (only if source exists)
    if "libexec_copy_map_optional" in config:
        for src, dest in config["libexec_copy_map_optional"].items():
            lines.append(f'    cp_r "{src}", libexec/"{dest}" if (buildpath/"{src}").exist?')

    lines.append("")

    # Extra scripts (e.g., CLI wrappers)
    if "extra_scripts" in config:
        for script_cfg in config["extra_scripts"]:
            script_name = script_cfg["name"]
            script_body = script_cfg["body"]
            lines.append(f'    (bin/"{script_name}").write <<~EOS')
            for line in script_body.split("\n"):
                lines.append(f"      {line}" if line.strip() else "")
            lines.append("    EOS")
            lines.append(f'    chmod "+x", bin/"{script_name}"')
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

    # post_install — 3-step pattern for all claude-plugin formulas
    lines.append("")
    lines.append("  def post_install")

    # Step 1: JSON schema cleanup (only if schema_cleanup feature enabled)
    if features.get("schema_cleanup"):
        lines.append("    # Step 1: Strip keys not recognized by Claude Code's strict plugin.json schema")
        lines.append("    begin")
        lines.append('      require "json"')
        lines.append('      plugin_json = libexec/".claude-plugin/plugin.json"')
        lines.append("      if plugin_json.exist?")
        lines.append('        allowed_keys = %w[name version description author]')
        lines.append("        data = JSON.parse(plugin_json.read)")
        lines.append("        cleaned = data.slice(*allowed_keys)")
        lines.append('        plugin_json.write("#{JSON.pretty_generate(cleaned)}\\n") if cleaned.size < data.size')
        lines.append("      end")
        lines.append("    rescue")
        lines.append("      nil")
        lines.append("    end")
        lines.append("")

    # Step 2: Auto-install plugin with 30s timeout (always)
    lines.append(f'    # Step {"2" if features.get("schema_cleanup") else "1"}: Auto-install plugin with 30s timeout')
    lines.append("    begin")
    lines.append('      require "timeout"')
    lines.append(f'      pid = Process.spawn(bin/"{formula_name}-install")')
    lines.append("      Timeout.timeout(30) { Process.waitpid(pid) }")
    lines.append("    rescue Timeout::Error")
    lines.append("      begin")
    lines.append('        Process.kill("TERM", pid)')
    lines.append("      rescue")
    lines.append("        nil")
    lines.append("      end")
    lines.append("      begin")
    lines.append("        Process.waitpid(pid)")
    lines.append("      rescue")
    lines.append("        nil")
    lines.append("      end")
    lines.append(f'      opoo "{formula_name}-install timed out after 30 seconds (skipping)"')
    lines.append("    rescue")
    lines.append("      nil")
    lines.append("    end")
    lines.append("")

    # Step 3: Sync Claude Code plugin registry (always)
    # Refresh the local-plugins marketplace index BEFORE updating, so the
    # update reads the freshly-installed version rather than a stale cached
    # manifest (otherwise `plugin update` no-ops on the prior version).
    #
    # Retry the marketplace-update call once: Step 2's spawned install script
    # can return (Process.waitpid) slightly before its marketplace-mirror
    # write (blocks/marketplace.sh) is fully visible to a freshly-spawned
    # `claude` CLI process, causing a spurious "marketplace not found" on the
    # first attempt even though the manifest is actually correct. If both
    # attempts fail, degrade to an advisory `opoo` with the manual fix-it
    # command rather than a raw failed-system-call trace.
    lines.append(f'    # Step {"3" if features.get("schema_cleanup") else "2"}: Sync Claude Code plugin registry (optional)')
    lines.append("    begin")
    lines.append('      if which("claude")')
    lines.append("        synced = false")
    lines.append("        2.times do |attempt|")
    lines.append('          synced = system("claude", "plugin", "marketplace", "update", "local-plugins")')
    lines.append("          break if synced")
    lines.append("")
    lines.append("          sleep 1 if attempt.zero?")
    lines.append("        end")
    lines.append("        if synced")
    lines.append(f'          system "claude", "plugin", "update", "{formula_name}@local-plugins"')
    lines.append("        else")
    lines.append('          opoo "marketplace sync didn\'t settle in time - run: " \\')
    lines.append('               "claude plugin marketplace update local-plugins && " \\')
    lines.append(f'               "claude plugin update {formula_name}@local-plugins"')
    lines.append("        end")
    lines.append("      else")
    lines.append(f'        opoo "claude not on PATH - run: claude plugin install {formula_name}@local-plugins to finish"')
    lines.append("      end")
    lines.append("    rescue")
    lines.append("      nil")
    lines.append("    end")
    lines.append("")

    # Cache GC: prune old cached plugin versions, keep newest 3 (unbounded growth otherwise)
    lines.append("    # Prune old cached plugin versions (keep newest 3)")
    lines.append("    begin")
    lines.append(f'      cache = Pathname.new("#{{Dir.home}}/.claude/plugins/cache/local-plugins/{formula_name}")')
    lines.append("      cache.children.select(&:directory?).sort_by(&:mtime).reverse.drop(3).each(&:rmtree) if cache.directory?")
    lines.append("    rescue")
    lines.append("      nil")
    lines.append("    end")

    # Version-drift self-check (advisory). Skipped for head-only formulas where
    # `version` is not a released semver and would false-positive.
    if not head_only:
        lines.append("")
        lines.append("    # Warn if the installed copy's version drifts from this formula")
        lines.append("    begin")
        lines.append('      require "json"')
        lines.append(f'      installed = Pathname.new("#{{Dir.home}}/.claude/plugins/{formula_name}/.claude-plugin/plugin.json")')
        lines.append("      if installed.file?")
        lines.append('        iv = JSON.parse(installed.read)["version"]')
        lines.append(f'        opoo "installed {formula_name} v#{{iv}} != formula v#{{version}}" if iv && iv.to_s != version.to_s')
        lines.append("      end")
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
    if not config.get("caveats_no_footer"):
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
            tp_type = tp["type"]
            if tp_type == "directory":
                lines.append(f'    assert_predicate libexec/"{path}", :directory?')
            elif tp_type == "bin":
                lines.append(f'    assert_path_exists bin/"{path}"')
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
