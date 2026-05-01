# Tier 3 LLM-driven synthesis

[PHASE: SPEC]

**Active blocker:** §3 (user-stories)

## PHASE: SPEC

### action: problem

- [x] who: agent + Sam (primary in v1.1); future teammates + downstream adopters (later — design must not preclude them)
- [x] why-now: complex projects need full-picture agent + token efficiency — both co-equal drivers, not one then the other
- [x] what-breaks: roadmap velocity wall — Sam ends up patching agent-memory issues instead of shipping features

### action: success

- [x] metric: dual co-equal — (1) quality: ≥80% of synthesised answers cite-check correctly on framework corpus (baseline: no synthesis exists today); (2) cost: avg synthesised answer <1 KB (baseline: Tier 2 returns ~5–20 KB raw chunks per question)

### action: user-stories

- [ ] stories: Which personas matter? For each: 'As <persona>, I want <action>, so that <outcome>.' 2-5 stories total.

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

- [ ] wireframe: draft wireframe.html — one screen per user story

### action: plan-decompose

- [ ] tasks: convert acceptance criteria into ordered build tasks (one test file per task)

### action: edge-case-sweep

- [ ] ec-sweep: draft
- [ ] ec-pick: ask

### Exit checks
- [ ] C-spec-acs: ≥1 acceptance criterion exists in §11
- [ ] C-spec-tasks: ≥1 task in plan-decompose section
