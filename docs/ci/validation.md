# Formula Validation

Weekly automated validation of all formulas.

## Schedule

Runs every Monday at 06:00 UTC via `validate-formulas.yml`. Can also be triggered manually via `workflow_dispatch`.

## What It Checks

### brew style

Runs `brew style` on all 14 formulas in `Formula/`. Reports pass/fail count and lists any failing formulas.

### ruby -c

Runs Ruby syntax check on all formulas. Catches syntax errors that would break Homebrew.

## Output

Results are written to the GitHub Actions step summary with a pass/fail table.

## Running Locally

```bash
# Style check all formulas
for f in Formula/*.rb; do
  echo -n "$(basename "$f" .rb): "
  brew style "$f" >/dev/null 2>&1 && echo "PASS" || echo "FAIL"
done

# Strict audit (reads from tap dir, not worktree)
for f in Formula/*.rb; do
  name=$(basename "$f" .rb)
  brew audit --strict "data-wise/tap/$name" 2>&1
done

# Ruby syntax check
for f in Formula/*.rb; do ruby -c "$f"; done
```
