# Idea: Plain-English sweep of SDD's own prose (match brief-builder v0.4 rewrite)

**Captured:** 2026-05-10
**Status:** captured

## What's the idea?
Brief-builder v0.4 rewrote its prose top-to-bottom for plain English: "lint gate" → "quality check", "decision-encoding word" → "fuzzy word that hides a real rule", "watchword list" → drill examples in plain language. Sentence shape: notes from a colleague, not docs from a robot.

SDD's own prose still uses framework-internal vocabulary that could trip the same non-technical confusion Sam hit on §4a vs §11 mockups during the brief-builder test. Examples worth surveying:

- "AGENT-LED" / "USER-LED" action prefixes
- "stop-lint invariants"
- "data contract" (§6 of the feature playbook)
- "wireframe action"
- "doctrine" used as a noun
- "marker check" / "manifest repin"
- Section labels in `actions/*.md` files

Some of these are intentional internal vocabulary the framework uses to itself (and the agent uses to reason about itself); some are user-facing and could be plain-English'd without losing precision.

## What problem might it solve?
Reduces the same class of non-technical-user confusion Sam hit on the §4a/§11 mockup question — wording is correct under the framework's rules but reads as jargon to a non-technical reader. Today's plain-English doctrine (#110, `feedback_framework_prompts_plain_english.md`) caught some prose; brief-builder v0.4 went further and would catch more.

## Why might it matter?
Friction reduction across every conversation, not just the speed-improvements stack. Compounds with idea 005 (auto-advance) — fewer prompts Sam has to read AND clearer prose when he does. Also keeps SDD's prose at the same plain-English bar as the brief-builder it integrates with — coherent reading experience between the two plugins.

## Confidence
half-baked — needs a survey pass first to separate user-facing prose (which should be swept) from internal framework vocabulary the agent uses to itself (which can stay). Not all jargon is bad; some is the framework's working vocabulary.

## Related features
- #110 (plain-English framework prompts — partial coverage today)
- `feedback_framework_prompts_plain_english.md` (existing memory)
- `feedback_plain_english.md` (Sam's general non-technical-user preference)
- brief-builder v0.4 release (recent shipped reference for what "fully plain English" looks like)
