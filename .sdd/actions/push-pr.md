---
type: action
slug: push-pr
tag: AGENT-LED
title: "push-pr"
short_label: "Push PR"
steps:
  - { id: push, action: "push the branch and open a PR with spec.md as the body", field: "spec.md" }
used_by: [feature]
references: [problem, success, learn, plan-decompose]
touches: []
requires_setup: [where-it-runs]
trust: framework
budget:
  max_minutes: 10
  max_tokens: 3000
  max_commits: 1
requires_user_approval: false
---

Push the feature branch to origin and open a PR against `main`.

**Pre-flight: setup-answer check (closes #68).** Before running the action sequence below, the agent runs:

```bash
bash .sdd/scripts/check-setup-answer.sh where-it-runs
```

If the user answered "Not deciding yet" to brick 005 (where-it-runs) at /sdd-setup time, this check exits 1 and prints the recovery instruction. The agent HALTS and tells the user in plain English:

> *"You said 'not deciding yet' for hosting at setup time. Now we're at push-pr — the framework needs to know what to deploy to. Run `/sdd-config where-it-runs` to pick a hosting target. Then re-run /next."*

Don't try to invent a default. Don't continue to git push without an answer. The whole point of `requires_setup:` in the action frontmatter is to force the deferred answer to be filled in BEFORE the dependent action runs.

If the check passes (the user has a real answer in stack.md `## Running services`), proceed to the action sequence below.

**Action sequence:**
1. `git push -u origin <feature-branch>` — push the branch
2. Auto-generate PR title from §1 Problem (one-line summary). Title must be plain alphanumeric + spaces — strip any backticks, quotes, or shell-meaningful characters
3. Auto-generate PR body from §1, §2, §3, plan-decompose summary
4. **Write the body to a tempfile** at `.sdd/<work-item>/pr-body.tmp` (where `<work-item>` is the actual feature folder shape `features/<id>-<slug>` / `bugs/<id>-<slug>` / `refactors/<id>-<slug>` — match the shape used by spec.md, never just `<id>`) — never inline body content into the shell command (spec content is user-controlled, so inlining risks shell-injection / quoting breaks)
5. `gh pr create --title "<plain-title>" --body-file .sdd/<work-item>/pr-body.tmp` (always `--body-file`, never `--body`)
6. Capture the PR URL from gh's output
7. Delete the tempfile: `rm .sdd/<work-item>/pr-body.tmp`
8. Tell the user the PR is open + the URL

**Required PR body sections:**
- **Summary** — 1-3 bullets from §1 Problem + §2 Success (what the feature does, why it matters)
- **Test plan** — checklist of ACs from §11, one box per AC, all unchecked at PR-open
- **Spec link** — `See: features/<id>-<slug>/spec.md` (one line, anchors reviewers to the full spec)

**CI trigger:** the PR auto-runs CI checks (tests, lint, type checks, etc.). The next action (verify-ci-green) waits for them.

**On push failure:** if `git push` fails (no remote, auth issue, force-push needed), HALT and tell the user. Don't `--force` push to a shared remote without explicit user confirmation.

**Output:** fill `spec.md` under `### push-pr` with `**PR URL:** <github-link>`.

**What it looks like:**

Time to open the pull request so the review tools can have at it.

Example: *"I'll write a PR title (under 70 chars), a body that explains in 3 bullets what this changes and why, a test plan checklist for what reviewers should verify, and link to any issues this closes (#97, #112). Then I run `gh pr create` against `main` and give you the URL."*

**End the turn with:** *"PR open at `<URL>`. CI is running. Run `/next` to verify CI green."*
