---
type: action
slug: signoff-steps
tag: USER-LED
title: "§12 Human sign-off steps"
short_label: "Sign-off steps"
steps:
  - { id: manual-steps, prompt: "What manual smoke tests do YOU need to do before SHIP, beyond the automated tests? 1-5 bullets.", field: "§12.manual-steps" }
used_by: [feature]
references: [success, acceptance-criteria]
touches: []
trust: framework
budget:
  max_minutes: 5
  max_tokens: 2000
  max_commits: 1
requires_user_approval: false
---

Ask: *"Besides the automated tests we've written, what manual steps do YOU need to take before we ship? These are the smoke tests only a human can do."*

Common patterns:
- Click around the live prod URL once
- Ask one real user to sign up and tell you what felt off
- Check the Slack/Discord channel got the expected notification
- Run a real test transaction (with a real card, in test mode if possible)
- Verify the analytics dashboard shows new events

**Anchor to `acceptance-criteria`.** Any AC tagged `[PROD-ONLY]` lives here AND in SHIP's verify-prod-only-acs action. They're the same list, surfaced twice for the user.

**Format:** 1-5 bullets. Each step: one sentence, action-oriented.

```
- Sign up via the live prod URL, check email inbox for confirmation
- Ask 1 real user to walk through the signup flow end-to-end
- Check Cloudflare dashboard shows zero blocked-but-legit requests for 24h
```

**If everything is automated, that's fine.** Fill with `Automated tests sufficient — no manual sign-off needed.`

**End the turn with:** *"Run `/next` when you're ready to continue to the Wireframe section."*
