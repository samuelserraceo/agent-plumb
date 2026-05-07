# build the SDD-on-pi extension package

[PHASE: SPEC]

**Active blocker:** §1 (first action: problem)

## PHASE: SPEC

### action: problem

- [x] who: Sam + colleagues using non-Claude models (GPT-5 via Codex, Kimi K2, open-weight models) — locked out of SDD today because it only runs in Claude Code
- [ ] why-now: Why is it worth solving now?
- [ ] what-breaks: What breaks (concretely) if it isn't solved?

**Who has this problem:** Sam and his colleagues who use GPT-5 (via Codex), Kimi K2, or other non-Claude models when they code. Today none of them can use SDD because it only runs inside Claude Code. They want SDD's discipline — the test-first rule, the atomic-step-per-commit rhythm, the anti-theatre lint, the trust-boundary state injection — but they're not going to switch CLIs to get it. The framework's reach is currently capped at "people who happen to use Claude Code," which is a small slice of the AI-coding-agent population.

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
- [ ] C-spec-acs: ≥1 acceptance criterion exists in §11 — grep -qE '^- \[[ x]\] AC[0-9]+' "$SECTION_FILE" {verify-by: verify-stage.sh}
- [ ] C-spec-tasks: ≥1 task in plan-decompose section — grep -qE '^- \[[ x]\] T[0-9]+' "$SECTION_FILE" {verify-by: verify-stage.sh}
