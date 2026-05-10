# Idea: Parallel wave execution with fresh per-wave contexts

**Captured:** 2026-05-07
**Status:** captured

## What's the idea?

Today SDD walks a spec strictly linearly — one atomic step, one commit, in order. This idea adds a **parallel wave** capability where independent BUILD tasks (or independent SPEC sub-questions) can run simultaneously in fresh agent contexts, then their results merge back into the main spec. GSD's `/gsd-execute-phase` already does this via "parallel waves with fresh contexts per executor" — each plan in a phase gets its own clean 200K-token window, runs to completion, and reports back. SDD would adopt a smaller version: identify which BUILD tasks have no inter-dependencies, dispatch them as a wave, collect results, integrate.

## What problem might it solve?

Two real costs today:
1. **Linear walk wastes wall-clock time** when 5 BUILD tasks are independent — they're done one after the other, not three-at-once.
2. **Single-context drift** — running 30+ atomic steps in one Claude session means the main agent's context fills up, quality degrades. GSD calls this "context rot" and uses fresh subagent contexts per task to avoid it.

## Why might it matter?

For features with many small independent BUILD tasks (e.g. "add 8 lint rules", "scaffold 5 endpoints", "wire up 6 form fields"), wave execution could finish a phase in a fraction of the wall-clock time. More importantly, **fresh-context-per-task is a quality argument, not just a speed argument** — Claude on a clean context outperforms Claude on a 60-turn context every time. Sam explicitly said "this is something I really want to execute" when shown this in the GSD comparison.

The killer combo is **wave execution × multi-model** (idea 001): waves of cheaper models running in parallel, with the main agent acting as orchestrator. That's the actual cost-and-quality win.

## Confidence

Pretty sure on the value, half-baked on the design. SDD's atomic-step doctrine ("one step = one commit") needs careful re-thinking to allow waves without breaking the audit trail. Open questions: How does the main agent verify each wave-task's commit was clean? What happens when wave-task A's RED test references code that wave-task B is writing? How do we detect and reject inter-task dependencies *before* dispatching the wave? GSD has answers to these — worth studying their `gsd-executor` agent and the wave-coordination logic before designing ours.

## Related features

- `001-multi-platform-pi-adapter` — multi-model is the natural pair for parallel waves (cheaper-model executor + main-model orchestrator)
- `003-specialized-subagents` — wave executors are themselves a form of specialised subagent
