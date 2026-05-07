# Refresher block — ground the user before every action's question

> **Purpose.** Every USER-LED action and every AGENT-LED-with-approval action references this skeleton. Before issuing the action's question, the agent emits a 3-line refresher to ground the user in *what* is being built, *what* this question asks, and *why* now. Closes [#171](https://github.com/samuelserraceo/spec-driven-dev-workflow/issues/171) — non-technical users were losing context across actions because each `/next` jumped straight to the next question without resurfacing what feature they're in.

## When to emit

- **Always:** at the start of every action's user-facing turn, BEFORE the question.
- **Skip:** within-action continuations. §1 Problem has three step rows (`who`, `pain`, `today`); they share context, so the refresher fires once at §1's start, not three times. Same pattern for any action whose `steps:` array has multiple entries.

## Format (plain English, no jargon)

```
**Where we are:** <feature/project name> — <one-line plain-English summary
of what this thing does for the user once it ships>. Pull from spec.md §1
prose; do not paraphrase from memory.

**Today's question (§N <action-slug>):** <what this question is asking, in
plain English. Translate any technical term on first use per CLAUDE.md
"Non-technical user lens".>

**Why now:** <why this question precedes the rest of SPEC. One line.>
```

Then ask the action's question below.

## What good looks like

✅ **Good:**

> **Where we are:** F01 Auth + canvas shell — log in, then see every Topishop database table on one screen at /map.
>
> **Today's question (§3 user-stories):** who uses this and what do they want to do? 1-5 short stories in the shape *"as <persona>, I want <action>, so that <outcome>."*
>
> **Why now:** §1 captured the WHY; §3 turns that into concrete user-shaped goals that §4 wireframe and §11 acceptance criteria will design against.

❌ **Bad** (jargon, abstract, missing context):

> Now we're at section 3, user-stories. This is a USER-LED step. Provide your stories in the standard format.

The bad version reads like an engineer talking to a database. The good version reads like a colleague catching the user up before asking a question.

## Plain English first (cross-references CLAUDE.md)

- Every technical term gets a translation on first use.
- Describe by what things DO for the user, not what they ARE.
- If you catch yourself writing prose a non-technical person can't read in 30 seconds, rewrite before showing.

## Mechanical enforcement

The lint at `templates/.sdd/scripts/lint-action-prose.sh` asserts every USER-LED + AGENT-LED-with-approval action references this skeleton. Removing the reference fails the lint at commit time.
