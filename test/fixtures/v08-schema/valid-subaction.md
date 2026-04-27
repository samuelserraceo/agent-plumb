---
type: subaction
slug: valid-subaction
tag: USER-LED
title: "Valid sub-action for fixture testing"
short_label: "Valid"
fields:
  - { id: example-field, label: "An example field" }
bundling: bundle_all_fields_in_one_turn
used_by: [valid-playbook]
references: []
touches: []
trust: framework
budget:
  max_minutes: 5
  max_tokens: 2000
  max_commits: 1
requires_user_approval: false
---

Synthetic USER-LED sub-action. Used by Theme 1 loader tests as the
"happy path" baseline. Every required field is present, every value
is in the closed enum, and the slug matches the filename.
