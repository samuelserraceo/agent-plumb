---
type: action
slug: flows
tag: AGENT-LED
prelude_refresh: true
title: "§7 Flows"
short_label: "Flows"
steps:
  - { id: flows, action: "draft 1-3 critical flows, each referencing the user story it implements", field: "§7" }
used_by: [feature]
references: [user-stories, success]
touches: [".sdd/<work-item>/spec.md", ".sdd/<work-item>/wireframe.html"]
trust: framework
budget:
  max_minutes: 25
  max_tokens: 6000
  max_commits: 1
requires_user_approval: true
---

> **§171 — Refresher first.** BEFORE asking the question below, emit the 3-section refresher per [`refresher-block.md`](../skeletons/refresher-block.md): **Where we are** (work-item name + **verbatim 1-line quote** from the work-item's mode-appropriate §1 source — copy it exactly as written; do not paraphrase from memory; if §1 isn't filled yet, use the skeleton's "§1 not yet written" fallback), **Today's question (§N <slug>)** (what this asks, in plain English), **Why now** (why it precedes the rest of the work). Skip on within-action continuations (e.g. §1.who → §1.pain share context).

Draw 1-3 critical user flows, from open-page through done. Reference `user-stories` explicitly — every flow maps to one or more stories.

For each flow:

1. **Name it** — e.g., "First-time signup", "Returning user adds a saved card", "Admin reviews flagged accounts"
2. **Reference the source story** — *"Implements US2: As a new visitor, I want to sign up..."*
3. **Number the steps** — page they land on, what they click/type, what the system does, what they see next
4. **Note the happy path AND the obvious failure paths** — what if validation fails? what if the third party is down? what if they refresh mid-flow?

**Format:**

```markdown
### Flow 1 — First-time signup (US2)

1. User lands on /signup
2. Enters email + password, clicks "Create account"
3. System validates (email format, password strength), saves user
4. Redirect to /verify-email; system sends confirmation email
5. User clicks link in email → lands on /verify-success
6. Failure path: invalid email → inline error, stay on /signup
7. Failure path: email service down → "We'll send the confirmation soon" + queue retry
```

**Output:** fill `spec.md` under `### §7 Flows` with 1-3 flows in this format.

**What it looks like:**

Let me draw out the most important journeys step by step, in plain English:

Example for a signup feature: *"1. Person lands on the page → 2. Types email → 3. Hits submit → 4. Sees a 'check your inbox' message → 5. Clicks confirmation link in their email → 6. Sees a 'you're in' page."* For each step I'll note what could break (e.g. "step 5: their email might mark our message as spam").

**End the turn with:** *"Reply `looks good` if these capture the flows correctly, or tell me what to add/change (e.g. 'add abandoned-cart flow', 'merge flows 1+2', 'failure path missing for X'). Then run `/next` to continue."*

---

## Wireframe-up-to-date check (v0.10.1 doctrine, CLAUDE.md rule 5)

If this action's answer changes anything user-visible (a screen, a button, a flow, a page transition, a form field), **also update `wireframe.html`** in the same commit. The wireframe is the non-technical user's primary visibility tool — never let it drift from the spec.

If the feature has no UI (backend cron, internal data migration), `wireframe.html` may not exist — skip this check.

Mechanical enforcement (a state_rule that refuses spec commits without wireframe staging when wireframe.html exists) lands in v0.11 — see issue #45.
