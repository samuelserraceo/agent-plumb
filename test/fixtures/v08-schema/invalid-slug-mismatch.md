---
type: action
slug: not-the-filename
tag: USER-LED
title: "Sub-action where slug doesn't match filename"
bundling: n_a
used_by: []
references: []
touches: []
trust: framework
---

Synthetic fixture for T28.

The filename is `invalid-slug-mismatch.md` (so the expected slug is
`invalid-slug-mismatch`), but the YAML declares `slug: not-the-filename`.
Loader MUST reject with a plain-English error pointing at the file
and naming the mismatch.

Mutation test: remove the slug-equals-filename check from the loader;
T28 must fail RED.
