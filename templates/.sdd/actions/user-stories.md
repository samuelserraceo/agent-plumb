---
type: action
slug: user-stories
tag: USER-LED
title: "§3 User stories"
short_label: "User stories"
steps:
  - { id: stories, prompt: "Which personas matter? For each: 'As <persona>, I want <action>, so that <outcome>.' 2-5 stories total.", field: "§3.stories" }
bundling: bundle_all_fields_in_one_turn
used_by: [feature]
references: [problem, success]
touches: []
trust: framework
budget:
  max_minutes: 5
  max_tokens: 2000
  max_commits: 1
requires_user_approval: false
---

Reference `problem` and `success` before asking. Don't ask in a vacuum.

Ask the user which personas apply — offer 6 common ones plus free-form:
- **New visitor** · **Signed-up user** · **Returning customer** · **Admin / operator** · **Billing / finance** · **Customer support** · **Or describe your own**

For each persona the user picks, ask what they want to do and why. Structure each answer as: *"As `<persona>`, I want `<action>`, so that `<outcome>`."*

**Keep phrasing consistent across stories.** If two stories sound different but mean the same, normalize them.

**Push back on scope creep.** If the user picks 6+ personas for one feature, say: *"That's a lot of personas. Which 2-3 are highest priority? The others can be a follow-up feature."*

**Output:** fill `spec.md` under `### §3 User stories` with 2-5 stories, one per line, in the standard format.

**End the turn with:** *"Run `/next` when ready to continue to §4 UX & Design brief."*
