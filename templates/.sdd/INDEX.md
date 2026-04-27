# Project Index

**Active:** _(none)_

> The single always-in-context table of contents. Agent reads this first every session.
> The `Active:` line above is the machine-readable pointer for hooks — keep its format stable.
> When a feature is active, the line reads: `**Active:** features/<id>-<slug>   [PHASE]   blocker: §<N> <section>`

---

## In flight
<!-- Features currently being worked on. Keep 1-3 max; hard cap at 5. Usually only one is "Active" at a time. -->

_(none yet)_

## Backlog
<!-- Queued features. Move to "In flight" when ready to start. -->

_(empty)_

## Shipped
<!-- Completed + merged. One line per feature, newest first.
     Format: features/<id>-<slug> — PR <#url> — merged <YYYY-MM-DD> — <one-line summary> -->

_(empty)_

---

## Live state
<!-- Auto-maintained by /ship and LEARN. Captures the truth about what's running NOW,
     so a non-technical reader can answer "what does this project actually do today?"
     without reading code. -->

### Environments
- **Development (local):** `pnpm dev` → http://localhost:3001
- **Preview:** _(not yet)_
- **Production:** _(not yet)_

### Known live deviations
<!-- Things that shipped despite deviating from spec. Format:
     <feature-id> — <what deviated> — <why accepted> — <when to fix> -->

_(none)_

### Pending production verification
<!-- Acceptance criteria tagged [PROD-ONLY] that can't be verified locally — they collect
     here on /ship and must be manually walked through after first prod deploy. -->

_(none)_

---

## References

- **Playbooks:** `.sdd/playbooks/` (B-1 ships `feature.md`; Phase C will add `bug.md`, `idea.md`, etc.)
- **Actions library:** `.sdd/actions/` (the prose each `/next` injects)
- **Data model:** `.sdd/data-model.md`
- **Patterns / cross-feature learnings:** `.sdd/patterns.md`
- **Decisions audit log:** `.sdd/decisions.md`
- **Project + workflow rules:** `CLAUDE.md` at project root
