---
playbook: feature
---

# feature playbook v2 — brief-driven SPEC entry replaces 3-question Pitch shape

[PHASE: SPEC]

**Active blocker:** §1 (first action: problem)

## PHASE: SPEC

### action: problem

- [x] who: non-technical founders walking SPEC ceremonies on real projects
- [x] why-now: F01 audit (2026-05-08) produced 4 concrete failure modes; doctrine alone insufficient
- [ ] what-breaks: What breaks (concretely) if it isn't solved?

### §1 Problem

#### who-has-it

Non-technical founders (Sam et al.) walking through SPEC ceremonies on real projects. Specifically anyone who hits §1's three-question Pitch shape ("who / why-now / what-breaks") on work that isn't a customer-facing startup feature — foundation features, internal tools, framework dogfooding. The friction was first observed across pipelogic_v2's F01 SPEC ceremony; same shape will hit any non-startup work.

#### why-now

The F01/pipelogic_v2 audit on 2026-05-08 produced concrete evidence — four specific failure modes captured live in the transcript (line numbers cited in #207). Sam invented the grill protocol himself mid-§2 because the framework wasn't pushing back; that's clear signal doctrine alone isn't enough and structural redesign is needed. Earlier point fixes (#173/#174 grill protocol, #110 plain-English lint, #171 refresher block) closed individual leaks but didn't address the entry shape itself. The cumulative friction is now well-evidenced enough to warrant a v1.6 anchor change.

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
