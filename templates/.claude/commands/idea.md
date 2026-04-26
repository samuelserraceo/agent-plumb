---
description: Capture an idea to the backlog — single small file, no phase, no commitment to build.
---

$ARGUMENTS

Capture an idea cheaply. Ideas are NOT features. They live in `.sdd/ideas/` as a single small file with no phase progression. Promote to a feature later if/when they earn it.

## When to use

- User says "I just thought of…" / "we should consider…" / "park this idea"
- The thought might be valuable but isn't ready to spec yet
- You want it in git so it's not lost, but not committed to building

Do NOT use `/idea` for things the user clearly wants built now — that's `/next` (feature).

## Bootstrap

**Step 1 — Pick the idea id and slug.**
- Scan `.sdd/ideas/` for the highest existing `NNN-` prefix. New id = highest + 1.
- Slug from the user's description, kebab-case, ≤40 chars.
- File: `.sdd/ideas/<id>-<slug>.md`

**Step 2 — Create the file.**
- Copy `.sdd/rubric-idea.md` to `.sdd/ideas/<id>-<slug>.md`.
- Replace the `# Idea: <one-line summary>` heading with the actual one-liner.
- Set `**Captured:**` to today's date.
- Set `**Status:**` to `captured`.

**Step 3 — Ask the user the small set of idea questions** (in one message, since the rubric is tiny):
- What's the idea? (one paragraph)
- What problem might it solve? (rough)
- Why might it matter? (order-of-magnitude impact)
- Confidence: half-baked / pretty sure / urgent?
- Related features (if any)?

The whole capture should take 60 seconds. If the user is writing a paragraph per question, push back: "Ideas are cheap — give me the rough version, we'll go deeper if it gets promoted."

**Step 4 — Fill the file with their answers, commit on `main` (NOT a branch — ideas don't ship).**
```bash
git add .sdd/ideas/<id>-<slug>.md .sdd/INDEX.md
git commit -m "[SDD] idea: <id>-<slug> — <one-line summary>"
```

**Step 5 — Add to INDEX.md `## Backlog` (or new `## Ideas` section).**
- Format: `- ideas/<id>-<slug> — <one-line summary> — captured <YYYY-MM-DD>`
- If there's no `## Ideas` section yet, add one after `## Backlog`.

## Promotion path

If the user later says "let's actually build that idea":

1. Run `/promote-idea <id>` (separate command — Round 4 work, not yet implemented).
2. Until that exists, manually: `cp .sdd/ideas/<id>-<slug>.md .sdd/features/<new-id>-<slug>/spec.md`, copy the idea's "What's the idea" / "What problem" content into the feature spec's §1 / §2, then continue normal feature SPEC.

## End your turn

> Idea `<id>-<slug>` captured. Status: `captured`. It'll sit in the backlog until you promote it. Run `/idea` again any time you have another thought.
