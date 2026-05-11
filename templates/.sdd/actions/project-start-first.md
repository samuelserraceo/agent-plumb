---
type: action
slug: project-start-first
tag: AGENT-LED
model_tier: routine
title: "Start the first feature"
short_label: "§7 Kickoff"
steps:
  - { id: start-first, action: do, field: "§7.kickoff" }
used_by: [project]
references: [project-queue-features]
touches: [".sdd/INDEX.md"]
trust: framework
budget:
  max_minutes: 5
  max_tokens: 2000
  max_commits: 1
requires_user_approval: false
---

# §7 — Auto-start the first feature

The project's roadmap is written. INDEX.md backlog is queued. Time to start working on the first feature.

## Why touches only includes INDEX.md

The new feature's `spec.md` is created in a SEPARATE commit by `start.sh` (its own atomic commit per the F4 atomic-step rule). This action's job is just the INDEX.md handoff — moving the backlog entry to in-flight and setting `**Active:**`. The feature spec creation is downstream.

If you tried to put `.sdd/features/<work-item>/spec.md` in `touches:`, the placeholder `<work-item>` would resolve to the PROJECT path (`projects/<NNN>-<project-slug>`), not the new feature path — wrong scope. The two-commit separation keeps the placeholder semantics clean.

## What this action does (one commit, INDEX.md only)

This action's `max_commits: 1` budget covers the INDEX.md handoff. `start.sh` is a separate, downstream concern — it gets its own atomic commit (see "After this action's commit" below).

1. Read INDEX.md `## Backlog` — find the first entry (highest priority, no unfulfilled dependencies)
2. Remove that entry from `## Backlog`; **append** it to the existing `## In flight` section (don't replace — `## In flight` is a list and may already contain other parallel work items)
3. Set `**Active:**` to the new feature (this line points to the user's CURRENT focus; when they switch git branches to work on a different in-flight feature, they update this line manually — see CLAUDE.md "Multi-feature parallel work")
4. Commit. Footprint: `.sdd/INDEX.md` only.

**Note:** `## In flight` can hold multiple parallel work items at once (one per branch is the typical pattern). `**Active:**` is just the current focus marker; `## In flight` is the canonical list of work-in-progress.

## After this action's commit (separate, downstream)

`start.sh` runs for the new feature — same flow as the user typing `/start "<headline>"` (a normal new-feature start, NOT `/start --extends=...` which is for extending shipped features). This is a SEPARATE atomic commit by `start.sh` itself, scaffolding the feature's `spec.md` and the standard `feature` playbook actions. It does not count against this action's budget.

After both commits land, the user is in normal `feature` playbook mode for the first capability. The project playbook is "done" — it produced the roadmap and got the first feature started.

## What carries forward from the project to the feature

- The cross-reference back to the project lives in the feature's INDEX.md entry (`Source: .sdd/projects/<NNN>-<project-slug>/spec.md (§4.<capability-slug>)`) — written by project-queue-features. `start.sh` does NOT auto-populate the feature spec's `extends:` field; that flag is for `/start --extends=<id>` (extending a SHIPPED feature), which is a different workflow.
- The feature gets a richer §1 Problem / §2 Success since the project context is already known — `/next` will offer to summarise from the roadmap rather than ask from scratch
- The feature's INDEX.md entry shows the capability tier (P0/P1/P2) so future readers know its priority

## After this action

The project playbook hits its terminal state. INDEX.md shows:
- `## In flight`: the first feature, in SPEC phase, ready for `/next`
- `## Backlog`: the remaining capabilities (i.e., everything queued by project-queue-features minus the one just kicked off), ordered
- `## Shipped`: empty (until features start landing)

User runs `/next` and starts working on the first feature.

---

**What it looks like:**

Of the features we listed, which one do we walk through `/start` FIRST — like, right now this session?

Example: *"Pick one: 'I want to start with the email-signup form because that's the easiest to demo to friends and prove it works' or 'I want to start with the admin dashboard because nothing else is useful without it'."* You CAN have multiple features in flight at once on different branches — the framework supports parallel work — but pick one to **prioritise for the fastest end-to-end ship**. Get one all the way to SHIPPED first; that's what proves the loop works.

**End the turn with:** `First feature is now active. Run /next to start its SPEC.`
