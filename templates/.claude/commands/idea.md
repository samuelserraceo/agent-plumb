---
description: Capture an idea to the backlog — single small file in .sdd/ideas/, no commitment to build.
---

$ARGUMENTS

Capture an idea cheaply. Ideas live in `.sdd/ideas/<id>-<slug>.md` as a single small file. They have NO phase progression and NO commitment to build — promote later if/when they earn it.

## When to use

- "I just thought of…" / "we should consider…" / "park this idea"
- The thought might be valuable but isn't ready to spec yet
- You want it in git so it's not lost, but not committed to building

Don't use `/idea` for things the user clearly wants built now — that's `/start` (feature) territory.

## What to do

**Step 1 — pick the idea id and slug.**
- Scan `.sdd/ideas/` for the highest existing `NNN-` prefix. New id = highest + 1, zero-padded (`001`, `002`, …). If `.sdd/ideas/` doesn't exist, create it.
- Slug from the user's description, kebab-case, ≤40 chars, ASCII only.
- File path: `.sdd/ideas/<id>-<slug>.md`.

**Step 2 — ask the small question set in ONE message** (idea capture is fast — ≤60 seconds total):

- What's the idea? (one paragraph)
- What problem might it solve? (rough)
- Why might it matter? (order-of-magnitude impact)
- Confidence: half-baked / pretty sure / urgent?
- Related features (if any)?

If the user starts writing a paragraph per question, push back: *"Ideas are cheap — give me the rough version, we'll go deeper if it gets promoted."*

**Step 3 — write the file** (inline structure, no template needed):

```markdown
# Idea: <one-line summary>

**Captured:** <YYYY-MM-DD>
**Status:** captured

## What's the idea?
<their answer>

## What problem might it solve?
<their answer>

## Why might it matter?
<their answer>

## Confidence
<half-baked | pretty sure | urgent>

## Related features
<comma-separated feature IDs, or "none">
```

**Step 4 — update `.sdd/INDEX.md`.** Add to `## Backlog` (or create a `## Ideas` section after Backlog if it doesn't exist):
- Format: `- ideas/<id>-<slug> — <one-line summary> — captured <YYYY-MM-DD>`

**Step 5 — commit on the current branch.** No new branch — ideas don't ship on their own.

```bash
git add .sdd/ideas/<id>-<slug>.md .sdd/INDEX.md
git commit -m "[SDD] idea: <id>-<slug> — <one-line summary>"
```

## Promotion path

When the user later says "let's actually build idea X":

1. Run `/start <description that incorporates the idea>`.
2. In §1 Problem of the new feature, reference the idea file: *"Originated from [`.sdd/ideas/<id>-<slug>.md`](.sdd/ideas/<id>-<slug>.md) — see for context."*

(Phase C may ship `/promote-idea <id>` for a smoother promotion path.)

## End your turn

> Idea `<id>-<slug>` captured. Status: `captured`. It'll sit in the backlog until you build it. Run `/idea` again any time you have another thought, or `/start <title>` when you're ready to build something.
