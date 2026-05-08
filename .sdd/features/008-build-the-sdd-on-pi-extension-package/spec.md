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

- [x] stories: 4 stories — Sam (multi-model task routing), Marco (GPT-5/Codex user), Lucia (open-weight Kimi K2/Llama user), New evaluator (first-time SDD trial without committing to Claude Code)

**User stories (4 total):**

1. **Sam — multi-model task routing.** As Sam, I want to use different models for different SDD tasks (cheaper models like Haiku or Kimi K2 for codebase research and small BUILD steps; Opus/Sonnet for planning and complex code), so that I cut SDD session cost by routing each task to the right model — without losing the atomic-step discipline.

2. **Marco — GPT-5 / Codex user.** As a colleague who codes with GPT-5 in Codex every day, I want to run SDD's SPEC → BUILD → SHIP loop inside pi.dev driving GPT-5, so that I get SDD's atomic-step discipline and anti-theatre rules without leaving my preferred model.

3. **Lucia — open-weight model user.** As a colleague running Kimi K2 (or Llama, or DeepSeek) for cost or privacy reasons, I want to run SDD on pi.dev with my local/open-weight model, so that I get SDD's rigour at a fraction of the inference cost.

4. **New evaluator — first-time SDD trial.** As someone curious about SDD but not yet using Claude Code, I want to try SDD via pi.dev with whatever model I already use, so that I can test SDD's value without committing to a new CLI as the entry point.

(Names are placeholders — Sam to swap with real colleagues' names if useful before SHIP.)

### action: ux-brief [SKIPPED]

- ⏭ brief: skipped — backend-only feature — CLI extension, no UI surface

**§4 skipped:** SDD-on-pi is a CLI extension — no screens, no visual layout, no motion. Visualisation for this non-UI feature lives in §13 Wireframe (flow + architecture diagram + concrete CLI usage examples) per the wireframe-redesign rule.

### action: proposed-approach

- [x] approval: Approved approach (C) — hybrid: develop in `extensions/sdd-pi-extension/` inside the SDD repo, auto-publish to npm as `sdd-pi-adapter`. 4 moving parts (TS extension, prompts/, package.json#pi manifest, reuse existing .sdd/ brain) + 4 key technical choices acknowledged.

**Recommended approach (C — hybrid):** Ship `extensions/sdd-pi-extension/` inside the existing SDD repo, then auto-publish it to npm as `sdd-pi-adapter`.

**Moving parts (4):**

1. **One TypeScript extension file** — `src/sdd-pi.ts` (~300-400 lines), modeled on pi-gsd's `pi-gsd-hooks.ts`. Hooks: `pi.on("context")` for state injection (the equivalent of our existing UserPromptSubmit hook); `pi.on("session_start")` for one-time install (copies `.sdd/` brain into `.pi/sdd/`, version-checks); `pi.registerCommand(...)` for instant zero-LLM commands like `/sdd-status`.
2. **A small `prompts/` folder** — 9 thin templates (`sdd-start.md`, `sdd-next.md`, `sdd-ship.md`, `sdd-status.md`, `sdd-compress.md`, `sdd-skip.md`, `sdd-bug.md`, `sdd-idea.md`, `sdd-config.md`). Each is a 5-line markdown file that includes the existing `.sdd/actions/*.md` prose unchanged via pi's prompt-template `$ARGUMENTS` mechanism.
3. **A `package.json#pi` manifest** — three lines telling pi.dev where the extension entry point and prompt templates live. Standard pi convention; pi-gsd v2.x uses identical shape.
4. **Reuse existing `.sdd/` brain unchanged** — `.sdd/scripts/`, `.sdd/actions/`, `.sdd/playbooks/`, `.sdd/state files`. The extension's `session_start` handler copies them into the project's `.pi/sdd/` on first run, replacing only stale framework files (idempotent), with user-edits preserved via the same copy-on-first-run pattern pi-gsd uses (HRN-01).

**Why this answers §1-3:**

- **§1** — colleagues using non-Claude models install with one line (`pi install npm:sdd-pi-adapter`) and immediately have `/sdd-start /sdd-next /sdd-ship` available in pi.dev with whatever model they prefer.
- **§2** — mechanical success: every §11 AC passes on both Claude Code AND pi.dev harnesses, verified via `verify-stage.sh`. The discipline test that passed 2/2 today (GPT-5.5 + Kimi K2) becomes a permanent regression test inside §11.
- **§3** — all four user stories covered: Sam's per-task model routing (story 1) via pi's native `/model` switcher; Marco/Lucia get GPT-5/Kimi K2 native (stories 2-3); new evaluators install pi.dev once and try SDD without committing to Claude Code (story 4).

**Alternatives considered (3):**

- **(A) In-repo only, no npm publish.** Extension lives in `extensions/sdd-pi-extension/`. Users clone the SDD repo to use it. Rejected — install friction kills stories 2/3/4 (colleagues won't clone an unfamiliar repo).
- **(B) Separate npm-only repo `sdd-pi-adapter`.** Brand-new GitHub repo, published to npm. Mirrors pi-gsd's pattern. Rejected — version-coupling pain between two repos; SDD core changes break adapter silently; iteration during formative weeks is slower.
- **(C) Hybrid: in-repo + auto-publish to npm** ⭐ recommended — best of both worlds; one source of truth + clean install UX. Slight CI complexity (publish workflow) is the only cost.

**What we trade off:**

- **Cost:** ~30-60 minutes of GitHub Actions YAML once for the publish workflow; zero ongoing cost.
- **Complexity:** SDD repo grows by one folder; build step adds an npm publish artifact.
- **Time-to-ship:** (C) is slightly slower than (A) to write but immediately useful when shipped. (B) is slowest overall.
- **Debt:** (C) couples adapter release cadence to SDD repo cadence. If we later want to release the adapter on its own schedule, that's a future migration to (B). Acceptable given the adapter design will be stable by then.

**Key technical choices for sign-off (4):**

1. **TypeScript for the extension code.** Type-checked code = fewer silent bugs. Slightly more tooling than plain JS but follows pi.dev's own stack (pi.dev itself is TS). Risk: TS major-version upgrades occasionally break things; we follow pi.dev's version to mitigate.
2. **`package.json#pi` manifest as the contract with pi.dev.** Three lines pointing pi at the extension entry + prompts dir. Standard, documented, pi-gsd uses it stably. Risk: pi.dev pre-1.0 changes the shape — low likelihood but worth tracking.
3. **`pi-mcp-adapter` (community package, MIT, 599 stars) required for SDD's MCP integration.** Bridges pi.dev to MCP servers like our existing `extensions/sdd-mcp-server/`. Risk: pi-mcp-adapter abandoned or breaks — mitigated by documenting a fallback (skip MCP; SDD methodology still works without it).
4. **Pre-commit enforcement moves to git pre-commit hooks (not pi's `tool_call` event).** Pi's `tool_call` is advisory-only — it can warn but not block, which is insufficient for SDD's anti-theatre / atomic-step / test-first guards. Git pre-commit hooks fire deterministically at commit time regardless of CLI. Cost: user needs `git config core.hooksPath .claude/hooks` (the friction we hit today). Risk: bypassed with `--no-verify` — same as today, explicit user choice.

**Out of scope here (defer to follow-up features):**

- **Parallel wave execution** ([[ideas/002-parallel-wave-execution]]) — separate feature after 008.
- **Specialized subagents** ([[ideas/003-specialized-subagents]]) — separate feature after 008.
- **Removing §2 Success from the feature playbook** ([[ideas/004-remove-success-from-feature-playbook]]) — separate framework feature after 008.

This keeps 008 focused on one harness adapter, no scope creep.

**Approved by Sam: 2026-05-08.** Section content hashed and locked into `verification.json`; downstream edits will trigger inline re-approval per CLAUDE.md.

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
