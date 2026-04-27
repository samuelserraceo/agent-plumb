---
type: playbook
slug: invalid-unresolved-subaction
title: "Playbook referencing a sub-action that doesn't exist"
when_to_use: "fixture only"
work_item_folder: items/
work_item_id_pattern: "{NNN}-{slug}"
stages:
  - id: ONESTAGE
    actions:
      - problem            # exists in B-0 baseline
      - does-not-exist     # NO such file in .sdd/actions/
    exit_checks:
      - { id: C-stage-done, check: "stage complete" }
---

Synthetic fixture for the unresolved-subaction-reference test.

SCHEMA.md §1.5 says: "Every `subactions[]` slug must reference an
existing `.sdd/actions/<slug>.md`." Loader MUST detect that
`does-not-exist` has no corresponding file and emit a plain-English
error per the plain-English error message convention.

Mutation test: remove the resolution check from the loader's
validate_playbook function; the test must fail RED (loader silently
accepts the dangling reference).
