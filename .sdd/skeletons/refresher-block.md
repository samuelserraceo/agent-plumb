# Refresher block — ground the user before every action's question

> **Purpose.** Every USER-LED action and every AGENT-LED-with-approval action references this skeleton. Before issuing the action's question, the agent emits a **3-section** refresher (Where we are / Today's question / Why now) to ground the user in *what* is being built, *what* this question asks, and *why* now. Closes [#171](https://github.com/samuelserraceo/spec-driven-dev-workflow/issues/171) — non-technical users were losing context across actions because each `/next` jumped straight to the next question without resurfacing what work-item they're in.

## When to emit

- **Always:** at the start of every action's user-facing turn, BEFORE the question.
- **Skip:** within-action continuations. §1 Problem has three step rows (`who`, `pain`, `today`); they share context, so the refresher fires once at §1's start, not three times. Same pattern for any action whose `steps:` array has multiple entries.

## Source-of-truth per work-item mode

The "Where we are" line quotes **verbatim** from the work item's §1 prose — *the spec's first paragraph, exactly as the user wrote it; never paraphrase from memory.* The §1 contents differ by mode:

| Work-item mode    | §1 source-of-truth prose                                          |
|-------------------|--------------------------------------------------------------------|
| **feature**       | §1 Problem prose — *who has it / why-now / what-breaks*            |
| **project**       | §1 Vision prose — *what we're building, who for, the desired state*|
| **bug**           | §1 Reproduction prose — *what was tried, what happened, what was expected* |
| **refactor**      | §1 Scope prose — *what's getting moved, why, the boundary*          |

### "§1 not yet written" fallback — the chicken-and-egg case

The first action of any work-item *fills* §1, so quoting verbatim from §1 is impossible the first time around. This applies to: `problem` (feature), `project-problem` (project), `bug-repro` (bug), `refactor-scope` (refactor). For these specific actions, follow this fallback shape:

```text
**Where we are:** <work-item identifier> — *§1 hasn't been written yet
because we're at the very first action; everything below is
groundwork for filling it. The seed line we have so far is:
"<the user's original /start title or brief seed line, copied
verbatim — even if it runs long, do not trim>"*.

**Today's question (§N <action-slug>):** <plain English ask>.

**Why now:** §1 is the foundation every later question references —
that's why this question runs first.
```

Once §1 has been filled by THIS action's commit, every subsequent action quotes from the now-existing §1 prose. The fallback fires once per work-item, at the first user-facing turn.

If §1 exists but is mid-edit (e.g., the user filled `who` but not `what-breaks` yet), quote whatever HAS been written; if all three §1 step rows are still `[ ]`, you're still in the fallback case — say so.

## Format (plain English, no jargon)

```text
**Where we are:** <work-item identifier> — <verbatim 1-line quote from §1
prose, copied not paraphrased; if §1 spans paragraphs, take the
single sentence that best summarises what this thing does for the
user>.

**Today's question (§N <action-slug>):** <what this question is asking,
in plain English. Translate any technical term on first use per
CLAUDE.md "Non-technical user lens".>

**Why now:** <why this question precedes the rest of the work. One line.>
```

Then ask the action's question below.

## What good looks like

✅ **Good (feature mode):**

> **Where we are:** F01 Auth + canvas shell — log in, then see every Topishop database table on one screen at /map.
>
> **Today's question (§3 user-stories):** who uses this and what do they want to do? 1-5 short stories in the shape *"as <persona>, I want <action>, so that <outcome>."*
>
> **Why now:** §1 captured the WHY; §3 turns that into concrete user-shaped goals that §4 wireframe and §11 acceptance criteria will design against.

✅ **Good (project mode):**

> **Where we are:** PipeLogic V2 — a non-technical pipeline editor where Sam sees every database table on one canvas and edits them inline.
>
> **Today's question (§3 stakeholders):** who uses this product, who pays, who runs ops? List each persona in plain English.
>
> **Why now:** vision tells us *what* we're building; stakeholders tell us *for whom*, which shapes every later spec choice.

❌ **Bad** (jargon, abstract, missing context, paraphrased from memory):

> Now we're at section 3, user-stories. This is a USER-LED step. Provide your stories in the standard format.

The bad version reads like an engineer talking to a database. The good versions read like a colleague catching the user up before asking a question — and quote §1 prose verbatim so the user never sees a paraphrase that drifts from what they wrote.

## Plain English first (cross-references CLAUDE.md)

- Every technical term gets a translation on first use.
- Describe by what things DO for the user, not what they ARE.
- If you catch yourself writing prose a non-technical person can't read in 30 seconds, rewrite before showing.

## Mechanical enforcement

Two checks at commit time, run by `templates/.sdd/scripts/lint-action-prose.sh`:

1. **Skeleton reference present** — every USER-LED + AGENT-LED-with-approval action body must contain a link to this skeleton. Removing the link fails the lint.
2. **`prelude_refresh: true` in frontmatter** — every user-facing action must declare the flag. The flag is the structured signal for tooling (next-action.sh, /next, IDE plugins) so the refresher fires deterministically; the prose directive is the agent-facing instruction. Both are required (foundation 3 — never assume; structured + prose belt-and-braces).

The prose quality of the emitted refresher (does it actually quote §1 verbatim? is it plain English?) is reviewed at PR-merge time — mechanical "is this verbatim?" diffing would be theatre per Foundation 3.
