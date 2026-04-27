---
type: playbook
slug: valid-playbook
title: "Valid playbook for fixture testing"
when_to_use: "synthetic; used only by loader tests"
work_item_folder: items/
work_item_id_pattern: "{NNN}-{slug}"
stages:
  - id: ONESTAGE
    subactions:
      - sample-action
    exit_checks:
      - { id: C-sample, check: "the sample action ran" }
---

# Valid playbook

Synthetic fixture. Used by Theme 1's loader tests as the "happy path"
baseline — every validation rule should pass against this file.
