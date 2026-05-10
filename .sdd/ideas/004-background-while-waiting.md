# Idea: Background-while-waiting — fill CR/CI deadtime with the next safe thing

**Captured:** 2026-05-10
**Status:** captured

## What's the idea?
When the agent is waiting on an external process (CodeRabbit review, CI run, deploy preview), don't sit idle — do the next safe thing in the queue.

**Always-safe set:**
- Re-read patterns.md / decisions.md / data-model.md to refresh internal model
- Pre-fetch context for the next feature's spec
- Pre-write the PR description for the current feature so `/ship` is one button when CR closes
- Draft commit messages

**Probably-safe set:**
- Speculative draft response to *likely* CR concerns ("the migrate tool will probably get questioned on Bash 3.2 compat — pre-write the response"). When CR fires, the agent has 80% of the reply ready.

**Don't-do-without-permission set:**
- Editing files outside current feature's scope
- Force-push, anything destructive
- Touching shared corpus files (patterns.md, decisions.md)

With multi-feature parallel work shipped (#42), the "next safe thing" is often "advance feature N+1 by one safe step" — the framework already knows what's in flight.

## What problem might it solve?
Push → CI → CR cycles take 15-30 minutes wall-clock. Today the agent (and Sam) sit there. That's pure unproductive deadtime.

## Why might it matter?
Doesn't make any single step faster, but doubles features-per-day if half the deadtime gets filled with productive next-feature work. **Most isolated of all the speed-improvement candidates** — least collision risk with other in-flight work. Best candidate to ship first if we want a quick win that doesn't block on coordination with other sessions.

## Confidence
pretty sure — extends the existing CodeRabbit-nudge memory ("don't sit through the timeout") into a broader "while you wait, do the next safe thing" doctrine.

## Related features
- #42 (parallel features — shipped)
- existing feedback_coderabbit_nudge.md
