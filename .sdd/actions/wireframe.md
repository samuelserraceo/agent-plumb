---
type: action
slug: wireframe
tag: AGENT-LED
title: "Wireframe"
short_label: "Wireframe"
steps:
  - { id: wireframe, action: "draft wireframe.html — UI screens for UI features OR flow + architecture for non-UI features", field: "wireframe.html" }
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

Build ONE static HTML file at `.sdd/features/<id>/wireframe.html`. Every feature gets one — UI or not. Tailwind CDN in `<head>`, no build step, viewable in any browser via `open <path>`.

The wireframe is often the only doc a non-technical reviewer can look at and decide *"yes, that's what I asked for"*. Don't skip it just because the feature is backend-only — non-UI features need MORE visualisation than UI features, not less, because reviewers can't infer behaviour from code.

**Pick one of two shapes based on the feature.**

### Shape A — UI feature (form, page, button, screen, anything user-clicks)

Copy the starter from `templates/.sdd/skeletons/wireframe-ui.html` into `.sdd/features/<id>/wireframe.html`, then fill the TODO sections:

- **Screens** — every screen named in `user-stories`. Label components, show real-looking copy (not Lorem Ipsum), mark interactive areas (buttons, links, form fields). Keep rough — this is wireframe (layout + flow), not visual design.
- **Design tokens** — colour palette, type scale, spacing, radii. References the project's `stack.md` if there's an established design system.
- **Component states matrix** — for each interactive component: default / hover / focus / active / disabled / loading / error. One column per state, one row per component.
- **Interaction details** — what happens between screens. Click X → goes to Y. Submit form with bad email → shows error inline.

### Shape B — non-UI feature (backend job, library, CLI, API endpoint, data migration, framework rule)

Copy the starter from `templates/.sdd/skeletons/wireframe-non-ui.html` into `.sdd/features/<id>/wireframe.html`, then fill the TODO sections:

- **Example interactions** — concrete chat / CLI / API examples showing what the user does and what they get back. One per `user-stories` story.
- **Flow diagram** — step-by-step what happens when the user does X. Numbered steps. Click any step in the rendered HTML for details.
- **Architecture diagram** — where this feature sits in the broader system. What it touches; what touches it. Click any box in the rendered HTML for details.
- **New vs existing** — which boxes/steps are new with this feature, which were already there.

For non-UI features, the wireframe's job is exactly the same as for UI features: let a non-technical reviewer say *"yes, that's right"* without reading code.

**If both UI AND backend** — ship both shapes in the same file under H2 sections. Common for full-stack features (signup form + backend job). The two skeletons are designed to coexist.

**Iterate with user.** They open the file in their browser. You update; they refresh. Keep going until they say `looks good` (or equivalent).

**Sync requirement (F1 generic enforcer `pre-commit-rules.sh`'s `touches:` enforcement):** the commit that closes SPEC must stage `wireframe.html` alongside `spec.md`.

**Note on placeholder paths:** the `touches:` declaration uses `<work-item>` as a placeholder. F1's pre-commit-rules.sh skips placeholder-templated paths during enforcement (the inline rule lives in `pre-commit-rules.sh` at the touches-validation loop; any path containing `<` is bypassed). So this declaration documents intent but doesn't actively block. The wireframe action's AGENT-LED iteration (drafted by the agent, refined until the user says `looks good`) keeps the wireframe pointed at the right work-item. Full template-substitution enforcement is deferred — see issue #42 (per-branch worktree-aware INDEX.md).

**Output:** the HTML file at `.sdd/features/<id>/wireframe.html` (one of the two shapes above; or both nested under H2s for full-stack features).

**What it looks like:**

For a UI feature: *"I'll draw the screens (plain HTML, no build step) so you can click through them in a browser. For a signup feature I'll make three screens — form before submit, 'check your inbox' message, 'you're in' welcome — each with placeholder copy you can edit. We iterate until you say `approved`."*

For a non-UI feature: *"I'll draw what your feature does as a flow diagram (the steps when the user does X), an architecture diagram (where this sits in the broader system), and concrete example interactions. For Tier 3 LLM-driven synthesis I made a 5-step flow (cache lookup → retrieval → AI call → cite-check → cache write), an architecture diagram showing where Tier 3 fits between the agent and the corpus, and chat examples per user story. You can click any step or any box for plain-English details on what happens there."*

**End the turn with:** *"Drafting wireframe.html now (UI shape / non-UI shape — pick one or describe). Open it with `open .sdd/features/<id>/wireframe.html`. Reply with feedback or `looks good` once it captures the feature — then run `/next` to continue."*
