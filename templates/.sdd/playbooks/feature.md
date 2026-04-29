---
type: playbook
slug: feature
title: "Build a new feature end-to-end"
when_to_use: "new functionality the user wants — not a bug, not an idea"
work_item_folder: features/
work_item_id_pattern: "{NNN}-{slug}"
terminal_state: SHIPPED
stages:
  - id: SPEC
    actions:
      - problem
      - success
      - user-stories
      - ux-brief
      - proposed-approach
      - data-contract
      - flows
      - dependencies
      - out-of-scope
      - non-functional
      - acceptance-criteria
      - signoff-steps
      - wireframe
      - plan-decompose
      - edge-case-sweep
    exit_checks:
      - { id: C-spec-acs,   check: "≥1 acceptance criterion exists in §11" }
      - { id: C-spec-tasks, check: "≥1 task in plan-decompose section" }
  - id: BUILD
    actions:
      - run-mode-chosen
      - build-task
    exit_checks:
      - { id: C-build-tasks-green, check: "every task is GREEN (test passing, code committed)" }
  - id: SHIP
    actions:
      - verify-test-run
      - verify-prod-only-acs
      - adversarial-review
      - learn
      - push-pr
      - verify-ci-green
      - mark-shipped
    exit_checks:
      - { id: C-ship-pr-url, check: "PR URL recorded in INDEX.md Shipped section" }
      - { id: C-ship-marked, check: ".shipped marker file exists in feature folder" }
---

# Build a new feature end-to-end

## When this playbook fits

You want to build something **new**: a feature, a screen, a workflow, a backend job, an API endpoint. You'd describe it as *"I want to be able to ___"* or *"the product should now do ___."*

This playbook is **not** for:
- Reporting or fixing something broken → Phase C will ship `bug.md`
- Capturing a half-formed thought without commitment → Phase C will ship `idea.md`
- Investigating an open question with no clear answer yet → Phase C will ship `question.md`

If you're not sure, pick `feature` and the agent will redirect if your work item turns out to be a different shape.

## What to expect

Three stages, walking left-to-right:

1. **SPEC** — 15 questions / drafts that turn the idea into a concrete plan. Some you answer (USER-LED), some the agent drafts and you approve (AGENT-LED). About 30-90 minutes the first time you run a feature, less as you build a feel for it.
2. **BUILD** — write a test, write code to pass the test, commit, repeat. The agent does the work; you decide pace via "run mode" (step-by-step, checkpointed, or autonomous).
3. **SHIP** — verify, summarize lessons, open PR, watch CI, mark shipped.

Total time depends on the feature. Small (a form, a CRUD endpoint): 1-2 hours. Medium (a multi-screen flow with a third-party integration): 4-8 hours. Large (rebuild a whole flow): a day or more — at that point we'd suggest splitting it into smaller features.

## How the agent runs each step

Every `/next` runs the same 4-step inner loop:

1. **LOCATE** — read `INDEX.md` to find the active work item, find the active action, load that action's prose from `.sdd/actions/<slug>.md`.
2. **EXECUTE** — ask the user (USER-LED) or draft + iterate (AGENT-LED). Capture the result in `spec.md`.
3. **SYNC** — `pre-commit-rules.sh`'s `touches:` enforcement (the F1 generic enforcer that subsumed `pre-commit-touches.sh` in Phase C) verifies the right files are staged for this step. Block if missing.
4. **ADVANCE** — the agent explicitly invokes `advance.sh` after the commit lands (Phase C subsumed the old `post-commit-advance.sh` hook into this agent-driven invocation). It updates the active blocker pointer in `INDEX.md` to the next action.

LOCATE + EXECUTE are agent-driven prose. SYNC + ADVANCE are structural (real bash hooks). The framework's defenses (manifest hash-pin, section-locking on user approval, trust boundary on injected content, fabrication check on phase advance) all run during commit, between SYNC and ADVANCE.

## What's locked, what's not

The 24 actions in this playbook's frontmatter (15 SPEC + 2 BUILD + 7 SHIP) are **closed for v0.13**. Adding new actions requires explicit framework work (touches schema validation + the action library). The order is also fixed — actions inside each stage must be filled in sequence.

Four actions default to **`requires_user_approval: true`** in their frontmatter:
- `proposed-approach` — closes Codex's silent-design-softening attack
- `acceptance-criteria` — closes Codex's silent-AC-softening attack (the central attack)
- `out-of-scope` — closes silent-scope-expansion attack
- `data-contract` — closes silent-schema-changes attack

When the user approves any of these, the framework hashes the section content. On phase-advance, the moat re-extracts the section from the staged spec.md and refuses the commit if the hash diverges. Re-approval (`/re-approve <slug>`) is the legitimate path for intentional edits.

The `check:` strings in `exit_checks` ARE the evaluation logic — not documentation that points elsewhere. Each `check:` follows the format `<plain-English description> — <bash command>` (em-dash separator). `verify-stage.sh` parses each line out of the `### Exit checks` block in `spec.md`, sets `$SECTION_FILE` to a temp file containing the active phase's body, and runs the trailing bash command directly. There is no per-check-ID dispatch in `verify-stage.sh` — the script is generic; the playbook owns what gets checked. Adding a new check means adding a new row to `exit_checks:` here in the playbook, with both the description and the bash command after the em-dash. No edits to `verify-stage.sh` are needed.

---

**[Theme 2 fills the rest of this prose from `profile-feature.md`.]**
