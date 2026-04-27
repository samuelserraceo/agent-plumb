---
type: subaction
slug: invalid-unknown-tag
tag: BOGUS
title: "Sub-action with an unknown tag"
bundling: n_a
used_by: []
references: []
touches: []
trust: framework
---

Synthetic fixture for T27.

The `tag: BOGUS` field is NOT in SCHEMA.md §6 closed enum (USER-LED |
AGENT-LED | BUILD-TASK | BUILD-SPIKE | TRANSITION). Loader MUST
reject with a plain-English error naming the allowed values.

Mutation test: remove the unknown-tag check from the loader; T27 must
fail RED (loader accepts BOGUS).
