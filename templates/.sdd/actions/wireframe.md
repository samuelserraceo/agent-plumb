---
type: action
slug: wireframe
tag: AGENT-LED
title: "Wireframe"
short_label: "Wireframe"
steps:
  - { id: wireframe, action: draft_wireframe_html_with_one_screen_per_user_story, field: "wireframe.html" }
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

**Skippable** for non-UI features OR if `ux-brief` (§4) was skipped. Proactively offer: *"Wireframe is for UI-facing features. This one [is/isn't]. Skip? Reply `/skip non-UI feature`."*

**If continuing:** build ONE static HTML file at `.sdd/features/<id>/wireframe.html`. Tailwind CDN in `<head>` — no build step, viewable in any browser via `open <path>`.

**Show every screen named in `user-stories`.** Label components, show placeholder text, mark interactive areas (buttons, links, form fields). Keep it rough — this is wireframe (layout + flow), not visual design.

**Iterate with user.** They open in browser, request changes (*"move button left", "add error state", "show loading spinner"*). You update the file and tell them to refresh.

**Continue until user says `looks good` (or equivalent).** Tick the `Approved by user: [ ]` box in spec.md.

**Sync requirement (F1 generic enforcer (`pre-commit-rules.sh`)'s `touches:` enforcement):** the commit that closes SPEC must stage `wireframe.html` alongside `spec.md`.

**v0.9 limitation:** F1 doesn't yet substitute `<work-item>` placeholders in `touches:` paths, so this declaration documents intent but doesn't actively block. The wireframe action's USER-LED iteration will keep the agent in the right place; full enforcement lands in v0.10's path-template feature.

**Output:** the HTML file at `.sdd/features/<id>/wireframe.html` + filled `Approved by user: [x]` in spec.md.

**End the turn with:** *"Drafting wireframe.html now. Open it with `open .sdd/features/<id>/wireframe.html`. Reply with feedback or `looks good` once it captures every screen — then run `/next` to continue."*
