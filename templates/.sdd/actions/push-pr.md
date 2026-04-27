---
type: action
slug: push-pr
tag: AGENT-LED
title: "push-pr"
short_label: "Push PR"
bundling: n_a
used_by: [feature]
references: [problem, success, learn, plan-decompose]
touches: []
trust: framework
budget:
  max_minutes: 10
  max_tokens: 3000
  max_commits: 1
requires_user_approval: false
---

Push the feature branch to origin and open a PR against `main`.

**Action sequence:**
1. `git push -u origin <feature-branch>` — push the branch
2. Auto-generate PR title from §1 Problem (one-line summary)
3. Auto-generate PR body from §1, §2, §3, plan-decompose summary
4. `gh pr create --title "<title>" --body "<body>"` (or whatever the project's PR-open command is)
5. Capture the PR URL from gh's output
6. Tell the user the PR is open + the URL

**CI trigger:** the PR auto-runs CI checks (tests, lint, type checks, etc.). The next action (verify-ci-green) waits for them.

**On push failure:** if `git push` fails (no remote, auth issue, force-push needed), HALT and tell the user. Don't `--force` push to a shared remote without explicit user confirmation.

**Output:** fill `spec.md` under `### push-pr` with `**PR URL:** <github-link>`.

**End the turn with:** *"PR open at `<URL>`. CI is running. Run `/next` to verify CI green."*
