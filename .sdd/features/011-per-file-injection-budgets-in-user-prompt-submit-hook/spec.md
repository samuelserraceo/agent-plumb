---
playbook: feature
---

# per-file injection budgets in user-prompt-submit hook

[PHASE: SPEC]

**Active blocker:** §1 (first action: brief-intake)

## PHASE: SPEC

### action: brief-intake

- [x] brief: agent-authored — replace 16K total-cap + truncate-from-end with per-file budgets so each corpus file (INDEX/spec/principles/stack/data-model/patterns) gets its own char allocation; overflow truncates individually with a sentinel. Closes idea 003's full-reorder prerequisite (#228 shipped INDEX-live filter as partial)

**§0 Brief intake**

Recap (3 bullets):

1. **Problem:** `user-prompt-submit.sh` today injects all corpus files (INDEX, spec, principles, stack, data-model, patterns) up to a single 16K total cap, then truncates from the end. On mature SDD projects patterns.md alone is 20KB; the last file in injection order gets cut entirely or mid-content. Agent loses visibility of accumulated lessons + active state.
2. **Fix:** new per-file budget map in `config.md` (`parameters.injection.per_file_budget_chars`), each file truncated individually to its budget with a `[truncated to <N> bytes — re-read explicitly]` sentinel. Total `cap_total_chars` stays as safety net. Defaults: INDEX=3K, spec=5K, principles=2K, stack=3K, data-model=3K, patterns=4K — ~20K total (over the 16K-only-cap floor, but the cap stays as a safety-net).
3. **Closes:** idea 003 full-reorder prerequisite from yesterday's brainstorm (#228 shipped the INDEX-live filter; this is the principled-allocation fix that the reorder needs to actually work without dropping INDEX/spec).

### action: problem

- [x] who: SDD framework maintainers and downstream users on mature projects — Sam first (patterns.md is 20KB on this repo today, gets silently cut mid-paragraph every turn), downstream users hit the same problem as their patterns.md grows
- [x] why-now: patterns.md hit 20KB on this repo this week (4 features shipped 2026-05-10/11 each adding lessons); #228 shipped the INDEX-live filter as the small win, but the full idea-003 reorder is blocked on this because today's "truncate from end" drops INDEX+spec entirely when stable corpus is reordered to the top — per-file budgets unblock the reorder
- [x] what-breaks: agent loses memory of accumulated patterns (cut mid-paragraph or entirely); idea 003's stable-first cache reorder can't ship (would push INDEX+spec off the cap and lose active state); patterns.md keeps growing so the truncation gets worse every shipped feature

### action: user-stories

- [x] stories: 3 stories — Sam wants per-file budgets so patterns.md doesn't silently lose mid-paragraph content; downstream user wants budgets configurable per-project (their patterns might be smaller); AI agent wants every corpus file at least partially visible so it doesn't propose things that contradict patterns it can't see

**User stories**

1. **As** Sam (framework maintainer on a mature project where patterns.md is 20KB), **I want** the user-prompt-submit hook to give each corpus file its own size budget instead of cutting from the end, **so that** patterns.md doesn't keep losing mid-paragraph content every turn as it grows.
2. **As** a downstream SDD user with a different project shape (e.g. patterns.md small, data-model.md huge), **I want** to override the default per-file budgets in my project's `config.md`, **so that** the budgets match what my project actually needs to see most.
3. **As** the AI agent running the session, **I want** every corpus file to appear at least up to its budget in the injection (never dropped entirely), **so that** I don't silently propose something that contradicts patterns I can't see.

### action: ux-brief [SKIPPED]

- ⏭ brief: skipped — non-UI feature (hook script + config schema change; no user-facing surface beyond config.md edits)

### action: proposed-approach

- [ ] approval: draft the approach with 2 alternatives and tradeoffs, iterate with the user, get approval

### action: data-contract

- [ ] approval: draft the data contract, iterate with the user, sync data-model.md, get approval

### action: flows

- [ ] flows: draft 1-3 critical flows, each referencing the user story it implements

### action: dependencies

- [ ] deps: draft external services + pricing math scaled to success-volume targets

### action: out-of-scope

- [ ] list: What are we explicitly NOT building this round? 1-5 bullets, each: name + reason. Empty is fine.
- [ ] approval: user_approves

### action: non-functional

- [ ] constraints: draft performance, security, and compliance constraints

### action: acceptance-criteria

- [ ] approval: draft the acceptance criteria, run a constraint-coverage check vs §4, iterate, get approval

### action: signoff-steps

- [ ] manual-steps: What manual smoke tests do YOU need to do before SHIP, beyond the automated tests? 1-5 bullets.

### action: wireframe

- [ ] wireframe: draft wireframe.html — UI screens for UI features OR flow + architecture for non-UI features

### action: plan-decompose

- [ ] tasks: convert acceptance criteria into ordered build tasks (one test file per task)

### action: edge-case-sweep

- [ ] ec-sweep: draft
- [ ] ec-pick: ask

### Exit checks
- [ ] C-spec-acs: ≥1 acceptance criterion exists in §11 {verify-by: C-spec-acs bash-grep} — grep -qE '^- \[[ x]\] AC[0-9]+' "$SECTION_FILE"
- [ ] C-spec-tasks: ≥1 task in plan-decompose section {verify-by: C-spec-tasks bash-grep} — grep -qE '^- \[[ x]\] T[0-9]+' "$SECTION_FILE"
