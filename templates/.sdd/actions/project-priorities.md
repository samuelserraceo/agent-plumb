---
type: action
slug: project-priorities
tag: AGENT-LED
title: "Project priorities"
short_label: "§5 Priorities"
steps:
  - { id: priority-tiers, action: "draft with alternatives", field: "§5.priorities" }
  - { id: dependency-graph, action: "draft the dependency graph", field: "§5.dependencies" }
used_by: [project]
references: [project-capabilities, project-queue-features]
touches: [".sdd/<work-item>/spec.md"]
trust: framework
budget:
  max_minutes: 20
  max_tokens: 6000
  max_commits: 2
requires_user_approval: true
---

# §5 — Priorities (in what order, why)

Capabilities aren't equal. Decide which to build first, second, third. Two steps.

## Step 1 — Tier each capability

Three tiers:
- **P0 — Must ship for the project to make sense.** Without these, the project doesn't deliver on §2 Success. Often 3-5 capabilities.
- **P1 — Should ship to be competitive.** The project works without them, but feels incomplete. Often 3-6 capabilities.
- **P2 — Nice to have, can wait.** Real value, but not blocking anything. Often 2-5 capabilities.

The agent drafts a P0/P1/P2 split based on §1 Problem and §2 Success. You override.

**Rule:** P0 should be ≤6 capabilities. If P0 > 6, the project is overscoped — promote some to P1.

## Step 2 — Dependency graph

Some capabilities can't ship until others do. List the chains:
- *email-signup → profile-setup* (can't profile without an account)
- *contacts-list → contact-detail* (need a list before a detail page)
- *contacts-list → bulk-import* (import depends on the contacts model existing)

The agent walks the §4 capabilities and proposes dependencies. You confirm or correct.

**Hard rules** (the agent must validate before deriving build order):
- **No cycles.** A → B → A is invalid. The dependency graph must be a DAG (directed acyclic graph) — if any cycle is detected, refuse to proceed and surface the offending chain so the user can break it.
- **No self-deps.** A capability cannot depend on itself. Same handling as cycles: refuse to proceed and surface the specific offending capability (e.g., `email-signup → email-signup`) so the user can correct it. Don't silently filter — that would hide a real authoring mistake.
- **Cycle + self-dep detection runs BEFORE build-order derivation.** The build-order walk assumes a clean DAG; running it on a cyclic or self-dep graph would either loop or silently drop entries. So both checks fail-loud first.

This determines build order: a P1 capability that nothing depends on can wait. A P1 that 3 P2s depend on probably needs to ship earlier than its tier suggests.

## Build order (output)

The combination of priority tiers + dependencies gives you a build order — a numbered list that becomes INDEX.md's `## Backlog`. Example:

```text
1. email-signup        [P0, no deps]
2. profile-setup       [P0, depends on email-signup]
3. add-first-contact   [P0, depends on profile-setup]
4. contacts-list       [P0, depends on add-first-contact]
5. contact-detail      [P1, depends on contacts-list]
6. bulk-import         [P1, depends on contacts-list]
7. dashboard           [P0, depends on contacts-list]
8. team-invites        [P2, depends on profile-setup]
```

The first capability is what you start working on. The rest sit in INDEX.md backlog and get pulled in as you ship each one.

---

**What it looks like:**

If you could only ship one thing this quarter, what would it be?

Example: *"(1) **MUST** — non-technical users can run /sdd-setup and have a working SPEC walk in 30 minutes. (2) **SHOULD** — every feature ships with auto-generated tests. (3) **NICE** — Cypress + visual regression. We'd hate to lose (1) over a 'nicer' (3)."* I help you sort by what would hurt most if missing.

**End the turn with:** `Reply approve when the priority + build order look right.`
