---
type: action
slug: invalid-yaml-duplicate
tag: USER-LED
tag: AGENT-LED
title: "Action with a duplicate YAML key"
bundling: n_a
used_by: []
references: []
touches: []
trust: framework
---

Synthetic fixture for the YAML-duplicate-key check (Codex finding #4 —
see config.md (closed enums section)).

This file declares `tag:` twice. Per YAML spec, duplicate keys are
"undefined behavior" — most parsers silently use the last one, but the
intent is ambiguous. config.md REQUIRES loaders to reject this with a
plain-English error so silent corruption can't sneak in.

Mutation test: remove the duplicate-key check from the loader; the
test must fail RED (loader picks one value silently and validates).
