---
type: playbook
slug: feature
title: "Build a new feature end-to-end"
when_to_use: "new functionality the user wants — not a bug, not an idea"
work_item_folder: features/
work_item_id_pattern: "{NNN}-{slug}"
stages:
  - id: SPEC
    subactions:
      - problem
      - proposed-approach
    exit_checks:
      - { id: C-spec-problem-filled, check: "§1 problem has all 3 fields filled" }
      - { id: C-spec-approach-approved, check: "§5 proposed-approach has been approved by the user" }
  - id: BUILD
    subactions:
      - build-task
    exit_checks:
      - { id: C-build-task-green, check: "every build-task instance is GREEN (test passing, code committed)" }
---

# Build a new feature end-to-end

> **Phase B-0 / Theme 1.5 SKELETON.** Two stages with the 3 sub-actions
> that exist in B-0. Theme 3 extracts the remaining 20 sub-actions from
> the legacy `profile-feature.md` and adds them back here (full SPEC =
> 14 sub-actions, BUILD = 2, SHIP = 7 = 23 total per the original plan).
> Theme 2 (the prose refactor) replaces this placeholder body with the
> real "when this fits / what to expect" prose.
>
> The loader enforces SCHEMA.md §1.5 — every `subactions[]` slug must
> resolve to a `.sdd/subactions/<slug>.md` file. Until Theme 3 ships
> the missing 20, this playbook can only declare references to the 3
> that exist. Honest representation > false-confidence loader.

## When this playbook fits

You want to build something **new**: a feature, a screen, a workflow, a backend job, an API endpoint. You'd describe it as "I want to be able to ___" or "the product should now do ___."

This playbook is **not** for:
- Reporting or fixing something broken → Phase C will ship `bug.md`
- Capturing a half-formed thought without commitment → Phase C will ship `idea.md`
- Investigating an open question with no clear answer yet → Phase C will ship `question.md`

If you're not sure, pick `feature` and the agent will redirect if your work item turns out to be a different shape.

## What to expect

Three stages, walking left-to-right:

1. **SPEC** — 14 questions / drafts that turn the idea into a concrete plan. Some you answer (USER-LED), some the agent drafts and you approve (AGENT-LED). About 30-90 minutes the first time you run a feature, less as you build a feel for it.
2. **BUILD** — write a test, write code to pass the test, commit, repeat. The agent does the work; you decide pace via "run mode" (step-by-step, checkpointed, or autonomous).
3. **SHIP** — verify, summarize lessons, open PR, watch CI, mark shipped.

Total time depends on the feature. Small (a form, a CRUD endpoint): 1-2 hours. Medium (a multi-screen flow with a third-party integration): 4-8 hours. Large (rebuild a whole flow): a day or more — and at that point we'd suggest splitting it into smaller features.

## What's locked, what's not

The 23 sub-actions in the frontmatter are **closed for B-1**. Adding new sub-actions requires Phase C work (it touches schema validation + the sub-action library). The order is also fixed — sub-actions inside each stage must be filled in sequence.

The plain-English `check:` strings in `exit_checks` are documentation. The actual evaluation logic lives in `verify-stage.sh` (per-check-ID bash). Adding a new check ID in B-1 requires editing `verify-stage.sh`. See SCHEMA.md §17 for why.

---

**[Theme 2 fills the rest of this prose from `profile-feature.md`.]**
