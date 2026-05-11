---
id: automation-level
title: "Automation level for AGENT-LED steps (Full / Most / Checkpoint)"
when: start
records_in: ".sdd/config.md"
records_at: "parameters.automation.level"
agent_infers: []
---

# Automation level — how much should the framework auto-advance for you?

Today the framework asks you to type `approve` at every AGENT-LED step in SPEC and SHIP — even when the agent's proposal is purely technical (no product/business/scope call for you to make). For a non-technical user that's a lot of clicks; for a technical user it's interruption tax. F011 lets you pick how much auto-advancement you want.

Three options (you can change later via `/sdd-config automation <tier>`):

- **Full** — auto-advance every AGENT-LED step where the action's frontmatter says it doesn't need your approval (the framework's `requires_user_approval: false` flag). The agent commits + advances silently on those. **Trade-off:** fastest. You only see questions for steps that need YOUR product/business/scope call — things like §1 problem (USER-LED — that's your input), §5 proposed-approach (still asks because architectural choice IS your call), §11 acceptance criteria (your contract). Recommended once you've watched a couple of walks and trust the framework's defaults.

- **Most** — auto-advance most AGENT-LED steps **but** still ask for approval on **destructive** actions: `mark-shipped` (writes the .shipped marker), manifest-repin commits (changes the framework's tamper-pin), `--delete-branch` merges, `decisions.md` append-only edits, `.shipped` marker writes. **Trade-off:** fast + safety gate. The agent doesn't touch the things-you-can't-undo without checking with you first.

- **Checkpoint** — today's behaviour. The agent asks `approve?` at every AGENT-LED step. **Trade-off:** slowest, safest. Best for your first week with the framework while you learn what each action does.

**Default: Checkpoint.** New projects start safe; opt up to Most or Full when you're comfortable. This question runs once at project start; change anytime via `/sdd-config automation <tier>`.

**What it looks like:**

> *Question:* "Automation level for AGENT-LED steps — Full / Most / Checkpoint?"
> *Sam:* "Most."
> *Agent:* "Writing `parameters.automation.level: most` to `.sdd/config.md`. From now on technical AGENT-LED steps auto-advance, but `mark-shipped`, manifest repins, branch deletions, and `decisions.md` edits will still ask you to approve. You can switch to Full or back to Checkpoint anytime with `/sdd-config automation <tier>`."
