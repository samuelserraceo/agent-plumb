---
type: action
slug: project-capabilities
tag: AGENT-LED
title: "Project capabilities"
short_label: "§4 Capabilities"
steps:
  - { id: capability-list, action: "draft with alternatives", field: "§4.capabilities" }
used_by: [project]
references: [project-problem, project-success, project-priorities]
touches: [".sdd/<work-item>/spec.md"]
trust: framework
budget:
  max_minutes: 30
  max_tokens: 8000
  max_commits: 1
requires_user_approval: true
---

> **§171 — Refresher first.** BEFORE asking the question below, emit the 3-line refresher per [`refresher-block.md`](../skeletons/refresher-block.md): **Where we are** (feature + 1-line plain-English summary from spec.md §1), **Today's question (§N <slug>)** (what this asks, in plain English), **Why now** (why it precedes the rest). Skip on within-action continuations (e.g. §1.who → §1.pain share context).

# §4 — Capabilities (what to build, in shippable chunks)

Now you turn the project into shippable features. Each capability becomes ONE feature — sized within the S/M/L band (S=1-4 BUILD tasks, M=5-10, L=11-15). Anything that would exceed L must split. Don't reach for "1-2 weeks" or other clock-time sizing — per CLAUDE.md doctrine rule 6, the framework sizes work in atomic steps and S/M/L, never in days/weeks (AI is much faster than human-trained estimates).

This is an AGENT-LED step. The agent drafts a list; you approve, adjust, or rewrite.

## What makes a good capability

- **Vertically slice-able.** One capability = one feature = one PR. Not "the database layer" (that's horizontal infra) but "user signup flow" (vertical, ships value).
- **Independently testable.** Can you put it in front of a user and see if it works? If not, it's not a capability — it's plumbing.
- **Sized within the S/M/L band below.** Bigger than L = must be split. Smaller than S = combine with a sibling. The single sizing convention is the S/M/L rubric used in the per-capability frontmatter — there's no separate "10-15 BUILD tasks" target; the L upper bound IS the project-wide cap.
- **Has a clear "done" state.** "Auth works" isn't a capability; "Email-magic-link signup with 7-day session" is.

## Limits

- **Min 3 capabilities.** Fewer than 3 and the project is just a feature in disguise — drop the project playbook, use `/start` directly.
- **Max 12 capabilities.** More than 12 means the project is too ambitious for one roadmap — break it into phases (Phase 1: Capabilities 1-8; Phase 2: Capabilities 9-X).

## What the agent drafts

For each capability, the agent fills:
- **Slug**: `lowercase-with-dashes` (becomes feature folder name)
- **One-line headline**: what it does
- **2-3 line plain-English description**: who uses it, what changes
- **Estimated size**: S (1-4 tasks) / M (5-10 tasks) / L (11-15 tasks). Anything that would exceed 15 tasks MUST be split into 2+ capabilities — that's the project-wide single sizing policy.
- **Depends on**: other capability slugs that must ship before this one (often empty)

## Example output

```markdown
## Capabilities (8)

1. **email-signup** [M, no deps]
   *Email magic-link signup with 7-day session.*
   New visitor → signs up → receives confirmation email → returns next day, still logged in.

2. **profile-setup** [S, depends on email-signup]
   *Three-step onboarding to capture name + role + team size.*
   Just-signed-up user → completes profile → lands on empty dashboard with sample data.

3. **add-first-contact** [M, depends on profile-setup]
   *Add a contact via paste-from-clipboard or one-by-one form.*
   Signed-in user → adds 1-3 contacts → sees them in the contacts list.
... (8 total)
```

## Iterate

You'll iterate with the agent: maybe split a capability, merge two, adjust priority. The agent should propose 2-3 alternative breakdowns ("safe", "ambitious", "minimal") and you pick or remix.

---

**What it looks like:**

What can the project DO at a high level — what are the verbs?

Example: *"This project can: (1) take a one-line feature description and turn it into a full SPEC ceremony, (2) run BUILD test-first per task, (3) push PRs with auto-generated descriptions, (4) audit-log every approval. It cannot (yet): generate React components from wireframes, run visual-regression tests, integrate with non-GitHub forges."*

**End the turn with:** `Reply approve when the capability list looks right, or describe what to adjust (split X, merge Y, drop Z, add W).`
