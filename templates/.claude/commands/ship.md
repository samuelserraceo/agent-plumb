---
description: Ship the active feature — push branch, open/update PR, watch CI, capture bugs or mark shipped.
---

Ship the active feature.

## Preconditions (check before running the shell script)

1. There is an active feature in `.sdd/INDEX.md`.
2. Its `spec.md` is in phase `VERIFY` with all tests GREEN and human sign-off ticked. Run `/verify` equivalents if unsure.
3. The working tree is clean (or has only the final commit you want to push).

If any precondition fails, tell the user what's missing and stop.

## Run the shipping script

```bash
./scripts/ship.sh
```

The script will:
1. Push the feature branch (`sdd/<id>-<slug>`).
2. Open a PR with body auto-generated from the spec (problem, user stories, acceptance results, sign-off).
3. `gh pr checks --watch` until CI returns.
4. If CI **passes**: mark the feature `[SHIPPED]` in INDEX.md, append a line under `## Shipped`, clear the `**Active:**` pointer, commit.
5. If CI **fails**: capture the error log, append a `[ ] bug: <summary>` task to the PLAN section of `spec.md`, flip `[PHASE: VERIFY]` back to `[PHASE: BUILD]`, commit. Next `/next` picks up the fix.

## Report to the user

After the script completes, tell the user:
- The PR URL.
- Pass/fail outcome.
- Next action: "Merge the PR when you're ready" (on pass) or "`/next` to work the bug task" (on fail).
