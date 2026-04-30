---
type: action
slug: wireframe
tag: AGENT-LED
title: "Wireframe"
short_label: "Wireframe"
steps:
  - { id: wireframe, action: "draft wireframe.html — one screen per user story", field: "wireframe.html" }
used_by: [feature]
references: [user-stories, ux-brief]
touches: [.sdd/<work-item>/wireframe.html]
trust: framework
budget:
  max_minutes: 45
  max_tokens: 10000
  max_commits: 1
requires_user_approval: false
---

**Skippable** for non-UI features OR if `ux-brief` (§4) was skipped. Proactively offer: *"Wireframe is for UI-facing features. This one [is/isn't]. Skip? Reply `skip non-UI feature` (handled inline by `/next`)."*

**If continuing:** build ONE static HTML file at `.sdd/features/<id>/wireframe.html`. Tailwind CDN in `<head>` — no build step, viewable in any browser via `open <path>`.

**Show every screen named in `user-stories`.** Label components, show placeholder text, mark interactive areas (buttons, links, form fields). Keep it rough — this is wireframe (layout + flow), not visual design.

**Iterate with user.** They open in browser, request changes (*"move button left", "add error state", "show loading spinner"*). You update the file and tell them to refresh.

**Continue until user says `looks good` (or equivalent).** Tick the `Approved by user: [ ]` box in spec.md.

**Sync requirement (F1 generic enforcer (`pre-commit-rules.sh`)'s `touches:` enforcement):** the commit that closes SPEC must stage `wireframe.html` alongside `spec.md`.

**Note on placeholder paths:** the `touches:` declaration here uses `<work-item>` as a placeholder. F1's pre-commit-rules.sh currently SKIPS placeholder-templated paths during enforcement (it doesn't substitute the live work-item path before checking) — the inline rule lives in `pre-commit-rules.sh` at the touches-validation loop, where any path containing `<` is intentionally bypassed. So this declaration documents intent but doesn't actively block. The wireframe action's AGENT-LED iteration (drafted by the agent, refined with the user until they say `looks good`) keeps the wireframe pointed at the right work-item. Full template-substitution enforcement is deferred — see issue #42 (per-branch worktree-aware INDEX.md) which is the natural place to wire it.

**Output:** the HTML file at `.sdd/features/<id>/wireframe.html` + filled `Approved by user: [x]` in spec.md.

**End the turn with:** *"Drafting wireframe.html now. Open it with `open .sdd/features/<id>/wireframe.html`. Reply with feedback or `looks good` once it captures every screen — then run `/next` to continue."*
