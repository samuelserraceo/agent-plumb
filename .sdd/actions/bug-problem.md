---
type: action
slug: bug-problem
tag: USER-LED
prelude_refresh: true
title: "§1 What's broken"
short_label: "Problem"
steps:
  - { id: what, prompt: "What's broken? In one sentence — the behaviour the user sees vs the behaviour they expect.", field: "§1.what" }
used_by: [bug]
references: []
touches: [".sdd/<work-item>/spec.md"]
trust: framework
budget:
  max_minutes: 5
  max_tokens: 1500
  max_commits: 1
requires_user_approval: false
---

> **§171 — Refresher first.** BEFORE asking the question below, emit the 3-section refresher per [`refresher-block.md`](../skeletons/refresher-block.md): **Where we are** (work-item name + **verbatim 1-line quote** from the work-item's §1 prose — *the spec's first paragraph, exactly as the user wrote it; do not paraphrase from memory*), **Today's question (§N <slug>)** (what this asks, in plain English), **Why now** (why it precedes the rest of the work). Skip on within-action continuations (e.g. §1.who → §1.pain share context).

Single USER-LED step: capture what's broken in one sentence. Bug fixes don't need persona / why-now / what-breaks-if-we-don't-solve-it — those questions assume new behaviour. A bug is "the existing behaviour is wrong."

**Push for specifics.** "Login is broken" is not enough — push for the observable symptom. *"After clicking the magic-link email on iPhone Safari, the page shows 'Session not found' instead of redirecting to the dashboard."* That kind of sentence is what §1 captures.

**Translate every technical term on first use.** If the user says "the API returns a 500", write back what that means in user-facing terms: *"the server gives back a generic error instead of the expected response."* Capture both the user-visible symptom and the technical signal if the user mentions one — but lead with the user-visible.

**Halt-on-feature-shaped-bug.** If the user's answer reveals NEW behaviour (a new screen, a new entity, a new flow), this is a feature, not a bug. Surface that politely:

> *"That description sounds like a new behaviour rather than a fix to existing behaviour. Shall we switch to `feature.md`? Reply `switch` to re-scaffold, or describe how the shipped behaviour is wrong (vs what's missing)."*

**Output:** replace the `- [ ] what: …` step row under `### action: bug-problem` with `- [x] what: <one-line summary of the answer>`. Long-form content (the paragraph or 2-3 bullets) goes under the action heading after the step row. No assumptions; if the description is vague, push back once.

**What it looks like:**

Tell me what's wrong, in plain English.

Example: *"What broke? — 'the signup form shows the wrong error when the email is invalid'. Who saw it? — 'a customer who emailed support'. When? — 'started yesterday around 4pm'. What were they trying to do? — 'sign up for our waitlist'. What did they see? — a generic 'something went wrong, please try again' page (the technical name for that screen is a 503 server error, but they wouldn't recognise that). What should they have seen? — 'please use a valid email address'."* The more specific you are, the easier it is to reproduce.

**End the turn with:** *"Run `/next` when you're ready to capture the repro steps in §2."*
