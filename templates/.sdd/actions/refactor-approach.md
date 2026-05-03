---
type: action
slug: refactor-approach
tag: AGENT-LED
title: "§3 Approach"
short_label: "Approach"
steps:
  - { id: approval, action: "draft the proposed new code shape (helper signature, file moves, call-site list), get user approval", field: "§3", triggers: [section_approved] }
used_by: [refactor]
references: [refactor-scope, regression-coverage]
touches: [".sdd/<work-item>/spec.md"]
trust: framework
budget:
  max_minutes: 30
  max_tokens: 6000
  max_commits: 1
requires_user_approval: true
---

Propose the new code shape. The smallest, clearest change that achieves the refactor's goal.

**Required output (fill §3):**

- **The new shape in one paragraph** — what the code looks like after. *"Extract `_atomic_write_config(path, content)` into `scripts/_helpers.sh`. Both `set` and `reset` source the helper and call it instead of duplicating the temp-file + rename logic."*
- **New helper signature(s)** — exact name + arg list. Be precise; this is the contract the call-sites depend on. *"`_atomic_write_config <path> <content>` — returns 0 on success, 1 on disk full / permission denied; emits the same stderr message both subcommands had."*
- **Call sites** — list every place the new helper is called from. *"`settings.sh:42-58` → `_atomic_write_config "$config" "$new"`; `settings.sh:91-107` → same call with reset's content."*
- **What's NOT changing** — the user-visible behaviour. Re-state from §1: *"Both subcommands still create the temp file under `.sdd/.tmp/`, still rename atomically, still emit the same stderr message on failure."*
- **Why this is the minimal shape** — explain why you didn't pick something fancier. *"Considered making the helper take a callback for the content-generation step — over-abstracted; the simple two-arg form covers both call sites without ceremony."*

**Iteration discipline.** This is AGENT-LED — propose first, iterate. Common feedback: *"can the helper be smaller?"*, *"why not just keep the duplication for clarity?"*, *"what about a one-line wrapper instead of a full helper?"*. Update §3 and ask again until the user types **approve**.

**Push for minimum diff.** Refactors that ADD net lines are usually feature-shaped, even if framed as cleanup. If your proposed approach grows the codebase, ask yourself: *"is the new shape genuinely simpler? Or am I adding ceremony?"* Defend the diff in writing.

**On approval.** Hashed into `verification.json.approved_sections.refactor-approach`. Future edits to §3 require re-approval — guards against silent shape-creep during BUILD.

**What it looks like:**

Here's the safest order to do this without ever leaving the codebase in a broken state.

Example: *"Step 1: create the new files with copies of the relevant code (everything still imports from the old place — green). Step 2: switch imports one caller at a time (green between each). Step 3: delete the old file once nothing imports it (green). One commit per step; never bundle."* No big-bang refactors.

**End the turn with:** *"Reply `approve` to lock the approach, or tell me what to change ('smaller helper', 'don't move the file', 'inline at call site instead'). Then `/next` to verify the diff is minimal in §4."*
