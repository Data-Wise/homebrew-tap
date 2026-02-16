# Formula Validation

Weekly automated validation of all formulas.

## Schedule

Runs every Monday at 06:00 UTC via `validate-formulas.yml`. Can also be triggered manually via `workflow_dispatch`.

## What It Checks

### brew audit --strict

Runs `brew audit --strict` on all 14 formulas using tap-qualified names (`data-wise/tap/<name>`). Reports pass/fail count and lists any failing formulas.

### ruby -c

Runs Ruby syntax check on all formulas. Catches syntax errors that would break Homebrew.

## Output

Results are written to the GitHub Actions step summary with a pass/fail table.

## Running Locally

```bash
# Strict audit (must use tap name, reads from tap dir)
for f in Formula/*.rb; do
  name=$(basename "$f" .rb)
  brew audit --strict "data-wise/tap/$name" 2>&1
done

# Style check (accepts file paths)
for f in Formula/*.rb; do
  echo -n "$(basename "$f" .rb): "
  brew style "$f" >/dev/null 2>&1 && echo "PASS" || echo "FAIL"
done

# Ruby syntax check
for f in Formula/*.rb; do ruby -c "$f"; done
```
