---
type: subaction
slug: invalid-yaml-duplicate
tag: USER-LED
tag: AGENT-LED
title: "Sub-action with a duplicate YAML key"
bundling: n_a
used_by: []
references: []
touches: []
trust: framework
---

Synthetic fixture for the YAML-duplicate-key check (Codex finding #4 —
SCHEMA.md §1.5 / §2.6 last row).

This file declares `tag:` twice. Per YAML spec, duplicate keys are
"undefined behavior" — most parsers silently use the last one, but the
intent is ambiguous. SCHEMA.md REQUIRES loaders to reject this with a
plain-English error so silent corruption can't sneak in.

Mutation test: remove the duplicate-key check from the loader; the
test must fail RED (loader picks one value silently and validates).
