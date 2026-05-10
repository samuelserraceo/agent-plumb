# Idea: Auto-advance through agent-led steps (no "click next" on technical steps)

**Captured:** 2026-05-10
**Status:** captured

## What's the idea?
Default `requires_user_approval` on most playbook actions to **FALSE**. Only stop at steps that need genuine product / business / scope judgement from the user. Setup wizard adds an "automation level" question at project start:

- **Full** — every requires_user_approval=false action runs without confirmation; only product-judgement steps stop
- **Most** — same but stops on anything potentially destructive
- **Checkpoint** — today's behaviour (current default)

Builds on the existing `feedback_full_autonomous_build.md` memory (BUILD-mode autonomy already established for Sam). This idea extends the same doctrine across SPEC and SHIP, not just BUILD.

## What problem might it solve?
Today the user clicks "next" on every step, even purely technical ones. Every click is wall-clock time + flow break + (Sam's words) "wasting my time and insulting my intelligence." Wastes the framework's biggest leverage — that the agent CAN do most steps unattended.

## Why might it matter?
The most **behaviorally felt** of the speed levers — touches every conversation, not just internal infrastructure. Costs nothing to implement (flag flips + setup question). Already partially scoped in #207 (§13 wireframe, §15 edge-case-sweep flagged for `requires_user_approval: false`).

## Confidence
pretty sure — already established as doctrine for BUILD; just needs to extend across the other phases and add the setup-time toggle.

## Related features
- #207 (v1.6 anchor — already lists §13 and §15 candidates)
- `feedback_full_autonomous_build.md` (BUILD-mode autonomy — established)
- `feedback_decide_dont_ask.md` (NEW 2026-05-10 — same doctrine at the conversation layer)
