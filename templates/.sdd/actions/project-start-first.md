---
type: action
slug: project-start-first
tag: AGENT-LED
title: "Start the first feature"
short_label: "§7 Kickoff"
steps:
  - { id: start-first, action: do, field: "§7.kickoff" }
used_by: [project]
references: [project-queue-features]
touches: [".sdd/INDEX.md", ".sdd/features/<first-feature>/spec.md"]
trust: framework
budget:
  max_minutes: 5
  max_tokens: 2000
  max_commits: 1
requires_user_approval: false
---

# §7 — Auto-start the first feature

The project's roadmap is written. INDEX.md backlog is queued. Time to start working on the first feature.

## What this action does

1. Read INDEX.md `## Backlog` — find the first entry (highest priority, no unfulfilled dependencies)
2. Move that entry from `## Backlog` to `## In flight`
3. Run `start.sh` for that feature — same as if the user had typed `/start "<headline>"`
4. Set `**Active:**` to the new feature
5. The feature's spec.md gets scaffolded with all the standard `feature` playbook actions

After this commit, the user is in normal `feature` playbook mode for the first capability. The project playbook is "done" — it produced the roadmap and got the first feature started.

## What carries forward from the project to the feature

- The feature's spec.md `extends:` field references the project: `extends: project/<NNN>-<slug>`
- The feature gets a richer §1 Problem / §2 Success since the project context is already known — `/next` will offer to summarise from the roadmap rather than ask from scratch
- The feature's INDEX.md entry shows the capability tier (P0/P1/P2) so future readers know its priority

## After this action

The project playbook hits its terminal state. INDEX.md shows:
- `## In flight`: the first feature, in SPEC phase, ready for `/next`
- `## Backlog`: the remaining 7 capabilities, ordered
- `## Shipped`: empty (until features start landing)

User runs `/next` and starts working on the first feature.

---

**End the turn with:** `First feature is now active. Run /next to start its SPEC.`
