# Status Guard

Required check on every pull request. Job name: **Check .STATUS for conflict markers**.

## What It Checks

Fails if `.STATUS` contains a literal unresolved git merge-conflict marker (`<<<<<<<`,
`=======`, `>>>>>>>`) — a leftover from a botched rebase/merge that was committed by mistake.
`.STATUS` is hand-edited frequently, often across concurrent worktrees/sessions, making it a
plausible place for a stray marker to slip through unnoticed.

Script: `generator/check-status-conflict-markers.sh`.

## Self-Skipping (Path-Aware Without a Path Filter)

The `pull_request` trigger has **no path filter** — it runs on every PR. A job-level step
(`Determine whether .STATUS changed`) diffs the PR against its base ref and skips the real
check fast (a few seconds) when `.STATUS` wasn't touched.

This matters because **required status checks have no path-awareness of their own**: a
path-filtered trigger left this check permanently "expected — waiting" (and the PR permanently
blocked) on any PR that didn't touch `.STATUS` — GitHub doesn't skip a required check just
because its workflow never ran, it waits forever. See
[SPEC-required-checks-self-skip-2026-07-19.md](https://github.com/Data-Wise/homebrew-tap/blob/main/docs/specs/SPEC-required-checks-self-skip-2026-07-19.md)
for the full incident and fix (same pattern applied to
[Formula Drift Guard](drift-guard.md)).

**Fail-closed contract:** if the base-ref/diff resolution itself errors, the job **fails** rather
than skips — an unresolvable "what changed?" is never treated as "nothing changed," which would
make this required check always green while checking nothing.

`push` events stay path-filtered (`.STATUS`) — unaffected by the self-skip change; only
`pull_request` runs unconditionally.

## Running Locally

```bash
bash generator/check-status-conflict-markers.sh .STATUS
```
