---
type: action
slug: out-of-scope
tag: USER-LED
title: "§9 Out of scope"
short_label: "Out of scope"
steps:
  - { id: list, prompt: "What are we explicitly NOT building this round? 1-5 bullets, each: name + reason. Empty is fine.", field: "§9.explicitly-deferred" }
  - { id: approval, action: user_approves, triggers: [section_approved] }
used_by: [feature]
references: [problem, success, user-stories]
touches: []
trust: framework
budget:
  max_minutes: 10
  max_tokens: 2000
  max_commits: 1
requires_user_approval: true
---

Ask: *"What are we explicitly NOT building this round? Anything related to §1-3 that came up but is off the table — tempting but deferred."*

**Why this matters:** out-of-scope lists are gold for future PRs. If a reviewer asks *"what about admin dashboards?"* you can point to §9: *"explicitly deferred to v2 — see §9."*

**Anchor to context.** Reference `problem`, `success`, `user-stories`. If a story came up in §3 but isn't in scope, list it. If §1 mentioned a related pain point that's a separate feature, list that.

**Format:** 1-5 bullets. Each entry: one bullet, name + reason inline.

```text
- Admin dashboard — not part of MVP, defer to v2
- Multi-language support — single-locale only this round, i18n is its own feature
- Mobile native app — web-only this round
```

**If empty, that's OK.** Fill with `None identified — every story is in scope.`

**On approval (Theme 1.6 hook).** This section gets hash-locked because it's a *commitment about what we WILL NOT do*. Silent expansion (e.g., agent adding "deferred" items mid-build) is a real attack class. Hash on approval; future edits require `/re-approve §9`.

**What it looks like:**

What are we explicitly **not** doing this round? It's just as important to be clear about what's left out as what's in.

Example: *"For this signup feature we are NOT building: (1) social login (Google/Apple) — keeps the scope smaller this round, can add later as its own feature; (2) account-deletion UI — we'll handle requests by hand for now; (3) referral codes — separate feature, parked."* 1-5 bullets is plenty. Empty is fine if everything is in.

**End the turn with:** *"Reply `approve` to lock the out-of-scope list, or tell me what to add/remove."*
