# build the SDD-on-pi extension package

[PHASE: SPEC]

**Active blocker:** §1 (first action: problem)

## PHASE: SPEC

### action: problem

- [x] who: Sam + colleagues using non-Claude models (GPT-5 via Codex, Kimi K2, open-weight models) — locked out of SDD today because it only runs in Claude Code
- [x] why-now: Three things just lined up — colleagues actively asking; GPT-5 + Kimi K2 passed the SDD discipline test today; pi.dev ecosystem matured (15+ providers, MCP solved, sibling framework GSD already ported)
- [x] what-breaks: Strategic — colleagues quietly switch to GSD by attrition, SDD becomes a Sam-only tool. Daily — every SDD session pays full Claude price even for tasks where cheaper models would do fine.

**Who has this problem:** Sam and his colleagues who use GPT-5 (via Codex), Kimi K2, or other non-Claude models when they code. Today none of them can use SDD because it only runs inside Claude Code. They want SDD's discipline — the test-first rule, the atomic-step-per-commit rhythm, the anti-theatre lint, the trust-boundary state injection — but they're not going to switch CLIs to get it. The framework's reach is currently capped at "people who happen to use Claude Code," which is a small slice of the AI-coding-agent population.

**Why now:** Three things just lined up at once.

1. **Colleagues started asking.** They want SDD's discipline but use GPT-5, Kimi K2, or pi.dev. The demand is live, not hypothetical.
2. **Non-Claude models got good enough.** Discipline test today (2026-05-07) passed 2/2: GPT-5.5 via Codex and Kimi K2 2.6 via NVIDIA Build both followed SDD's atomic-step BUILD-TASK rule cleanly without prompting tweaks. Six months ago that probably wouldn't have worked.
3. **Pi.dev matured into a real ecosystem.** 15+ model providers behind one harness, 40+ community extensions, MCP gap already solved by the community ([pi-mcp-adapter](https://github.com/nicobailon/pi-mcp-adapter), MIT, 599 stars), and a sibling spec-driven framework (GSD via [fulgidus/pi-gsd](https://github.com/fulgidus/pi-gsd)) already ported successfully — confirming the architectural pattern works.

The "if not now, when?" answer: if SDD stays Claude-only for another 6 months while GSD (60.6k stars, already supports 8 CLIs) keeps expanding, SDD risks becoming "the spec-driven framework you only get if you happen to be on Claude Code." That niche shrinks fast.

**What breaks if we don't solve it:** Two concrete things break — one strategic and cumulative, one daily.

1. **Strategic break — colleagues quietly switch to GSD by attrition.** Three months from now, a colleague (call him Marco) wants spec-driven discipline for his GPT-5/Codex setup. He searches "spec-driven framework for GPT-5." Top result: GSD (works on his CLI, 60.6k stars, supports 8 harnesses). Second result: SDD (Claude only). He picks GSD without thinking about it. He learns GSD's conventions, not SDD's. Six months in, when Sam wants colleagues to join SDD work, they all already know GSD and don't see the point of switching. SDD has become a Sam-only tool — not because it's worse, but because it didn't reach where colleagues already work.
2. **Daily break — every SDD session pays full Claude price.** There are SDD tasks where a cheaper or faster model would do fine: codebase exploration, research recon, simple BUILD tasks on small features. Today, every minute of SDD work bills Claude. With SDD-on-pi, model choice happens per task — Sonnet/Opus where it matters, Haiku/Kimi K2 where it doesn't. Without it, every research session burns Claude tokens unnecessarily.

### action: success

- [x] metric: Success = every §11 acceptance criterion passes on both Claude Code AND pi.dev harnesses, verified mechanically by the framework's standard verification path {verify-by: §11 AC pass via verify-stage.sh}

**Success metric:** Mechanical, not market.

When every acceptance criterion in §11 passes on both Claude Code AND pi.dev harnesses, verified mechanically by the framework's standard verification path (`verify-stage.sh`), this feature is done. {verify-by: §11 AC pass via verify-stage.sh}

Market metrics — colleague adoption, model-cost reduction, engagement, etc. — are intentionally **not** part of §2 here. They're market signals that arrive weeks or months after ship; treating them as success-gates would violate SDD's anti-theatre doctrine (which says: every spec claim must be mechanically verifiable, soft-annotated, or named as live-infra-only). Sam captured this concern as `ideas/004-remove-success-from-feature-playbook.md` mid-walkthrough — the framework cleanup will remove §2 entirely after 008 ships, leaning on §11 as the canonical success layer.

For 008 specifically, this means: when SPEC → BUILD → SHIP completes and §11 has all-green ACs running on both harnesses, the feature has shipped successfully. Adoption signals come later, separately.

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
