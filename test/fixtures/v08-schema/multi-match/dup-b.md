---
type: subaction
slug: dup-test
tag: AGENT-LED
title: "Second file claiming slug 'dup-test'"
bundling: n_a
used_by: []
references: []
touches: []
trust: framework
---

Paired with `dup-a.md`. See that file for the test rationale.

Note: this fixture's filename is intentionally NOT `dup-test.md`,
because `dup-a.md` and `dup-b.md` both have slug `dup-test` to
demonstrate multi-match. Filename-vs-slug mismatch is a SEPARATE check
(see `invalid-slug-mismatch.md`); to keep this fixture isolated to
multi-match-only, the loader must run multi-match detection BEFORE
filename-mismatch detection — or this fixture will fail two rules at
once and the test couldn't isolate the bug.

Implementation note for Theme 1's loader: order checks so multi-match
fires first when both apply.
