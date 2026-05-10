# Idea: Specialized subagents — planner / executor / verifier / debugger sub-roles

**Captured:** 2026-05-07
**Status:** captured

## What's the idea?

Today SDD has zero specialised subagents — the same single agent walks every step (USER-LED, AGENT-LED, BUILD-TASK). This idea introduces a small set of **specialised sub-roles** that the main agent can dispatch to for specific kinds of work: a planner, an executor, a verifier, a debugger, maybe a researcher. GSD ships **18** subagents (gsd-planner, gsd-executor, gsd-verifier, gsd-debugger, gsd-codebase-mapper, gsd-integration-checker, gsd-phase-researcher, gsd-plan-checker, gsd-nyquist-auditor, etc.). SDD would start with **far fewer** — probably 4-5 — to stay true to Pillar 1 (Simplicity), then grow only when a sub-role earns its keep.

## What problem might it solve?

Today the main agent does everything in one context:
- Researching the codebase (huge token cost — eats context)
- Drafting plans
- Writing code
- Verifying acceptance criteria
- Debugging when something fails

Each of these has different optimal tooling, prompting, and even model choice. Stuffing them all into one context means the main agent is good at none of them, and its context window fills up with research notes that aren't useful 5 turns later. Specialised subagents with clean contexts and role-specific prompts would each be sharper at their job.

## Why might it matter?

Three concrete wins:
1. **Context-rot mitigation** — research findings stay in the researcher's session; the planner only sees the synthesis. Same for verifier and debugger.
2. **Cost optimisation when paired with multi-model (idea 001)** — researcher = Haiku/open-weight (cheap, lots of context); planner = Opus (quality matters); executor = Sonnet (balance); verifier = Haiku again. GSD already does this via "model profiles."
3. **Better outputs per role** — a verifier subagent prompted *only* to find acceptance-criteria gaps will catch more gaps than a generalist agent that's also writing code.

This idea is most useful **after** 001 (multi-model) and 002 (parallel waves) — the three together unlock the real GSD-class capability. Alone, specialised subagents are still a win (cleaner contexts, better outputs), but the cost-savings story is muted on a single-model setup.

## Confidence

Pretty sure this is needed eventually, half-baked on which sub-roles to pick. SDD's identity is simplicity — copying GSD's 18-subagent forest would betray that. The question to answer first: *what is the smallest set of subagents that delivers 80% of the value?* Plausible starter set:
- **researcher** — codebase exploration + WebFetch, returns synthesis
- **executor** — runs a single BUILD-TASK, returns commit SHA
- **verifier** — reads spec + diff, reports AC gaps

Three subagents instead of eighteen. Add `debugger` and `planner` only when the patterns earn it.

## Related features

- `001-multi-platform-pi-adapter` — model profiles per role only make sense once SDD reaches multiple models
- `002-parallel-wave-execution` — wave executors ARE specialised subagents; the two ideas overlap and may converge
