---
type: action
slug: project-queue-features
tag: AGENT-LED
title: "Queue features in backlog"
short_label: "§6 Queue"
steps:
  - { id: write-backlog, action: do, field: "§6.queue" }
used_by: [project]
references: [project-capabilities, project-priorities, project-start-first]
touches: [".sdd/INDEX.md", ".sdd/projects/<work-item>/spec.md"]
trust: framework
budget:
  max_minutes: 5
  max_tokens: 2000
  max_commits: 1
requires_user_approval: false
---

# §6 — Queue features in backlog

Take the build order from §5 and write each capability as a queued feature in `.sdd/INDEX.md`'s `## Backlog` section.

## What gets written

For each capability in priority order, append to `## Backlog`:

```markdown
- features/<NNN>-<slug> — <headline> [<priority tier>] [<size>] [<deps>]
  - Depends on: <list of capability slugs that must ship first>
  - Source: projects/<NNN>-<project-slug>/roadmap.md (§4.<capability-slug>)
```

The `<NNN>` is auto-numbered starting from 001 (or whatever's next if the project's been running).

## Example

After the agent writes:

```markdown
## Backlog

- features/001-email-signup — Email magic-link signup with 7-day session [P0] [M]
  - Depends on: (root)
  - Source: projects/001-pipelogic/roadmap.md (§4.email-signup)

- features/002-profile-setup — Three-step onboarding [P0] [S]
  - Depends on: email-signup
  - Source: projects/001-pipelogic/roadmap.md (§4.profile-setup)

- features/003-add-first-contact — Paste or form-add contacts [P0] [M]
  - Depends on: profile-setup
  - Source: projects/001-pipelogic/roadmap.md (§4.add-first-contact)
... (8 total)
```

## Auto-update INDEX.md

The action writes the entries automatically — the user doesn't have to. After the action runs, INDEX.md has 8 features queued.

When the user later runs `/ship` on one feature, the framework offers: "Backlog has features/002-profile-setup ready next. Start it now? (y/n)". If yes → automatic `/start --extends=001` style kickoff. If no → backlog stays untouched, user picks when ready.

---

**End the turn with:** `Run /next to advance to §7 — auto-start the first feature.`
