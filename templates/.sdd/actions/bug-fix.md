---
type: action
slug: bug-fix
tag: AGENT-LED
prelude_refresh: true
title: "§4 Fix"
short_label: "Fix"
steps:
  - { id: approval, action: "draft the minimal-diff fix, name files touched, get user approval", field: "§4", triggers: [section_approved] }
used_by: [bug]
references: [bug-problem, bug-repro, bug-root-cause]
touches: [".sdd/<work-item>/spec.md"]
trust: framework
budget:
  max_minutes: 30
  max_tokens: 6000
  max_commits: 1
requires_user_approval: true
---

> **§171 — Refresher first.** BEFORE asking the question below, emit the 3-section refresher per [`refresher-block.md`](../skeletons/refresher-block.md): **Where we are** (work-item identifier + **verbatim 1-line quote** from the work-item's mode-appropriate §1 source — copy it exactly as written; do not paraphrase from memory; if §1 isn't filled yet, use the skeleton's "§1 not yet written" fallback), **Today's question (§N <slug>)** (what this asks, in plain English), **Why now** (why it precedes the rest of the work). Skip on within-action continuations (e.g. §1.who → §1.pain share context).

> **§173/§174 — Grill the user's answer.** AFTER the user answers below, BEFORE writing the answer into spec.md, apply the grill protocol per [`grill-protocol.md`](../skeletons/grill-protocol.md): cap 3 questions max, grill only on vague terms / hidden assumptions / under-specification / compound answers / implied trade-offs — skip clean answers (names, numbers, picked-from-list). Every grill question is plain English with a concrete example or analogy (per #174); no SQL/code in inline prose; end with "or describe in your own words".

Propose the **smallest** change that fixes the bug. Bugs aren't a refactor opportunity.

**Required output (fill §4):**

- **Fix in one paragraph** — what you'll change, in plain English. *"In the magic-link callback, await the user-creation Promise before redirecting. Add a single `await` keyword."*
- **Files touched** — list each path + a one-line description of what changes inside it. Keep this list as small as possible.
- **What's NOT changing** — call out anything you considered changing but deliberately didn't. *"Considered also caching the user object on `session` to avoid the second DB read on the next request — deferred to a follow-up; not part of this fix."*
- **Why this is the minimal diff** — explain why you didn't do something larger. *"The auth library handles N other flows the same way; the smallest-blast-radius fix is the one branch that's broken."*

**Iteration discipline.** This is AGENT-LED — propose first, iterate. Common feedback: *"can you make it smaller?"*, *"don't touch X"*, *"what about a 1-line wrapper instead of changing the helper?"*. Update §4 and ask again until the user types **approve**.

**Push for minimum diff (Karpathy borrow #2).** If the proposed fix touches 5 files, ask yourself: *"can the same correctness be achieved by changing 1 file?"* The smallest diff is reviewable, revertable, and least likely to introduce a new bug. If the user accepts a larger diff, capture WHY in §4 — future-you will need to understand the reasoning at code-review time.

**On approval.** Hashed into `verification.json.approved_sections.bug-fix`. The moat refuses commits where §4 content has changed without re-approval — guards against silent fix-creep during BUILD.

**What it looks like:**

Here's the smallest, safest change that fixes the root cause.

Example: *"3 lines added to `app/api/signup/route.ts` — wrap the email regex in try/catch, return 400 with the message 'please use a valid email' on the catch. No other code touched."* Then a regression test that asserts the bad-email case returns 400 + the user-friendly message — so this exact bug can never silently come back.

**End the turn with:** *"Reply `approve` to lock the fix, or tell me what to change ('smaller', 'don't touch X', 'try Y instead')."*
