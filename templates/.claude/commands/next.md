---
description: Advance the SDD workflow by one atomic step (ask, propose, or act on the next [ ] step).
---

$ARGUMENTS

You are running the SDD workflow. **Do exactly one atomic step — no more, no less.** One step = one commit. Cognitive prep before the commit is free-form; the framework only enforces commit shape.

## What to do

1. **Read state.** Run `.sdd/scripts/resolve-active.sh` and parse the JSON. The `active` field is the work-item path relative to `.sdd/` (e.g. `features/001-waitlist`); `source` tells you whether it came from the current branch (`branch`) or the INDEX.md `**Active:**` line (`index`). Branch-derived wins so multi-feature parallel work just works — switching branches switches the active feature without editing INDEX.md.
   - **`ambiguous: true`** → the branch slug matched 2+ work-item folders (e.g. both `features/001-foo/` AND `bugs/001-foo/` exist). The resolver refuses to pick silently. Tell the user, in plain English: *"Your branch slug matches two folders under `.sdd/` — I can't tell which one you mean. Rename one of them so the slug is unique, or check out a different branch, then run `/next` again."* Stop here.
   - **`active` is null** with `source: "none"` (and not ambiguous) → use the other resolver fields before answering, because the right next step depends on which subcase applies:
     - **`index_active` is non-null** → INDEX.md's `**Active:**` line points at a folder that doesn't exist. Tell the user: *"INDEX.md says the active feature is `<index_active>`, but that folder isn't there. Either edit INDEX.md to point at a real folder, or check out an SDD-style branch (`sdd/<id>-<slug>`) whose folder exists, then run `/next` again."* Stop here. **Don't suggest `/start`** — there's already an INDEX entry, just stale.
     - **`branch` matches `sdd/<id>-<slug>`** → SDD branch exists but the work-item folder isn't scaffolded yet. Tell the user: *"You're on `<branch>` but the work-item folder isn't scaffolded yet. Run `/start <one-line title>` to scaffold it."* Stop here.
     - **Otherwise** → fresh project, non-SDD branch. Tell the user, in plain English: *"No active work item. Run `/start <one-line title>` to scaffold a new one (e.g., `/start build a waitlist landing page`)."* Stop here. `/next` does not bootstrap — `/start` is the single entry point for new work.
   - **The active spec lives at** `.sdd/<active>/spec.md`. Use that path everywhere this prose says "active spec".

2. **Resolve the next step.** Run `.sdd/scripts/next-action.sh <active-spec-path>` and parse the JSON output. Fields you care about:
   - `phase` — active phase ID (SPEC / BUILD / SHIP / SHIPPED).
   - `action` — slug of the active action (e.g., `problem`, `proposed-approach`, `build-task`).
   - `step` — step ID inside that action (e.g., `who`, `why-now`, `approval`).
   - `tag` — `USER-LED` / `AGENT-LED` / `BUILD-TASK` (decides what kind of EXECUTE to run).
   - `prompt` — the step's prompt (USER-LED) or action label (AGENT-LED / BUILD-TASK).
   - `field` — where the answer goes in spec.md (e.g., `§1.who-has-it`).
   - `sub_action` — the literal `[ ]` line in spec.md (use to find + replace it).
   - `transition` — non-null when no `[ ]` step rows remain in this phase (e.g., `"SPEC→BUILD"`).

3. **If `transition` is non-null:** all step rows in the active phase are filled. Advance `[PHASE: X]` to the target phase, update INDEX.md's `**Active blocker:**` pointer to the first action of the new phase, and commit with `[SDD:<id>] phase: <from> → <to>`. Stop. The next `/next` starts the new phase.

4. **Otherwise, do ONE step based on `tag`:**

   - **`USER-LED`** → ask the user the `prompt` (verbatim) in plain English. Wait for their answer. Push for specifics if vague (one push-back, then move on with the best they gave). Replace the matched step row with `- [x] <step-id>: <one-line summary of user's answer>`. If the answer needs a paragraph, append it under the action heading after the step rows.
   - **`AGENT-LED`** → propose a concrete answer following the action prose at `.sdd/actions/<action>.md`. For actions whose prose calls for it (e.g., `proposed-approach`), show ≥2 alternatives + tradeoffs. Iterate with the user. **End each turn with the verbatim CTA from the action's prose** (typically "Reply `approve` or tell me what to change."). On approval, replace the step row with `- [x] <step-id>: <one-line summary>`; long-form content (alternatives, tradeoffs, paragraphs) goes under the action heading.
   - **`BUILD-TASK`** → BUILD-TASK has 3 steps inside it (`test`, `code`, `green`). Each step is its own commit:
     - `test`: write the failing test for the next BUILD task. Run it; must be RED. Commit.
     - `code`: write code to make the test GREEN; keep other tests GREEN. Commit.
     - `green`: flip the task line in spec.md from RED → GREEN. Commit.
     Honour the recorded `Run mode` in `## PHASE: BUILD` (step-by-step pauses; checkpoint/autonomous loop per CLAUDE.md). The Universal halting rules in CLAUDE.md apply in every mode.

5. **If the step has `triggers: [section_approved]`** (look up the action's frontmatter, find the matching step row): hash the section content via `.sdd/scripts/hash-section.sh`, record it under `verification.json.approved_sections.<action-slug>`, and append a Markdown level-2 section to `.sdd/decisions.md` per the audit-log convention in `.sdd/CLAUDE.md`. The append-only hook blocks edits to prior entries.

6. **Stage the right files.**
   - Always: the spec.md you just edited.
   - The action's `touches:` paths from frontmatter (e.g., `wireframe.html` for wireframe; `.sdd/patterns.md` for learn; `.sdd/data-model.md` for data-contract).
   - On `section_approved` triggers: `verification.json` and `decisions.md` go in the SAME commit as the spec.md change.

7. **Commit per the convention in `.sdd/CLAUDE.md`:**
   - Step filled (USER-LED / AGENT-LED): `[SDD:<id>] spec: <action-slug>/<step-id>`
   - BUILD task step: `[SDD:<id>][T<n>] <step-id>: <message>` (test / code / green)
   - Phase advance: `[SDD:<id>] phase: <from> → <to>`
   - INDEX.md status update: `[SDD] index: <id> <status>`

## Automation level — when to auto-advance vs prompt (F011)

Before doing an AGENT-LED step, read `parameters.automation.level` from
`.sdd/config.md` (via `.sdd/scripts/resolve-parameters.sh`). The value is one
of `full` / `most` / `checkpoint` and drives the decision tree:

- **`full`** → auto-advance every AGENT-LED step whose action frontmatter
  declares `requires_user_approval: false` (purely technical steps with no
  product/business/scope call). Commit + advance silently on those. Still ask
  on `requires_user_approval: true` steps (the user's product calls — §1
  problem, §5 proposed-approach, §11 acceptance criteria) and on USER-LED
  steps. Recommended once you trust the framework's defaults.

- **`most`** → auto-advance most AGENT-LED steps, **but always prompt on
  destructive actions**, regardless of `requires_user_approval`. The
  destructive list (canonical, enumerated in `parameters.automation.destructive_actions`):
  `mark-shipped`, manifest repins (`[SDD] manifest: repin` commits),
  `--delete-branch` merges, `decisions.md` append-only edits, and `.shipped`
  marker writes. On these, fall back to checkpoint behaviour: show the diff
  + ask `approve?`. The agent never silently touches the things-you-cannot-undo.

- **`checkpoint`** → today's behaviour. Prompt `approve?` at every AGENT-LED
  step. Safest and slowest. Default for new projects.

**Decision tree per step:**

1. Is this a USER-LED step? → always ask (no auto-advance, any tier).
2. Is this an AGENT-LED step?
   - Read the tier. If `checkpoint` → ask `approve?` and wait.
   - If `most` → check action against the destructive list above. If on
     the list → ask `approve?`; otherwise auto-advance.
   - If `full` → check action's frontmatter `requires_user_approval`. If
     `true` → ask `approve?`; if `false` → auto-advance.
3. Is this a BUILD-TASK step (test/code/green)? → honour the recorded
   `Run mode` instead; automation level does not apply.

When the agent auto-advances under `full` or `most`, the commit shape stays
the same (`[SDD:<id>] spec: <action-slug>/<step-id>`) — only the prompt-for-
approval is skipped. The user can still see every commit in `git log`.

The user changes tier anytime via `/sdd-config automation <full|most|checkpoint>`.

## Inline situations /next handles (no separate slash command needed)

The framework's slash-command surface stays small (Pillar 1: Simplicity). Three situations that used to have their own slash command in v0.8 now live inside `/next`:

- **Skipping a `[SKIPPABLE]` step.** When the active step or section is marked `[SKIPPABLE: <condition>]`, proactively offer to skip BEFORE asking any question: *"§N is marked skippable for X. This work item Y, so I think we should skip. Reply `skip <one-line reason>` to skip, or tell me what does apply."* On `skip <reason>`: replace every `[ ]` in the section with `⏭ skipped — <reason>`, append `[SKIPPED]` to the heading, and commit `[SDD:<id>] spec: skip <action-slug>/<step-id> — <reason>`. Never skip §1, §2, §3, §5, §6, §7, §11, §12 — they're not marked skippable.

- **Re-approving a section after intentional edits.** When the moat blocks a phase-advance commit with `"section §<slug> CHANGED since you approved it"` AND the new content is intentional, treat it as a re-approval step. Show the diff between the original-approved content and the new content. Ask the user: *"You previously approved this section, then edited it. Reply `approve` to re-lock the new content as canonical, or tell me what to change."* On `approve`: re-run `.sdd/scripts/hash-section.sh <action-slug> <work-item-dir>`, write the new hash into `verification.json.approved_sections.<action-slug>`, append a re-approval entry to `decisions.md`, commit `[SDD:<id>] spec: re-approve <action-slug>`.

- **Reporting a bug mid-conversation.** If the user describes something broken (not a feature request), don't run `/start` automatically. First confirm: *"Sounds like a bug. I'll capture this as a feature with `[BUG]` in the title — same SPEC → BUILD → SHIP flow, you'll skip sections that don't apply. Reply `confirm` or `no, it's a feature`."* On `confirm`, route to `/start [BUG] <one-line summary>`.

## Rules

- **Never** fill a `[ ]` step without the user's input in USER-LED steps.
- **Never** advance phases with open `[ ]` step rows in the current phase.
- **Never** put two atomic steps into one commit. One step = one commit.
- **Never** bootstrap a new work item from `/next` — that's `/start`'s job. If the user asks `/next` to start something new, route them to `/start <title>`.
- **Never** bypass the pre-commit hook with `--no-verify`. If a hook blocks you, read its message, fix the underlying blocker, and retry.
- **Cognitive prep is free-form.** For AGENT-LED steps, you may take multiple turns to draft, iterate, and refine before the user approves. The 1-step-per-commit rule applies to commits, not turns.

## End-of-turn

End every turn with an explicit next-action prompt per the call-to-action rules in `.sdd/CLAUDE.md`. Format: state what you just did + what to type next + (if applicable) the question or option you're presenting. Never end with "What's next: §X" alone.
