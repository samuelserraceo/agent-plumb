---
playbook: feature
---

# feature playbook v2 — brief-driven SPEC entry replaces 3-question Pitch shape

[PHASE: SPEC]

**Active blocker:** §3 (action: user-stories)

## PHASE: SPEC

### action: problem

- [x] who: non-technical founders walking SPEC ceremonies on real projects
- [x] why-now: F01 audit (2026-05-08) produced 4 concrete failure modes; doctrine alone insufficient
- [x] what-breaks: 4 concrete failure modes — startup-pitch §1, redundant §2, lazy first-pass record, bundled-question turns

### §1 Problem

#### who-has-it

Non-technical founders (Sam et al.) walking through SPEC ceremonies on real projects. Specifically anyone who hits §1's three-question Pitch shape ("who / why-now / what-breaks") on work that isn't a customer-facing startup feature — foundation features, internal tools, framework dogfooding. The friction was first observed across pipelogic_v2's F01 SPEC ceremony; same shape will hit any non-startup work.

#### why-now

The F01/pipelogic_v2 audit on 2026-05-08 produced concrete evidence — four specific failure modes captured live in the transcript (line numbers cited in #207). Sam invented the grill protocol himself mid-§2 because the framework wasn't pushing back; that's clear signal doctrine alone isn't enough and structural redesign is needed. Earlier point fixes (#173/#174 grill protocol, #110 plain-English lint, #171 refresher block) closed individual leaks but didn't address the entry shape itself. The cumulative friction is now well-evidenced enough to warrant a v1.6 anchor change.

#### what-breaks

Four things break, drawn directly from #207's *"What's wrong with the current SPEC"* section:

1. **§1 Problem is startup-pitch BS for non-startup work.** Three questions ("who / why-now / what-breaks") don't fit foundation features, internal tools, or framework dogfooding — anywhere the user already knows what they want and just needs to describe it.
2. **§2 Success metrics adds zero signal beyond §11 ACs** for foundation features. Every F01 metric ended up tagged `{best-effort: clickthrough QA}`; the same checks landed in §11 anyway. Pure ceremony noise.
3. **The agent records first-pass answers without challenge.** Even after #173/#174 shipped grill protocol, the doctrine-default still leans toward "record" over "interrogate." Sam invented the grill protocol himself mid-§2 because the framework wasn't pushing back.
4. **Bundled multi-question turns + technical-prose-first drafts** violate doctrine but fire anyway. Sam had to ASK for plain English at §5 (line 4518) and again at §11 (line 26474) of the F01 transcript.

### action: success [SKIPPED]

- ⏭ metric: skipped — out of scope — this redesign deletes §2 from the playbook (per #207 Part 2; argued in §5 proposed-approach)

### §2 Success [SKIPPED]

**Skipped on purpose** — out of scope — this redesign deletes §2 from the playbook (per #207 Part 2; argued in §5 proposed-approach)

§2 success metrics for this very feature would be self-defeating. The feature's own §5 proposed-approach is going to argue for **deleting §2 from the feature playbook entirely** (issue #207 Part 2: *"§2 Success folded into §11 ACs"*). Filling in success metrics would create theatre: drafting a metric that the feature's own design says shouldn't exist.

Honest discipline: skip with documented reason. Verification of this redesign's success lives in §11 ACs (e.g., *"§2 success removed from feature playbook frontmatter; existing F009 spec.md is the last to use §2"*). That's the §11-as-the-source-of-truth pattern that #207 itself argues for — applied to its own SPEC ceremony as proof.

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
