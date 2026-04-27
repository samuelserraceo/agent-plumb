---
type: subaction
slug: ux-brief
tag: AGENT-LED
title: "§4 UX & Design brief"
short_label: "UX brief"
bundling: n_a
used_by: [feature]
references: [problem, success, user-stories]
touches: []
trust: framework
budget:
  max_minutes: 20
  max_tokens: 5000
  max_commits: 1
requires_user_approval: false
---

**Skippable for non-UI features** (APIs, cron jobs, data migrations). Proactively offer to skip if [[problem]], [[success]], and [[user-stories]] mention no user-facing surface: *"§4 UX brief is for UI-facing features. This one is backend — skip? Reply `/skip backend-only feature` to continue."*

**If continuing:** read [[problem]], [[success]], [[user-stories]]. Extract signals about audience, stakes, mood, screen context, voice. Write back one paragraph of inferred UX direction.

**Then identify 1-3 smallest gaps and ask only those.** Don't ask blank open-ended questions.

**Propose candidates, not blanks.** For each sub-item, give 2-3 concrete options with one-line reasoning tied back to §1-3:

- **Tone / feel:** minimal, professional, playful, bold, elegant — pick one with a why
- **Reference sites / apps (3 candidates):** name, URL, what to borrow (layout / spacing / copy / colour / motion), why it maps. 1-2 anti-references with why.
- **Primary screen size & device posture:** mobile-first / desktop-first / split — name the "primary" you'll make perfect first
- **Information density:** sparse / balanced / dense — pick with reasoning
- **Motion / interactivity:** static / subtle / playful
- **Accessibility floor:** WCAG 2.1 AA minimum. Anything beyond? (reduced motion, RTL, locale, low-bandwidth)

**Output:** fill `spec.md` under `### §4 UX & Design brief` with the user's chosen options.

**End the turn with:** *"Reply `approve` if this works, or tell me what to change (e.g. 'tone too formal', 'mobile-first instead', 'add dark mode')."*
