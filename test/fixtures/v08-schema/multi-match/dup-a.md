---
type: subaction
slug: dup-test
tag: USER-LED
title: "First file claiming slug 'dup-test'"
bundling: n_a
used_by: []
references: []
touches: []
trust: framework
---

Synthetic fixture for T29 — multi-match wikilink resolution.

Paired with `dup-b.md` in this same directory. Both files claim
`slug: dup-test`. When `load-playbook.sh` builds the slug-map, it MUST
detect the conflict and ERROR with both paths listed. Resolution of
`[[dup-test]]` from any prose MUST also fail.

Mutation test: remove the multi-match detection from the loader's
slug-map builder; T29 must fail RED.
