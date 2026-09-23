#!/usr/bin/env bash
# Contract: claude-plugin formulas never try to reach ~/.claude from
# post_install, and their caveats give the Claude Code setup commands instead.
#
# Why: Homebrew runs post_install in a sandbox with an isolated temporary HOME
# (formula.rb run_post_install: Dir.mktmpdir) plus deny_read_home, allowing
# writes only to the Cellar, prefix link dirs, temp and cache. Anything aimed
# at ~/.claude there lands in a throwaway dir: the old auto-install copied the
# plugin into it and reported success, and `claude plugin marketplace update
# local-plugins` saw zero marketplaces ("not found") on every brew upgrade.
# That failure was misread as a race (PR #134's retry); this test replaces the
# test that locked the retry in.
#
# Scope: the 6 generated claude-plugin formulas only.

set -u
cd "$(dirname "$0")/.." || exit 2

ROWS=$(python3 -c "
import json
m = json.load(open('generator/manifest.json'))
for n, c in m['formulas'].items():
    if c.get('type') == 'claude-plugin' and c.get('generated', True):
        print(n, c.get('claude_plugin') or '-', 'yes' if c.get('claude_setup', True) else 'no')
")

fail=0
checked=""

while read -r name ref setup; do
    [ -n "$name" ] || continue
    f="Formula/${name}.rb"
    if [ ! -f "$f" ]; then
        echo "FAIL ${name}: $f missing"; fail=1; continue
    fi
    checked="$checked $name"

    # 1. post_install (if any) touches nothing outside the Homebrew sandbox
    post=$(awk '/^  def post_install$/,/^  end$/' "$f")
    for pat in 'Dir.home' '.claude/plugins' 'Process.spawn' 'system "claude"' 'system("claude"' 'local-plugins' '-install")'; do
        if printf '%s\n' "$post" | grep -qF -- "$pat"; then
            echo "FAIL ${name}: post_install references '$pat' (unreachable from Homebrew's sandbox)"
            fail=1
        fi
    done

    # Deprecated formulas (claude_setup: false) keep their legacy caveats verbatim
    [ "$setup" = "yes" ] || continue
    cav=$(awk '/^  def caveats$/,/^  end$/' "$f")

    # 2. caveats make no claims the sandboxed install can't keep
    for pat in '@local-plugins' 'has been installed to' 'If the automatic copy failed'; do
        if printf '%s\n' "$cav" | grep -qF -- "$pat"; then
            echo "FAIL ${name}: caveats still say '$pat'"
            fail=1
        fi
    done

    # 3. caveats carry the setup the user actually has to run
    if ! printf '%s\n' "$cav" | grep -qF "Claude Code setup"; then
        echo "FAIL ${name}: caveats missing the Claude Code setup section"; fail=1
    fi
    if [ "$ref" != "-" ]; then
        mp=${ref#*@}
        for cmd in "claude plugin marketplace update ${mp}" "claude plugin install ${ref}" "claude plugin update ${ref}"; do
            if ! printf '%s\n' "$cav" | grep -qF -- "$cmd"; then
                echo "FAIL ${name}: caveats missing '$cmd'"; fail=1
            fi
        done
    elif ! printf '%s\n' "$cav" | grep -qF -- "${name}-install"; then
        echo "FAIL ${name}: no marketplace and caveats don't point to ${name}-install"; fail=1
    fi
done <<< "$ROWS"

if [ "$fail" -eq 0 ]; then
    echo "PASS: post_install is sandbox-safe and caveats carry the Claude Code setup"
    echo "  checked:$checked"
fi
exit "$fail"
