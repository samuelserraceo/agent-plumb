---
playbook: feature
---

# promote-legacy-queued.sh migrator for pre-v1.5.2 PHASE state drift (closes #206)

[PHASE: SPEC]

**Active blocker:** §1 problem

## PHASE: SPEC

### action: brief-intake

- [x] brief: GitHub issue #206 IS the brief. Pre-v1.5.2 projects have backlog features stored as `[PHASE: SPEC]` instead of `[PHASE: QUEUED]`; ship a one-shot migrator + document it in CLAUDE.md.

#### §0 Brief

**Source:** https://github.com/samuelserraceo/spec-driven-dev-workflow/issues/206 — *"Pre-v1.5.2 queued features show `[PHASE: SPEC, §1 done]` not `[PHASE: QUEUED]` (#169 retro-fix)"*

**Problem (verbatim from issue):** Projects scaffolded before v1.5.2 — which added the `[PHASE: QUEUED]` pre-active state via #169 — have backlog features written with `[PHASE: SPEC]` instead of `[PHASE: QUEUED]`. Their INDEX.md rows look like they're in flight at SPEC rather than queued waiting for `/promote-to-active`. `/next` would happily advance them.

**Affected project (live audit 2026-05-11):** pipelogic_v2's F02-F15 all carry `[PHASE: SPEC]` despite being backlog. Plus any other multi-feature project bootstrapped before v1.5.2.

**Fix shape (two-step):**
1. **One-shot migrator** `bash .sdd/scripts/promote-legacy-queued.sh` — scans every `.sdd/<work-item-folder>/<id>-<slug>/spec.md`; if the INDEX.md row marks the item as backlog/queued but the spec.md PHASE is not `QUEUED`, flip the PHASE marker AND update the INDEX.md row to the canonical `(scaffolded, PHASE: QUEUED)` shape.
2. **Documentation** in CLAUDE.md "Multi-feature parallel work" section: one paragraph noting the migration path and when to run it (after `sdd-migrate.sh --apply`).

**Severity:** Minor — only affects pre-v1.5.2 projects. New projects don't hit this.

**Target:** v1.7 patch line (alongside v1.7.0 hook merge-exception + v1.7.1 hash-bold-strip).

### action: problem

- [ ] who: Who specifically has this problem? (real persona, not 'users')
- [ ] why-now: Why is it worth solving now?
- [ ] what-breaks: What breaks (concretely) if it isn't solved?

### action: user-stories

- [ ] stories: Which personas matter? For each: 'As <persona>, I want <action>, so that <outcome>.' 1-5 stories total.

### action: ux-brief

- [ ] brief: infer the UX direction from problem, success, and user stories

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
