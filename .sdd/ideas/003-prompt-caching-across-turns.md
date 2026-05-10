# Idea: Prompt caching across SDD turns (model "remembers" stable corpus)

**Captured:** 2026-05-10
**Status:** captured

## What's the idea?
Order the framework's prompt so the **stable** content (framework instructions, playbook contract, decisions.md, patterns.md, stack.md) comes first; **variable** content (current user turn, timestamps, turn-counters) comes last. Anthropic's prompt cache picks up the identical prefix and serves it at much lower latency + cost on subsequent turns within ~5 minutes. Same idea works on other providers via their cache APIs (Anthropic = explicit cache breakpoints; OpenAI = automatic; Google = explicit) — abstract via a per-provider adapter rather than reinventing.

Avoid common cache-killers:
- Timestamps inside the prefix
- Turn numbers / counters inside the prefix
- Random session IDs in the prefix
- Hooks injecting fresh content at the **top** of system prompt instead of the bottom

## What problem might it solve?
Today every turn re-reads the full framework + corpus context — at session start the inject was ~70KB just for the SDD state hook. 70-80% of that is identical turn-to-turn. Without caching, the model re-processes it every time = unnecessary latency + cost.

## Why might it matter?
Estimated 20-30% per-turn latency reduction once the prompt is ordered correctly. Costs nothing to implement beyond ordering discipline. Compounds with idea 002 (lego models) — cache + cheaper tier multiplies the savings.

## Confidence
pretty sure — well-understood lever, mostly plumbing.

## Related features
- Idea 002 (lego models — cache adapter is per-provider too, share the abstraction)
- SDD's existing hook injection currently puts state at the **top** which may already be killing cache hits — worth measuring before redesigning
