---
type: subaction
slug: data-contract
tag: AGENT-LED
title: "§6 Data contract"
short_label: "Data contract"
bundling: n_a
used_by: [feature]
references: [problem, success, user-stories, proposed-approach]
touches: [.sdd/data-model.md]
trust: framework
budget:
  max_minutes: 30
  max_tokens: 8000
  max_commits: 1
requires_user_approval: true
---

Every entity, field, transition, and edge case must be named before code. The data layer is where silent bugs go to multiply.

**Propose the schema.** Based on `problem`, `user-stories`, `proposed-approach`, draft:

- **Entities affected** — which tables/collections change?
- **New fields / migrations** — name + type + why we need it
- **Relations created or removed** — foreign keys, joins, cascades
- **Edge cases at the data layer** — what happens at write conflicts, race conditions, deletes, soft-deletes?

**Show the math in plain English** for each new field: *"`user.verified_email` (boolean): tracks whether the user clicked the confirmation link, so we can gate payments until it's true."*

**Push hard on edge cases.** Ask: *"What if a user signs up twice? What if they try to delete their account while a transaction is pending? What if two writers race to update the same row?"* If you can't articulate what happens, the design is incomplete.

**Sync requirement (enforced by Theme 4's pre-commit-touches hook):** when this section is committed, `.sdd/data-model.md` MUST be staged in the same commit. Never duplicate schema definitions in spec.md — reference by name.

**On approval.** Hash recorded in `verification.json.approved_sections.data-contract`. Future edits require `/re-approve §6`.

**End the turn with:** *"Reply `approve` to lock the data contract, or tell me what to change ('split table X', 'cascade delete here', 'edge case Y missing')."*
