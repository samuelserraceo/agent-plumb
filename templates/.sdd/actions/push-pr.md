---
type: action
slug: push-pr
tag: AGENT-LED
title: "push-pr"
short_label: "Push PR"
steps:
  - { id: push, action: push_branch_open_pr_with_spec_md_body, field: "spec.md" }
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
2. Auto-generate PR title from §1 Problem (one-line summary). Title must be plain alphanumeric + spaces — strip any backticks, quotes, or shell-meaningful characters
3. Auto-generate PR body from §1, §2, §3, plan-decompose summary
4. **Write the body to a tempfile** at `.sdd/features/<id>/pr-body.tmp` — never inline body content into the shell command (spec content is user-controlled, so inlining risks shell-injection / quoting breaks)
5. `gh pr create --title "<plain-title>" --body-file .sdd/features/<id>/pr-body.tmp` (always `--body-file`, never `--body`)
6. Capture the PR URL from gh's output
7. Delete the tempfile: `rm .sdd/features/<id>/pr-body.tmp`
8. Tell the user the PR is open + the URL

**Required PR body sections:**
- **Summary** — 1-3 bullets from §1 Problem + §2 Success (what the feature does, why it matters)
- **Test plan** — checklist of ACs from §11, one box per AC, all unchecked at PR-open
- **Spec link** — `See: features/<id>-<slug>/spec.md` (one line, anchors reviewers to the full spec)

**CI trigger:** the PR auto-runs CI checks (tests, lint, type checks, etc.). The next action (verify-ci-green) waits for them.

**On push failure:** if `git push` fails (no remote, auth issue, force-push needed), HALT and tell the user. Don't `--force` push to a shared remote without explicit user confirmation.

**Output:** fill `spec.md` under `### push-pr` with `**PR URL:** <github-link>`.

**End the turn with:** *"PR open at `<URL>`. CI is running. Run `/next` to verify CI green."*
