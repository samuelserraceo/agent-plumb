---
type: action
slug: invalid-missing-tag
title: "Action with no `tag:` field"
bundling: n_a
used_by: []
references: []
touches: []
trust: framework
---

Synthetic fixture for general schema-validation coverage.

`tag:` is required per config.md (closed enums section). This file
omits it. Loader MUST reject with a plain-English error: `"Action
'invalid-missing-tag.md' is missing field 'tag' — see config.md
(closed enums section)."`

Mutation test: remove the required-field check from the loader; the
test must fail RED (loader silently treats missing tag as some default).
