---
playbook: feature
---

# background while waiting

[PHASE: SPEC]

**Active blocker:** §1 (first action: problem)

## PHASE: SPEC

### action: problem

- [x] who: SDD project owner (Sam) dogfooding the framework on its own development loop — the immediate-and-only person hitting CR/CI deadtime today; downstream SDD users inherit benefit
- [x] why-now: v1.5+ improvement queue is bottlenecked on CR/CI idle time; #42 parallel-features already shipped giving the agent a concrete "next safe thing" target; landing 004 first compounds savings on every subsequent v1.6+ improvement
- [x] what-breaks: every shipped framework feature carries 15-30 min of agent + Sam idle wall-clock; the v1.5+ improvement queue ships much slower than it could; deadtime breaks Sam's flow and burns attention with nothing to do

### action: success

- [x] metric: engagement — 100% of CR/CI waits ≥3 min trigger ≥1 always-safe background action {verify-by: marker emit count in CR-poll loop == wait-event count, measured across next 5 framework features after 008 ships}; baseline 0% today (current poll loop is idle) {verify-by: grep .sdd/scripts/ for background-emit calls — expect zero matches at HEAD~0}

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
