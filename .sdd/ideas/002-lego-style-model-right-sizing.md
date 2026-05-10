# Idea: Lego-style model right-sizing per step (Claude-only + pi.dev port)

**Captured:** 2026-05-10
**Status:** captured

## What's the idea?
Each playbook step declares its **tier** (thinking / routine / mechanical) — not its specific model. Framework picks the actual model per tier from project config. Same idea works for the Claude-only plugin (Opus / Sonnet / Haiku) and the pi.dev port (any API-based model: Claude / GPT / Gemini / local Ollama). Project config maps tier → provider+model.

Layered on top:
- **Confidence escalation** — start at the cheapest tier; if the model flags uncertainty or makes a catchable mistake, retry one tier up. Average cost lower than statically picking thinking-tier; worst case same.
- **Per-feature cost ceiling** — "don't spend more than $X on this feature."
- **Fallback chain** — Opus rate-limited → Sonnet. Anthropic down → GPT. Keeps the loop moving.
- **Capability dimension on top of tier** — "thinking + long context" vs "thinking + vision" routes to different providers. More relevant for pi.dev.
- **Two whole-feature presets** — "go fast" (cheap end of every tier), "go careful" (expensive end). One toggle per feature.
- **Cost visibility per feature** — `/ship` reports "$X total: SPEC $a, BUILD $b, SHIP $c."

Uses existing OSS for routing where available (e.g. `litellm` already does tier + fallback).

## What problem might it solve?
Today every step runs on whatever model the user happens to be on. Mechanical steps (mark-shipped, sdd-migrate run, format INDEX, write PR description) waste thinking-tier throughput when a cheaper model would handle them faster with no quality loss. Framework also locks to one provider — pi.dev port specifically wants users to mix.

## Why might it matter?
Estimated 30-50% reduction in average per-turn latency. Cost reduction comparable. Especially valuable on pi.dev where mixing providers is the explicit point. Compounds with prompt caching (idea 003) — cache + cheaper tier multiplies.

## Confidence
pretty sure — well-understood lever. Main risk is misclassifying steps (some "mechanical" looking ones actually need thinking-tier — e.g. writing acceptance criteria looks formatting-shaped but requires understanding).

## Related features
- pi.dev port (separate session)
- Touches nearly every action file (highest collision risk among the speed levers)
- GSD plugin's `/gsd:set-profile` is prior art
