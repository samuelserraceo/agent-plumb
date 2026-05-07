---
type: action
slug: user-stories
tag: USER-LED
prelude_refresh: true
title: "§3 User stories"
short_label: "User stories"
steps:
  - { id: stories, prompt: "Which personas matter? For each: 'As <persona>, I want <action>, so that <outcome>.' 1-5 stories total.", field: "§3.stories" }
used_by: [feature]
references: [problem, success]
touches: [".sdd/<work-item>/spec.md"]
trust: framework
budget:
  max_minutes: 5
  max_tokens: 2000
  max_commits: 1
requires_user_approval: false
---

> **§171 — Refresher first.** BEFORE asking the question below, emit the 3-section refresher per [`refresher-block.md`](../skeletons/refresher-block.md): **Where we are** (work-item identifier + **verbatim 1-line quote** from the work-item's mode-appropriate §1 source — copy it exactly as written; do not paraphrase from memory; if §1 isn't filled yet, use the skeleton's "§1 not yet written" fallback), **Today's question (§N <slug>)** (what this asks, in plain English), **Why now** (why it precedes the rest of the work). Skip on within-action continuations (e.g. §1.who → §1.pain share context).

> **§173/§174 — Grill the user's answer.** AFTER the user answers below, BEFORE writing the answer into spec.md, apply the grill protocol per [`grill-protocol.md`](../skeletons/grill-protocol.md): cap 3 questions max, grill only on vague terms / hidden assumptions / under-specification / compound answers / implied trade-offs — skip clean answers (names, numbers, picked-from-list). Every grill question is plain English with a concrete example or analogy (per #174); no SQL/code in inline prose; end with "or describe in your own words".

Reference `problem` and `success` before asking. Don't ask in a vacuum.

Ask the user which personas apply — offer 6 common ones plus free-form:
- **New visitor** · **Signed-up user** · **Returning customer** · **Admin / operator** · **Billing / finance** · **Customer support** · **Or describe your own**

For each persona the user picks, ask what they want to do and why. Structure each answer as: *"As `<persona>`, I want `<action>`, so that `<outcome>`."*

**Keep phrasing consistent across stories.** If two stories sound different but mean the same, normalize them.

**Push back on scope creep.** If the user picks 6+ personas for one feature, say: *"That's a lot of personas. Which 2-3 are highest priority? The others can be a follow-up feature."*

**Output:** fill `spec.md` under `### §3 User stories` with 1-5 stories, one per line, in the standard format.

**What it looks like:**

Who's going to use this, and what do they want to do?

Common types: **new visitor**, **signed-up user**, **returning customer**, **admin or operator**, **billing person**, **customer support**, or **describe your own**.

For each type, fill in the blanks: *"As a `<type of person>`, I want to `<do something>`, so that `<I get the outcome I want>`."* 1 to 5 of these — one is fine for tightly-scoped features.

**End the turn with:** *"Run `/next` when ready to continue to §4 UX & Design brief."*
