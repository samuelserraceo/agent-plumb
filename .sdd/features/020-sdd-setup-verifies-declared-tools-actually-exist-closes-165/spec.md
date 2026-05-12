---
playbook: feature
---

# sdd-setup verifies declared tools actually exist (closes #165)

[PHASE: SPEC]

**Active blocker:** §1 (first action: brief-intake)

## PHASE: SPEC

### action: brief-intake

- [x] brief: Sam-authored GitHub issue #165 (captured 2026-05-08, lived during PipeLogic V2 setup 2026-05-05) is the brief source. Pattern: `/sdd-setup` asks plain-English questions, records answers in stack.md/config.md, then moves on — there is no follow-up step that verifies the answers reflect reality. Failure mode lived during PipeLogic V2 install: user says "I'll use CodeRabbit" but had not installed the App; agent waited silently for reviews that did not arrive. Issue spec'd 6 concrete verify steps for a new post-wizard action `/sdd-verify-stack`: (1) CR App installed via `gh api repos/.../installation`; (2) Copilot review via gh api; (3) branch-protection on main matches declared required-checks; (4) required CI workflow files exist for declared job names; (5) Tier 3 LLM provider reachable (Ollama curl probe, OpenAI key env-var presence); (6) test runner deps present in package.json. Pre-fills §1 (who/why-now/what-breaks) + §3 (user-stories) + §5 (proposed-approach as a sketch only, awaiting your alternatives review) + §9 (out-of-scope deferrals already in issue body).

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
