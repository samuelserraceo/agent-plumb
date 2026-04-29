---
provider: coderabbit
display_name: CodeRabbit
category: pr-reviewer
records_in: ".sdd/config.md"
records_at: "parameters.review.bot"
---

# CodeRabbit install walkthrough

CodeRabbit is a GitHub app that reads every Pull Request you push and posts comments suggesting fixes (security issues, edge cases, simpler code, etc.). It's the most-used PR-reviewer bot the SDD framework integrates with — the framework's `/ship` flow polls CodeRabbit for its review and either auto-merges on a clean review or nudges via `@coderabbitai full review`.

## What this walkthrough does

The wizard runs this walkthrough automatically when you picked **CodeRabbit** at `/sdd-setup` brick 003 (PR reviewer). It gets you from "I want CodeRabbit" to "CodeRabbit is actually reviewing this repo's PRs" without you needing to remember anything beyond your GitHub login.

Total time: about 2 minutes if you have a GitHub account already.

## Skip this if

- You've already installed CodeRabbit on this repo (the agent verifies in step 3 below — if it's already there, the walkthrough no-ops cleanly).
- You'd rather install it yourself later. Reply `skip walkthrough` when prompted; the choice stays recorded in config.md and the agent re-prompts at first PR.

## The steps

The agent walks you through these one at a time. **Don't try to do them all at once** — the agent waits for your "done" reply between each step.

### Step 1: open CodeRabbit's install page

The agent runs `open https://coderabbit.ai/integrations/github` for you (or prints the URL if the `open` command isn't available). You see CodeRabbit's "Install on GitHub" page in your browser.

> **Agent says:** *"I've opened CodeRabbit's install page. Click 'Install' (top of the page). GitHub will ask which repos to install on — pick 'Only select repositories' and tick this one. Click 'Install & Authorize'. Reply `done` when you're back here."*

### Step 2: handle the GitHub permissions prompt

GitHub asks for read access to the repo (PRs, commits, comments) and write access to post review comments. CodeRabbit's permissions list is documented at `coderabbit.ai/docs/permissions` — the agent reads the latest list aloud if you ask.

> **Agent says:** *"GitHub will show CodeRabbit's permissions list — these are read access to your repo's pull requests and commits, plus write access to post comments on PRs. That's the minimum needed for it to do its job. Click 'Authorize' if it looks right. Reply `done` when GitHub redirects you back to CodeRabbit."*

### Step 3: agent verifies the install

After you reply `done`, the agent runs a two-step check against the GitHub API to confirm the install actually landed:

1. List the GitHub apps installed under the authenticated user's account:
   `gh api /user/installations --jq '.installations[] | select(.app_slug == "coderabbit-ai") | .id'`
2. If that returns an installation ID, list the repos that installation has access to and check the target repo is in there:
   `gh api "/user/installations/<id>/repositories" --jq '.repositories[].full_name'`

(For installs that live on an organisation rather than the user's own account, the agent falls back to `gh api /orgs/<org>/installations` with the same `app_slug == "coderabbit-ai"` filter.)

Three outcomes:

- **Installed** — CodeRabbit's installation ID came back AND the target `<owner>/<repo>` appears in that installation's repository list. Agent records `parameters.review.bot: coderabbit` in `.sdd/config.md`. Walkthrough completes.
- **Not installed** — `/user/installations` returns no entry with `app_slug == "coderabbit-ai"`. Agent says: *"GitHub doesn't show CodeRabbit installed yet. Common reason: you didn't pick this specific repo, or you cancelled before clicking Authorize. Want me to re-open the install page? (yes / no)"*. Yes loops back to step 1; no records `parameters.review.bot: coderabbit` with a `pending_install: true` flag and a follow-up reminder at first `/ship`.
- **Wrong repo** — CodeRabbit IS installed under the user/org, but the target repo isn't in its accessible repository list. Agent says: *"CodeRabbit is installed on your account but not on THIS repo. Open the install page and tick this repo specifically: github.com/settings/installations"*. Loop until installed or skip.

### Step 4: optional — seed `.coderabbit.yaml` config

CodeRabbit can be tuned via a config file at the repo root. The agent offers to create a sensible default:

> **Agent says:** *"Want me to create a `.coderabbit.yaml` with sensible defaults? It tells CodeRabbit to focus on security + correctness findings (not style nits) and skip files in test/fixtures or generated paths. (yes / no — I'll skip it)"*

If yes, the agent writes:

```yaml
# .coderabbit.yaml — CodeRabbit settings for this SDD project.
# See https://docs.coderabbit.ai/getting-started/configure-coderabbit
language: en
reviews:
  profile: chill
  request_changes_workflow: false
  high_level_summary: true
  poem: false
  review_status: true
  collapse_walkthrough: true
path_filters:
  - "!test/fixtures/**"
  - "!**/dist/**"
  - "!**/build/**"
  - "!**/*.min.js"
chat:
  auto_reply: true
```

This file is committed in the same commit as the brick 003 record so the install + config land together.

### Step 5: post-install smoke test (optional)

The agent offers: *"Want to push a small test PR to confirm CodeRabbit is reviewing? I can open a trivial change (typo fix in README) on a throwaway branch, push it, and we wait for CodeRabbit's review comment. Total time: 5-10 minutes if your GitHub plan is responsive. (yes / no — I trust the install verification)"*

If yes, the agent makes the trivial change, pushes, and polls the PR for CodeRabbit's first comment. If a comment lands within 5 minutes, the walkthrough confirms success and offers to delete the smoke-test branch. If no comment after 5 min, agent says: *"CodeRabbit hasn't responded yet. The install looks fine; review can take 5-15 minutes the first time. Continue, and check back later. The branch is left in place so you can verify."*

## What gets recorded after the walkthrough

```yaml
# .sdd/config.md — parameters.review.bot already recorded by brick 003
review:
  bot: coderabbit
  installed_via_walkthrough: true   # set after step 3 verification
  installed_at: "<ISO-Z timestamp>"
  poll_interval: 180
  max_polls: 5
  nudge_command: "@coderabbitai full review"
  manual: false
```

Plus optionally `.coderabbit.yaml` at the repo root from step 4.

## Failure recovery

If the walkthrough fails partway (network error, GitHub returns an error, agent's verify fails), the agent does NOT silently complete. It records the failure in `.sdd/decisions.md` with a stub:

```markdown
## <ISO-Z>  [setup]  walkthrough/coderabbit
CodeRabbit walkthrough failed at step 3 verification. Reason: <plain-English reason>.
Will re-prompt at next /ship or /sdd-config pr-reviewer.
```

And the choice in `config.md` gets `pending_install: true` so the framework knows to re-prompt later.
