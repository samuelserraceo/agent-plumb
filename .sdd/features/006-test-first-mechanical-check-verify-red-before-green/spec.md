# test-first mechanical check — verify RED before GREEN

[PHASE: SPEC]

**Active blocker:** §5 (next action: proposed-approach)

## PHASE: SPEC

### action: problem

- [x] who: Sam (framework user/maintainer) and future contributors. Anyone running an SDD project relies on the test-first claim being real, but right now nothing actually checks it.
- [x] why-now: yesterday's audit identified test-first-as-discipline as one of the 3 must-fix gaps before public release. The other 2 (backend scope-guard / shipped-row tamper detection) shipped in PRs #150 + #151 overnight. This is the last item before the SDD-identity claim is mechanically backed up.
- [x] what-breaks: the AI can write code AND test together in one commit, where the test happens to pass on first run because the code is already there. The framework treats this as a successful T01 GREEN. Future regressions sneak in because the test doesn't actually pin behaviour — it was written to pass against whatever the code happens to do, not to fail before the code existed.

### action: success

- [x] metric: **quality** — a fake-test-first commit attempt is mechanically refused. Measurable as a regression test in the framework's own suite: stage a code+test together where the test passes without the code, run the safety hook → expect refusal with a clear error. **Target**: 1 new regression test passes (binary), AND existing 203+ framework tests still pass (no regression). **Baseline**: today, 0 fake-test-first attempts are caught.

### action: user-stories

- [x] stories: 3 personas — Sam (framework user) wants commits with theatre tests refused; future SDD contributors get the same catch even if they don't know test-first discipline; PR reviewers want T01 GREEN to mean test was RED first, not written-to-match-code.

### action: ux-brief [SKIPPED]

- ⏭ skipped — no UI surface, backend hook only

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
