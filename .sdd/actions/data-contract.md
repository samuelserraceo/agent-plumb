---
type: action
slug: data-contract
tag: AGENT-LED
model_tier: thinking
prelude_refresh: true
title: "§6 Data contract"
short_label: "Data contract"
steps:
  - { id: approval, action: "draft the data contract, iterate with the user, sync data-model.md, get approval", field: "§6", triggers: [section_approved] }
used_by: [feature]
references: [problem, success, user-stories, proposed-approach]
touches: [".sdd/<work-item>/spec.md", ".sdd/data-model.md"]
trust: framework
budget:
  max_minutes: 30
  max_tokens: 8000
  max_commits: 1
requires_user_approval: true
---

> **§171 — Refresher first.** BEFORE asking the question below, emit the 3-section refresher per [`refresher-block.md`](../skeletons/refresher-block.md): **Where we are** (work-item identifier + **verbatim 1-line quote** from the work-item's mode-appropriate §1 source — copy it exactly as written; do not paraphrase from memory; if §1 isn't filled yet, use the skeleton's "§1 not yet written" fallback), **Today's question (§N <slug>)** (what this asks, in plain English), **Why now** (why it precedes the rest of the work). Skip on within-action continuations (e.g. §1.who → §1.pain share context).

> **§173/§174 — Grill the user's answer.** AFTER the user answers below, BEFORE writing the answer into spec.md, apply the grill protocol per [`grill-protocol.md`](../skeletons/grill-protocol.md): cap 3 questions max, grill only on vague terms / hidden assumptions / under-specification / compound answers / implied trade-offs — skip clean answers (names, numbers, picked-from-list, binary yes/no). Every grill question is plain English with a concrete example or analogy (per #174); no SQL/code in inline prose; end with "or describe in your own words".

Every entity, field, transition, and edge case must be named before code. The data layer is where silent bugs go to multiply.

**Propose the schema.** Based on `problem`, `user-stories`, `proposed-approach`, draft:

- **Entities affected** — which tables/collections change?
- **New fields / migrations** — name + type + why we need it
- **Relations created or removed** — foreign keys, joins, cascades
- **Edge cases at the data layer** — what happens at write conflicts, race conditions, deletes, soft-deletes?

**Show the math in plain English** for each new field: *"`user.verified_email` (boolean): tracks whether the user clicked the confirmation link, so we can gate payments until it's true."*

**Push hard on edge cases.** Ask: *"What if a user signs up twice? What if they try to delete their account while a transaction is pending? What if two writers race to update the same row?"* If you can't articulate what happens, the design is incomplete.

**Stage the data file too.** When you commit §6, the schema file (`.sdd/data-model.md`) MUST be staged in the same commit. The framework refuses the commit otherwise — that's how we stop schema docs from drifting from the spec. Never duplicate the schema in spec.md; the spec names the entity (e.g. `User`) and the schema file owns the columns.

**Link to data entities.** When §6 mentions a table or entity that lives in `.sdd/data-model.md`, name it with a `[[entity:User]]` link — like a footnote pointing at the schema. Slug = the heading text in data-model.md, case-insensitive. The framework checks the link points to a real entity. The payoff: anyone reading later can click straight to the schema; future schema changes can pull up "which features touch this table" without grepping by hand. Only link to entities that exist (or will exist after this commit lands — fine, since the schema file is staged in the same commit).

**What happens when you `approve`.** The framework takes a fingerprint of this section's text. If §6 changes later (you, me, or a future session edits it), the framework spots the diff at the next phase advance and walks you through a quick "review + reply `approve`" flow. Section-lock that keeps the spec honest.

**What it looks like:**

What pieces of information do we need to store, and what does each look like?

Example: a signup form might need a **person's email** (text, has to be a valid email), **the day they signed up** (date), **whether they confirmed via the link in the email** (true/false). I'll list each one in plain English first, then show you the technical version. You confirm or correct.

**Got an existing schema? Drop it here.** Paste it / upload it / give me a path to it (Google Sheets export, schema dump, JSON sample, CSV header row, screenshot of a table — any shape works).

<details>
<summary>Show technical detail (supported formats, reliability, failure path)</summary>

The framework reads:

- **markdown / CSV / JSON / plain text** — clean (most reliable)
- **PDF** — spotty (text extraction varies; works for tables, less reliable for diagrams)
- **screenshots** — depend on vision-capable models (works on Claude Sonnet 4+; degrades on text-only models)

**Failure path.** If the format is unsupported or the agent can't read it, you get a plain-English error like *"I couldn't parse the PDF you uploaded — try copy-pasting the table as markdown, or describe the columns and I'll match them."* Don't let a parse failure block §6; describe instead.

</details>

**End the turn with:** *"Reply `approve` to lock the data contract, or tell me what to change ('split table X', 'cascade delete here', 'edge case Y missing')."*
