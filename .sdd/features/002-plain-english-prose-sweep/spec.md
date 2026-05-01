# plain-english prose sweep

[PHASE: SPEC]

**Active blocker:** §1 (first action: problem)

## PHASE: SPEC

### action: problem

- [x] who: Two real people. (1) Sam — the framework owner, non-technical, drives every SDD spec walk. (2) Future SDD plugin users (Anthropic marketplace candidate per the v1.0 backlog) — assumed non-technical by design. Both rely on the agent's USER-LED questions reading like "what would a smart non-coder ask?", not like a code review.
- [x] why-now: The v1.1 Tier 3 SHIP cycle caught technical drift in agent-drafted prose **four times** in one feature walk (§4 UX, §8 dependencies, §11 acceptance-criteria, §15 sweep — each pushed back with "far too technical"). Sam saved the lesson as `feedback_framework_prompts_plain_english.md` in agent memory and as the second pattern block of `[[001-tier-3-llm-driven-synthesis]]` in `.sdd/patterns.md`. The repeat-rate proves the existing CLAUDE.md "plain English first" rule is necessary but not enforcing — the agent reads framework-shipped action prose, mirrors its tone, and drifts. Fix the action prose itself and the drift goes away at the source.
- [x] what-breaks: Three concrete breakages. (1) The non-technical user freezes when asked a technical question — 5-10 min of session time wasted per incident on rephrase + retry. (2) Spec quality drops because frozen users give vague answers ("works well" instead of "200 signups by month-end"). (3) The agent's draft prose mirrors the action file it just read; if action prose says "infer the UX direction from problem, success, and user stories", the agent writes back in that voice. CLAUDE.md saying "plain English first" doesn't survive the framing the agent inherited 30 seconds earlier. Without this fix, every future SDD ceremony costs the user manual rework time, and the framework's "non-technical first" promise is theatre at every USER-LED action that ships with jargon-shaped prose.

Source: GitHub [#110](https://github.com/samuelserraceo/spec-driven-dev-workflow/issues/110); pattern block `[[001-tier-3-llm-driven-synthesis]]` second sub-block in `.sdd/patterns.md`; agent-memory `feedback_framework_prompts_plain_english.md`.

### action: success

- [ ] metric: Pick a metric pattern (volume / speed / quality / engagement) or describe your own. Give a target number AND the current baseline if known.

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
