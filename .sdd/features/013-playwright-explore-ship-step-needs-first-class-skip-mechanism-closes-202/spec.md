---
playbook: feature
---

# playwright-explore SHIP step needs first-class skip mechanism (closes #202)

[PHASE: BUILD]

**Active blocker:** SHIP — all 3 tasks GREEN; ready to PR

**Run mode:** full-autonomous

## PHASE: SPEC

### action: brief-intake

- [x] brief: GitHub issue #202 IS the brief. Add `skip_when:` frontmatter field + clean single-line skip log shape to `playwright-explore.md`; agent reads + mirrors at SHIP time.

#### §0 Brief

**Source:** https://github.com/samuelserraceo/spec-driven-dev-workflow/issues/202 — *"playwright-explore skips silently when MCP missing — needs first-class skip mechanism"*

**Problem (from issue):** `playwright-explore` action is doctrine-required during SHIP, but when the MCP server isn't configured the agent skips it inline with a long justification comment instead of using a first-class `[SKIPPED]` mechanism. F01 SHIP at transcript line 30493 emitted a 12-line inline comment explaining why playwright-explore was being skipped, then proceeded to the next SHIP action. No `[SKIPPED]` marker, no INDEX.md log, no decisions.md entry — pure noise for the non-technical reader.

**Fix-shape (from issue):** add a `skip_when:` frontmatter field naming the MCP-missing condition + canonical single-line skip log. When the condition matches, the agent emits the skip log (not the 12-line wall) and proceeds.

**Severity:** Minor — cosmetic; the skip itself is correct, just noisy.

**Target:** v1.7 patch line — v1.7.3 candidate alongside the v1.7 maintenance trio (v1.7.0/.1/.2).

### action: problem

- [x] who: framework users running `/ship` on a project that hasn't enabled the playwright-explorer MCP extension; the agent currently emits 12 lines of inline justification before moving on
- [x] why-now: F01/pipelogic_v2 audit (2026-05-08) showed the failure mode at transcript line 30493; v1.7 maintenance trio is already shipping cosmetic-noise fixes (#197p2 hash bold-strip, #220 hook merge-exception); this is the same shape
- [x] what-breaks: 12-line wall of "why I'm skipping this" prose every SHIP run on un-Playwright'd projects; non-technical reader can't tell at a glance whether the skip was intentional or a hidden failure {verify-by: T-001}

#### §1 Problem

#### who-has-it

Framework users running `/ship` on projects that haven't enabled the `playwright-explorer` MCP extension (default state — projects opt in via `bash .sdd/extensions/playwright-explorer/enable.sh`). The current `playwright-explore` action prose assumes the explorer is on PATH; when it isn't, the agent improvises a justification block instead of following a canonical skip path.

#### why-now

F01/pipelogic_v2 audit (2026-05-08, transcript line 30493) caught this in the wild — 12-line inline comment ("MCP server isn't configured for this project — playwright-explore depends on the explorer extension shipped via `.sdd/extensions/playwright-explorer/`...") before proceeding. The v1.7 maintenance trio (#197p2 hash bold-strip + #220 hook merge-exception + #206 legacy-queued migrator) has been clearing cosmetic-noise drift; this is the same shape and fits the v1.7.3 patch line.

#### what-breaks

3 concrete failure modes {verify-by: T-001 / T-002}:

1. **12-line wall on every un-Playwright'd SHIP.** Non-technical reader (Sam et al.) can't tell at a glance whether the skip was intentional config or a hidden failure mode. The skip itself is correct; the noise is the problem.
2. **No `[SKIPPED]` marker = no audit-trail.** Other skippable actions emit `⏭ skipped — <reason>` step rows + a decisions.md entry; `playwright-explore` doesn't follow the same shape.
3. **Agent has no canonical guidance.** Every agent invocation that hits this case improvises wording. The action prose should ship the canonical shape so the output is identical run-to-run.

### action: user-stories

- [x] stories: 2 personas — non-technical reader scanning SHIP output + framework agent emitting the skip

#### §3 User Stories

#### Story 1 — Non-technical reader scanning SHIP output

> *As Sam reading `/ship` output on a project without the Playwright explorer enabled, I want to see ONE line — `playwright-explore: SKIPPED — explorer not installed` — so I can scroll past it instantly instead of parsing a 12-line wall to confirm "yes, the skip was intentional."*

#### Story 2 — Framework agent emitting the skip

> *As the agent reaching the `playwright-explore` action at SHIP time, I want a canonical `skip_when:` clause in the action's frontmatter naming the MCP-missing condition + the exact skip-log shape, so I emit the same single line every time instead of improvising 12 lines of justification.*

### action: ux-brief

- [x] brief: no UI surface — pure action-prose change. The primary surface is the `/ship` transcript line the user reads on un-Playwright'd projects.

#### §4 UX & Design brief

**Primary surface:** the `/ship` transcript when playwright-explore fires on a project where the explorer MCP isn't installed.

**Before fix (current — F01 transcript line 30493 shape, 12 lines):**

```
playwright-explore: skipping. MCP server isn't configured for this project —
playwright-explore depends on the explorer extension shipped via
.sdd/extensions/playwright-explorer/, and that extension's CLI isn't in PATH
for this Claude Code session. The user can enable it later via
bash .sdd/extensions/playwright-explorer/enable.sh which sets up the
provider config in .sdd/config.md under parameters.playwright_explorer.
Once enabled, future /ship runs will fire this action against the live
deployment URL from .sdd/stack.md ## Running services. Until then,
the empirical edge-case layer is deferred; the analytical adversarial-review
layer still runs. Proceeding to next SHIP action.
```

**After fix (target — 1 line):**

```
playwright-explore: SKIPPED — explorer not installed; install via `bash .sdd/extensions/playwright-explorer/enable.sh`
```

**Tone:** terse, one line, recovery path included verbatim (the user gets the install command without scrolling). Same shape as the framework's existing `⏭ skipped — <reason>` convention on other skippable actions.

**No HTML wireframe** — action-prose change. Skip §13.

### action: proposed-approach

- [x] approval: AUTONOMOUS DRAFT — single action-prose change to `templates/.sdd/actions/playwright-explore.md`; adds `skip_when:` frontmatter field + a short prose section modelling the canonical skip output.

#### §5 Proposed approach

**Approach (chosen):** minimum-diff edit to `templates/.sdd/actions/playwright-explore.md`:

1. **Frontmatter `skip_when:` field** — declares the MCP-missing condition + the canonical single-line skip log. Documentation for the agent; the agent reads it at SHIP time and decides to skip.

   ```yaml
   skip_when:
     - condition: "playwright-explorer MCP server not configured (extension not enabled)"
       detect: "no parameters.playwright_explorer.provider in .sdd/config.md"
       log_line: "playwright-explore: SKIPPED — explorer not installed; install via `bash .sdd/extensions/playwright-explorer/enable.sh`"
   ```

2. **Body prose addition** — a new `## When to skip` section above `**What it looks like:**` that says, in plain English: *"If `.sdd/config.md` has no `parameters.playwright_explorer` block, emit the canonical single-line skip log from the frontmatter's `skip_when[0].log_line` (NOT a 12-line justification block) and advance."*

3. **No new code paths needed.** The frontmatter field is documentation; the agent reads + honours it. Same shape as `requires_user_approval`, `prelude_refresh`, `trust` — all read by the agent, not by a runtime evaluator.

**Alternatives considered + rejected:**
- *Runtime `skip_when` evaluator in next-action.sh.* Rejected — requires bash/python config parsing + hook integration; over-engineering for a cosmetic fix.
- *Just delete the playwright-explore action when the extension isn't enabled.* Rejected — leaves a hole in the SHIP action sequence; agent reading the playbook would see a missing action and improvise.

**Risk register:**
- **Future skip_when shape evolution** — if multiple skip conditions emerge, the YAML list pattern already accommodates them. Low risk.
- **Agent ignores the field** — the lint check (T03) asserts the field exists; the agent's reading discipline is a foundation-3 behavioural cue. Best-effort.

**Status:** AUTONOMOUS DRAFT.

### action: data-contract

- [x] approval: AUTONOMOUS DRAFT — no new entities. Pure action-prose change.

#### §6 Data contract

No new entities. `templates/.sdd/actions/playwright-explore.md` gains a frontmatter field + body prose. `data-model.md` unchanged.

### action: flows

- [x] flows: 1 flow — agent reaches §14 playwright-explore at SHIP on un-Playwright'd project

#### §7 Flows

```text
Agent: reads templates/.sdd/actions/playwright-explore.md frontmatter
       sees skip_when[0].condition: "playwright-explorer MCP server not configured"
       sees skip_when[0].detect:    "no parameters.playwright_explorer.provider in .sdd/config.md"
Agent: greps .sdd/config.md for parameters.playwright_explorer.provider
       -> not found
Agent: emits skip_when[0].log_line verbatim:
       "playwright-explore: SKIPPED — explorer not installed; install via `bash .sdd/extensions/playwright-explorer/enable.sh`"
Agent: marks the action's step rows as `⏭ skipped — explorer not installed`
Agent: appends a one-line decisions.md entry (per ## Audit log doctrine)
Agent: advances to next SHIP action
```

### action: dependencies

- [x] deps: zero new deps (pure frontmatter + prose change)

### action: out-of-scope

- [x] list: 3 explicit deferrals
- [x] approval: AUTONOMOUS DRAFT

#### §9 Out-of-scope

3 explicit deferrals:

1. **Runtime `skip_when` evaluator in next-action.sh.** Out of scope; agent-reading-prose is the discipline (same as `requires_user_approval`).
2. **Auto-installing the playwright-explorer MCP extension at first SHIP.** Out of scope; extensions are opt-in.
3. **Generalising `skip_when:` to all 26 actions.** Out of scope; only `playwright-explore` has the documented failure mode today. A follow-up can extend the pattern to other actions if the same shape recurs.

### action: non-functional

- [x] constraints: no perf/security/compliance impact (action-prose change)

### action: acceptance-criteria

- [x] approval: AUTONOMOUS DRAFT — 3 ACs

#### §11 Acceptance criteria

- [ ] AC1: `templates/.sdd/actions/playwright-explore.md` frontmatter has a `skip_when:` list with at least one entry; entry has `condition`, `detect`, and `log_line` keys {verify-by: T-001} — `tests/task-001.sh`
- [ ] AC2: `skip_when[0].log_line` is a single line (no embedded newlines), starts with `playwright-explore: SKIPPED`, and contains the install command `bash .sdd/extensions/playwright-explorer/enable.sh` {verify-by: T-002} — `tests/task-002.sh`
- [ ] AC3: `templates/.sdd/actions/playwright-explore.md` body has a `## When to skip` section before the `**What it looks like:**` block, naming the canonical single-line log + telling the agent NOT to emit a multi-line justification {verify-by: T-003} — `tests/task-003.sh`

### action: signoff-steps

- [x] manual-steps: 1 manual smoke

#### §12 Sign-off

1. After this PR lands and you upgrade a project via `bash .sdd/scripts/sdd-migrate.sh --apply`, run `/ship` on a project without the playwright-explorer extension. Confirm the SHIP transcript shows ONE line `playwright-explore: SKIPPED — explorer not installed; install via bash .sdd/extensions/playwright-explorer/enable.sh` and no 12-line justification block. {best-effort: Sam at SHIP smoke}

### action: wireframe

- [x] wireframe: skipped — action-prose change, no UI

### action: plan-decompose

- [x] tasks: AUTONOMOUS DRAFT — 3 tasks T01-T03 mapped 1:1 to AC1-AC3

#### §14 Plan-Decompose

- [x] T01: Add `skip_when:` frontmatter field to `templates/.sdd/actions/playwright-explore.md` with condition + detect + log_line. Test: `tests/task-001.sh` GREEN. AC1 mapped.
- [x] T02: Validate the log_line shape (single line, prefix, install command). Test: `tests/task-002.sh` GREEN. AC2 mapped.
- [x] T03: Add `## When to skip` body section before `**What it looks like:**`. Test: `tests/task-003.sh` GREEN. AC3 mapped.

**Status:** AUTONOMOUS DRAFT.

### action: edge-case-sweep

- [x] ec-sweep: 3 edge cases
- [x] ec-pick: AUTONOMOUS DRAFT

#### §15 Edge cases

1. EC#1 — Extension partially installed (provider set but endpoint blank). Out of scope; same canonical skip log fires; "install via enable.sh" recovery path covers this.
2. EC#2 — User has Playwright extension via a different path (custom MCP server). Out of scope; the canonical log mentions the framework's enable.sh; user reading it will know it's not the right recovery for their custom setup.
3. EC#3 — Future actions need `skip_when:` for different conditions. Out of scope (per §9 deferral 3); pattern is extensible but only `playwright-explore` ships with it today.

### Exit checks
- [ ] C-spec-acs: ≥1 acceptance criterion exists in §11 {verify-by: C-spec-acs bash-grep} — grep -qE '^- \[[ x]\] AC[0-9]+' "$SECTION_FILE"
- [ ] C-spec-tasks: ≥1 task in plan-decompose section {verify-by: C-spec-tasks bash-grep} — grep -qE '^- \[[ x]\] T[0-9]+' "$SECTION_FILE"

## PHASE: BUILD

### action: run-mode-chosen

- [x] mode: full-autonomous

**Run mode:** full-autonomous

### action: build-task

(driven by §14 tasks T01-T03)

### exit_checks

- [ ] C-build-tasks-green: every task is GREEN — `grep -cE '^- \[x\] T[0-9]+' "$SECTION_FILE"` matches T-row count in §14
