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

- [x] metric: **Quality, dual co-equal measures.**
  - **(1) Backward-facing — pushback count.** Across the next 3 feature SHIP cycles after this one ships, count Sam's "far too technical" / "use plain English" pushbacks during USER-LED or AGENT-LED drafts. **Target: 0.** Baseline (Tier 3 v1.1, the last cycle before this fix): 4 in one feature.
  - **(2) Forward-facing — coverage.** Every USER-LED or AGENT-LED action file under `templates/.sdd/actions/` ships with: a plain-English version of its main question first, the technical label (if any) second, and at least one "what it looks like" concrete example. **Target: 100% of qualifying files.** Baseline: TBD via the §11 plan-decompose audit pass — Tier 3's catches were §4, §8, §11, §15, so at minimum 4 files are known-failing today; the sweep counts them all.
  - Both measures together: pushback-count is the *outcome*, coverage is the *mechanism*. We need both to confirm the fix worked AND was applied systematically, not just at the spots Sam happened to push back on.

### action: user-stories

- [x] stories: Three personas — the SDD agent, Sam (current owner), and a future plugin-marketplace user (non-technical first-time SDD adopter).

  **Story 1 — Agent draft fidelity.**
  *As the SDD agent, I want every USER-LED / AGENT-LED action file to lead with plain-English question wording, so that when I draft my first turn for the user I mirror that voice instead of slipping into technical jargon I'd otherwise default to.*

  **Story 2 — Sam answers in 30 seconds.**
  *As Sam (non-technical owner walking a SPEC), I want every framework-shipped question to read like a smart non-coder asked it, so that I can answer in 30 seconds instead of 5-10 minutes lost to "what does that even mean" mental rephrase.*

  **Story 3 — Marketplace adopter doesn't bounce.**
  *As a non-technical plugin-marketplace user trying SDD for the first time, I want the framework's first SPEC ceremony to feel like a smart conversation, so that I don't bounce off after question #2 thinking "this is for engineers, not me."*

### action: ux-brief [SKIPPED]

- ⏭ skipped — non-UI feature. This work-item only edits framework-shipped markdown files (`templates/.sdd/actions/*.md`); there's no user-visible UI surface. The agent's chat output is the closest thing to a "UX surface" — and the prose-sweep IS the UX brief, just expressed as the §11 acceptance criteria below.

### action: proposed-approach

- [ ] approval: draft the approach with 2 alternatives and tradeoffs, iterate with the user, get approval

**Approach: Audit + sweep + mechanical lint, two passes.**

**Pass 1 — content sweep (manual, BUILD task).**
For every file in `templates/.sdd/actions/*.md` whose frontmatter has `tag: USER-LED` or `tag: AGENT-LED`:

1. Read the body. Identify the *first* user-facing sentence the agent would mirror.
2. If it leads with technical framing ("infer the UX direction from problem, success, and user stories"), rewrite to lead with plain-English first ("What does this need to look and feel like to the person using it? Read what we already know about the problem and the user, then propose a direction.").
3. Add a `**What it looks like:**` block with a concrete plain-English example of how the agent should phrase its question to the user. Keep technical phrasing as a *secondary* label if useful, never as the primary.

**Pass 2 — mechanical lint (BUILD task).**
New script `.sdd/scripts/lint-action-prose.sh` that scans every `templates/.sdd/actions/*.md`. For files where the frontmatter `tag:` is `USER-LED` or `AGENT-LED`:

- **Check 1:** body contains a literal `**What it looks like:**` heading (ASCII heuristic, deterministic — no jargon denylists).
- **Check 2:** body's first non-frontmatter paragraph is ≤2 sentences AND ≤200 characters total. (The opening line is what shapes the agent's draft; long technical preambles are the failure mode we're catching.)

The script exits non-zero with a plain-English error naming each violating file + which check failed. Hook into `test/run-framework-test.sh` as a new T-numbered gate; CI then catches future drift on every PR.

**Pass 3 — wire CLAUDE.md doctrine update.**
Add a one-line rule under "Code-quality doctrine" pointing at the lint: *"Action prose ships plain-English-first. Verified by `lint-action-prose.sh` on every PR."*

**Approach: 2 alternatives considered + rejected.**

- **Alternative B — Heuristic jargon denylist.** Instead of asserting `**What it looks like:**` exists, the lint scans for a denylist of jargon tokens (`infer`, `derive`, `compute`, etc.) and warns if any appear in the *first* paragraph. Rejected: every denylist either has false positives ("derive a name" is fine) or false negatives (jargon-loaded technical writing using only Anglo-Saxon roots). Foundation 3 ("never assume, always check") prefers a *positive* assertion (the file ships the example block) over a *negative* heuristic (no jargon detected).

- **Alternative C — Structured frontmatter `plain_english_question:`.** Each action file's frontmatter gains a new field that the agent reads INSTEAD of the technical `prompt:`. The technical `prompt:` becomes implementation-internal. Rejected: doubles the maintenance surface (every action edit now updates both fields), forces a schema migration across 22 existing action files in one shot, and the existing `prompt:` is ALREADY in the user-shown chat — making it redundant. Foundation 1 (simplicity) prefers fixing the existing prose to *be* plain English over adding parallel fields.

**Pattern reused:** [[pattern:never-assume-always-check]] — the lint enforces a *positive* deterministic check, not a heuristic guess.

### action: data-contract

- [ ] approval: draft the data contract, iterate with the user, sync data-model.md, get approval

**No schema changes.** This feature only edits framework-shipped markdown files (`templates/.sdd/actions/*.md`) and adds one bash script (`.sdd/scripts/lint-action-prose.sh`). No new entities, no fields added or modified, no `data-model.md` impact.

The action files' YAML frontmatter shape is untouched (we are not adding a `plain_english_question:` field — see §5 alternative C, rejected). The body prose is rewritten in place.

Approval row left [ ] — same flow as §5; Sam ticks at approval-pass time.

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
