---
playbook: feature
---

# parallel wave execution

[PHASE: SPEC]

**Active blocker:** §1 (first action: problem)

## PHASE: SPEC

### action: problem

- [x] who: Sam, when running BUILD phases with many small independent tasks (F008 lived this — 36 atomic commits, orchestrator context filled past turn ~50, small drift started landing). Future adopters too — pain scales with task count × task independence.
- [x] why-now: Three signals just lined up — F008 unlocked multi-model so sub-task delegation is now physically possible; F008 made the context-rot pain concrete (36 commits, 3 CR cycles, residual drift); GSD's proven parallel-wave pattern is mature prior art (Sam said live "I really want to execute" this during the GSD comparison).
- [ ] what-breaks: What breaks (concretely) if it isn't solved?

**Who has this problem:** Sam is the primary persona. Specifically: Sam running an SDD BUILD phase with 10+ acceptance criteria and 30+ atomic build tasks. F008 just lived it — 36 atomic commits across the BUILD walk, then 3 CR cycles cleaning up small drift the orchestrator should have caught itself but didn't (T200-T211 residual references after T212 was added, "12 vs 13 task count" mismatches across multiple spec sections, post-cycle-2 partial-e2e gap). The CR cycles burned real time fixing what fresh-context tasks would not have produced.

The same shape hits any SDD adopter doing big-feature work — anyone scaffolding multi-component features (endpoint + tests + docs + types per item × N items). They pay wall-clock cost (linear walk) and quality cost (orchestrator context-rot) — both compound on long sessions.

**Why now:** Three things just lined up at once.

1. **F008 just unlocked multi-model.** Before F008, every step ran the orchestrator's model. With pi.dev as the second harness, sub-task delegation to Haiku or Kimi K2 is real. The cost-and-quality combo of "waves × cheaper-model" now becomes physically possible — without that, parallel waves would just mean "more parallel Sonnet-rate calls," which is a dubious win on its own.
2. **F008 made the pain concrete.** 36 BUILD-task commits + 3 CR cycles + post-cycle-2 partial-e2e gap = real lived cost. Sam has the receipts: turn ~50 onwards had small drift CR caught (T200-T211 residual references, task-count mismatches, deferred-vs-blocked confusion). Each one cost a cycle to fix.
3. **Prior art is mature.** GSD's `/gsd-execute-phase` parallel-wave logic is in production at fulgidus/pi-gsd v2.1.4 — the same pattern Sam saw during the SDD-vs-GSD comparison walk and explicitly said "this is something I really want to execute." The architecture works; we need a smaller version that fits SDD's atomic-step doctrine.

The "if not now, when?" answer: as adopters take SDD-on-pi for bigger features (now physically possible with multi-model), the context-rot ceiling gets hit faster. Without waves, the multi-model unlock pays half its dividend.

### action: success

- [ ] metric: Pick a metric pattern (volume / speed / quality / engagement) or describe your own. Give a target number AND the current baseline if known.

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
