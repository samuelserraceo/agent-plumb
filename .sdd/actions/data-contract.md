---
type: action
slug: data-contract
tag: AGENT-LED
title: "§6 Data contract"
short_label: "Data contract"
steps:
  - { id: approval, action: "draft the data contract, iterate with the user, sync data-model.md, get approval", field: "§6", triggers: [section_approved] }
used_by: [feature]
references: [problem, success, user-stories, proposed-approach]
touches: [".sdd/<work-item>/spec.md", ".sdd/data-model.md"]
trust: framework
budget:
  max_minutes: 30
  max_tokens: 8000
  max_commits: 1
requires_user_approval: true
---

> **§171 — Refresher first.** BEFORE asking the question below, emit the 3-line refresher per [`refresher-block.md`](../skeletons/refresher-block.md): **Where we are** (feature + 1-line plain-English summary from spec.md §1), **Today's question (§N <slug>)** (what this asks, in plain English), **Why now** (why it precedes the rest). Skip on within-action continuations (e.g. §1.who → §1.pain share context).

Every entity, field, transition, and edge case must be named before code. The data layer is where silent bugs go to multiply.

**Propose the schema.** Based on `problem`, `user-stories`, `proposed-approach`, draft:

- **Entities affected** — which tables/collections change?
- **New fields / migrations** — name + type + why we need it
- **Relations created or removed** — foreign keys, joins, cascades
- **Edge cases at the data layer** — what happens at write conflicts, race conditions, deletes, soft-deletes?

**Show the math in plain English** for each new field: *"`user.verified_email` (boolean): tracks whether the user clicked the confirmation link, so we can gate payments until it's true."*

**Push hard on edge cases.** Ask: *"What if a user signs up twice? What if they try to delete their account while a transaction is pending? What if two writers race to update the same row?"* If you can't articulate what happens, the design is incomplete.

**Sync requirement (enforced by F1 generic enforcer (`pre-commit-rules.sh`)'s `touches:` enforcement):** when this section is committed, `.sdd/data-model.md` MUST be staged in the same commit. Never duplicate schema definitions in spec.md — reference by name.

**Wiki-link emission (v1.0 graph layer).** When §6 references an entity that lives in `.sdd/data-model.md`, name the entity with a wiki-link in §6 prose: `[[entity:User]]` (case-insensitive, slug from the entity's H2/H3 heading in data-model.md). This makes the feature → entity edge mechanically queryable: the MCP server's `get_backlinks` query reveals which features touch a given entity, so future schema changes can find their downstream consumers without grep. Only emit links for entities that already exist in data-model.md after this commit lands; if you're adding a brand-new entity, the link is correct because data-model.md is staged in the same commit.

**On approval.** Hash recorded in `verification.json.approved_sections.data-contract`. Future edits require `/re-approve §6`.

**What it looks like:**

What pieces of information do we need to store, and what does each look like?

Example: a signup form might need a **person's email** (text, has to be a valid email), **the day they signed up** (date), **whether they confirmed via the link in the email** (true/false). I'll list each one in plain English first, then show you the technical version. You confirm or correct.

**End the turn with:** *"Reply `approve` to lock the data contract, or tell me what to change ('split table X', 'cascade delete here', 'edge case Y missing')."*
