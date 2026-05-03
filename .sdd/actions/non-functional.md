---
type: action
slug: non-functional
tag: AGENT-LED
title: "§10 Non-functional"
short_label: "Non-functional"
steps:
  - { id: constraints, action: "draft performance, security, and compliance constraints", field: "§10" }
used_by: [feature]
references: [problem, success, user-stories, proposed-approach]
touches: [".sdd/<work-item>/spec.md"]
trust: framework
budget:
  max_minutes: 15
  max_tokens: 4000
  max_commits: 1
requires_user_approval: true
---

**Skippable** if there are no real performance, security, or compliance constraints. Proactively offer: *"§10 covers performance budgets, security constraints, and compliance. Does this feature have any of those? If not, reply `skip no NFRs apply` (handled inline by `/next`)."*

**Test for "is this a real constraint?":** *"Would it be a deal-breaker if X took 5 seconds?"* If yes, it's a constraint.

**If continuing:** propose 1-2 candidates per sub-section, anchored to `success` and `proposed-approach`:

- **Performance:** response time budget? data volume limit? caching? *Example: "Form submits in <2 sec including network round-trip. p95 < 5 sec under 100 concurrent."*
- **Security:** sensitive data? access control? threat model? *Example: "Passwords hashed + salted (bcrypt). API keys never in URL params. Rate-limit /signup to 10/IP/hour."*
- **Compliance:** GDPR / CCPA / SOC2 / HIPAA / etc.? *Example: "EU users' data stored in eu-west-1 per GDPR Art. 32. No PII in server logs."*

**Format:** 1-2 bullets per sub-section, or `None identified` if N/A.

**Output:** fill `spec.md` under `### §10 Non-functional`.

**What it looks like:**

Beyond the feature itself, are there any constraints we need to respect?

Example: *"This signup page must (1) load in under 2 seconds on a phone with average 4G; (2) keep the email and confirmation token off any third-party tracker; (3) work for someone using a screen reader. We don't need GDPR consent banners because we already have one site-wide."* I propose, you correct.

**End the turn with:** *"Reply `looks good` if these NFRs match what you actually need, or tell me what to tighten/loosen ('faster', 'add audit log', 'we don't care about EU users yet'). Then run `/next` to continue."*
