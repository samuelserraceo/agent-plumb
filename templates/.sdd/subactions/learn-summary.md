---
type: subaction
slug: learn-summary
tag: AGENT-LED
title: "learn-summary"
short_label: "Learn summary"
bundling: n_a
used_by: [feature]
references: [problem, success, acceptance-criteria, build-task, verify-test-run]
touches: []
trust: framework
budget:
  max_minutes: 10
  max_tokens: 3000
  max_commits: 1
requires_user_approval: false
---

One paragraph (4-6 sentences) capturing what just shipped.

**Anchoring:** reference `problem` (why we built it), `success` (what we optimized for), and what actually happened during BUILD (any pivots, surprises, dead ends recovered from).

**Prompt structure:**
1. *What got built* — one sentence summary of the feature.
2. *Why* — one sentence linking back to the problem.
3. *What surprised* — one or two sentences on a tradeoff, edge case, or implementation detail that didn't go as planned.
4. *What you'd do differently* — one sentence; can be *"nothing — went smoothly."*

**Plain English.** Should be readable cold by someone who didn't follow the build. No jargon, no internal slang.

**Output:** fill `spec.md` under `### learn-summary` with one paragraph.

**End the turn with:** *"Summary drafted. Reply `approve` or tell me what's off, then we move to learn-lessons."*
