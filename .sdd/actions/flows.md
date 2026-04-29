---
type: action
slug: flows
tag: AGENT-LED
title: "§7 Flows"
short_label: "Flows"
steps:
  - { id: flows, action: draft_1_to_3_critical_flows_referencing_user_stories, field: "§7" }
used_by: [feature]
references: [user-stories, success]
touches: []
trust: framework
budget:
  max_minutes: 25
  max_tokens: 6000
  max_commits: 1
requires_user_approval: true
---

Draw 1-3 critical user flows, from open-page through done. Reference `user-stories` explicitly — every flow maps to one or more stories.

For each flow:

1. **Name it** — e.g., "First-time signup", "Returning user adds a saved card", "Admin reviews flagged accounts"
2. **Reference the source story** — *"Implements US2: As a new visitor, I want to sign up..."*
3. **Number the steps** — page they land on, what they click/type, what the system does, what they see next
4. **Note the happy path AND the obvious failure paths** — what if validation fails? what if the third party is down? what if they refresh mid-flow?

**Format:**

```
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

**End the turn with:** *"Reply `looks good` if these capture the flows correctly, or tell me what to add/change (e.g. 'add abandoned-cart flow', 'merge flows 1+2', 'failure path missing for X'). Then run `/next` to continue."*

---

## Wireframe-up-to-date check (v0.10.1 doctrine, CLAUDE.md rule 5)

If this action's answer changes anything user-visible (a screen, a button, a flow, a page transition, a form field), **also update `wireframe.html`** in the same commit. The wireframe is the non-technical user's primary visibility tool — never let it drift from the spec.

If the feature has no UI (backend cron, internal data migration), `wireframe.html` may not exist — skip this check.

Mechanical enforcement (a state_rule that refuses spec commits without wireframe staging when wireframe.html exists) lands in v0.11 — see issue #45.
