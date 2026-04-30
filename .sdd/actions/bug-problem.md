---
type: action
slug: bug-problem
tag: USER-LED
title: "§1 What's broken"
short_label: "Problem"
steps:
  - { id: what, prompt: "What's broken? In one sentence — the behaviour the user sees vs the behaviour they expect.", field: "§1.what" }
used_by: [bug]
references: []
touches: []
trust: framework
budget:
  max_minutes: 5
  max_tokens: 1500
  max_commits: 1
requires_user_approval: false
---

Single USER-LED step: capture what's broken in one sentence. Bug fixes don't need persona / why-now / what-breaks-if-we-don't-solve-it — those questions assume new behaviour. A bug is "the existing behaviour is wrong."

**Push for specifics.** "Login is broken" is not enough — push for the observable symptom. *"After clicking the magic-link email on iPhone Safari, the page shows 'Session not found' instead of redirecting to the dashboard."* That kind of sentence is what §1 captures.

**Translate every technical term on first use.** If the user says "the API returns a 500", write back what that means in user-facing terms: *"the server gives back a generic error instead of the expected response."* Capture both the user-visible symptom and the technical signal if the user mentions one — but lead with the user-visible.

**Halt-on-feature-shaped-bug.** If the user's answer reveals NEW behaviour (a new screen, a new entity, a new flow), this is a feature, not a bug. Surface that politely:

> *"That description sounds like a new behaviour rather than a fix to existing behaviour. Shall we switch to `feature.md`? Reply `switch` to re-scaffold, or describe how the shipped behaviour is wrong (vs what's missing)."*

**Output:** fill `spec.md` under `### §1.what` with one short paragraph or 2-3 bullets. No assumptions; if the description is vague, push back once.

**End the turn with:** *"Run `/next` when you're ready to capture the repro steps in §2."*
