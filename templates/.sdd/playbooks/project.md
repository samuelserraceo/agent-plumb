---
type: playbook
slug: project
title: "Plan a multi-feature project"
short_label: "Project"
when_to_use: "multi-feature initiative (a CRM, a marketplace, a whole new app) — too big for one /start, needs a roadmap broken into features"
work_item_folder: projects/
work_item_id_pattern: "{NNN}-{slug}"
stages:
  - id: VISION
    actions:
      - project-problem
      - project-success
      - project-stakeholders
    exit_checks:
      - { id: C-vision-stakeholders, check: "≥1 stakeholder profile in §3" }
      - { id: C-vision-success, check: "≥1 measurable success metric in §2" }
  - id: BREAKDOWN
    actions:
      - project-capabilities
      - project-priorities
    exit_checks:
      - { id: C-breakdown-caps, check: "between 3 and 12 capabilities listed in §4" }
      - { id: C-breakdown-priorities, check: "every capability has a priority tier" }
  - id: KICKOFF
    actions:
      - project-queue-features
      - project-start-first
    exit_checks:
      - { id: C-kickoff-queue, check: "INDEX.md `## Backlog` has ≥1 entry" }
      - { id: C-kickoff-active, check: "INDEX.md `## In flight` has the first feature in flight" }
trust: framework
---

# Plan a multi-feature project end-to-end

Use this playbook when:
- You're starting something bigger than one feature ("build a CRM", "build a marketplace platform", "build a whole new admin dashboard")
- You don't yet know how to break the work into shippable features
- You want a roadmap document AND queued individual features to start working on

Don't use this when:
- You have ONE clear feature in mind → use the `feature` playbook directly via `/start "<title>"`
- You're extending a shipped feature → use `/start --extends=<id> "<title>"`

## Three stages

**VISION** — capture the project's intent in plain English. Who's it for? What changes when it ships? Who cares?

**BREAKDOWN** — break the vision into 3-12 capabilities. Each capability must be small enough to ship as 1 feature (sized within the S/M/L band: S=1-4 BUILD tasks, M=5-10, L=11-15). Anything that would exceed L must split into 2+ capabilities.

**KICKOFF** — write the roadmap file, queue all capabilities as features in INDEX.md backlog, auto-start the first one.

## Output

- `.sdd/projects/<NNN>-<slug>/spec.md` — the project-level spec (uses the standard `spec.md` filename for consistency with the `feature` playbook; the file holds the roadmap content)
- `.sdd/INDEX.md` `## Backlog` — list of features to build, in priority order
- `.sdd/INDEX.md` `## In flight` — the first feature, automatically started
- `.sdd/decisions.md` — **append entry** on each VISION/BREAKDOWN/KICKOFF approval. Use `cat >>`, never `>` (overwrite). The append-only contract is enforced by the F1 rule (`file_rules.append_only` in config.md) — any commit that mutates an existing entry is refused. Each decision append must be staged in the **same commit** as the related spec/state/verification change (same-commit coupling preserves audit integrity).

## After kickoff

Once the project playbook completes, you're working on the first feature in normal `feature` playbook mode. The other backlog items wait until you're ready — each `/ship` of a feature offers to start the next backlog item.
