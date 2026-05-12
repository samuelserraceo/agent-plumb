---
description: Dispatch a specialised subagent (researcher / executor / verifier) with a fresh context and a role-tuned system prompt.
---

$ARGUMENTS

You are about to **dispatch a fresh-context subagent** with a role-specific system prompt. The argument shape is `<role> <task>` — for example, `/dispatch verifier "Audit §11 ACs against the current diff"`.

## What to do

1. **Parse the argument.** Split `$ARGUMENTS` at the first whitespace. The first token is `<role>`. The rest is `<task>`. If `<role>` is missing or `<task>` is empty, tell the user the shape and stop: *"Usage: `/dispatch <role> <task>` — role is one of researcher / executor / verifier. Try again with both arguments."*

2. **Resolve the role file.** The role file lives at `.sdd/agents/<role>.md`. The three roles that ship with SDD are:
   - **researcher** — reads, searches, synthesises. Returns a written synthesis; does NOT write code.
   - **executor** — runs one BUILD task end-to-end (test → code → green → commit). Returns the commit SHA.
   - **verifier** — reads §11 ACs + `git diff`. Returns an AC-coverage report; does NOT write code.

3. **If `.sdd/agents/<role>.md` does not exist:** tell the user, in plain English: *"No agent role file at `.sdd/agents/<role>.md`. The three roles that ship with SDD are `researcher`, `executor`, `verifier`. If you meant one of those, check it's there and try again. If you've added a custom role, confirm the filename matches the role name in the frontmatter."* Stop.

4. **Dispatch the subagent.** Use Claude Code's Agent tool to spawn a fresh-context subagent. The role file's body (everything after the YAML frontmatter) becomes the subagent's system prompt. The `<task>` string becomes the user message. **Do not answer the task yourself in the main agent's voice — dispatch a real subagent.** The whole point of `/dispatch` is the fresh context; answering in-line defeats it.

5. **Honour the role's frontmatter contract.** The frontmatter declares:
   - `role:` — must match the filename basename.
   - `model_tier_default:` — one of `thinking` / `routine` / `mechanical`. Pass this to the Agent tool if model selection is supported in the harness you are running (Claude Code reads `parameters.models.<tier>` from `.sdd/config.md` per F015). If model selection is not configurable in your harness, the default model is used.
   - `tools_allowed:` — advisory list of tools the subagent should rely on. Not mechanically enforced in v1 (a follow-up may add a hook-level filter); pass it through to the subagent's prompt as a soft hint.

6. **Relay the subagent's output back to the user verbatim.** Do not paraphrase or summarise. The subagent already produced a tight output (per its role prose); your job as the main agent is to surface it cleanly.

7. **Stop.** One dispatch per `/dispatch` invocation. If the user wants another role to follow up, they run `/dispatch` again.

## When to use which role

- **Need to understand something without writing code** → `/dispatch researcher "<question>"`. Use for codebase exploration, dependency research, WebFetch, third-party API discovery, OSS-package shopping (anti-NIH doctrine).

- **Need to run one BUILD task end-to-end** → `/dispatch executor "<task description from §14>"`. Use during BUILD when the main agent's context is heavy and a fresh executor would write cleaner code. Pairs with F010 parallel waves: each wave-task is one executor dispatch.

- **Need to audit whether the current diff covers §11 ACs** → `/dispatch verifier "Audit §11 ACs against current diff"`. Use before pushing the SHIP PR. Catches gaps before CR finds them.

When unsure: ask yourself "is this READ work, WRITE work, or CHECK work?" Researcher = READ, executor = WRITE, verifier = CHECK.

## Backwards compat

This command is **opt-in**. The existing `/next` flow still works monolithically — the main agent walks every step in one context. `/dispatch` is an addition for users who want to optimise long features or cost-optimise per role.

## Custom roles

Any markdown file under `.sdd/agents/<custom-role>.md` with the same frontmatter shape (`role`, `model_tier_default`, `tools_allowed`) is dispatchable. Add a `debugger.md` or `planner.md` if your project earns it — but resist forest-of-subagents temptation per SDD's Pillar 1 (simplicity). The three that ship cover 80% of the value; add a fourth only when a pattern is unmistakable.
