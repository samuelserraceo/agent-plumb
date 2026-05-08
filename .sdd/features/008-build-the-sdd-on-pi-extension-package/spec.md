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

- [x] approval: No new project-state entities. One new framework-level concept added to data-model.md ([[entity:pi-extension-package]]). Existing entities ([[entity:Action]], [[entity:Playbook]], [[entity:Hook]], [[entity:Setup-brick]]) gain no new fields.

**Data contract:** No new project-state entities. Pi adapter is a new way to *access* the existing brain — it doesn't add fields, tables, or files to user data.

| Layer | Change | Why |
|---|---|---|
| **Project state** (spec.md, INDEX.md, decisions.md, patterns.md, principles.md, data-model.md, stack.md, .sdd/features/**, .sdd/bugs/**) | No changes | Pi adapter reads them as-is via the same scripts |
| **Framework data-model.md** | One addition: `Pi extension package` entity (analogous to `Hook`, `Action`, `Playbook`, `Setup brick`) | Distributable unit type the framework should describe so future work knows it exists |
| **Existing entities** ([[entity:Action]], [[entity:Playbook]], [[entity:Hook]], [[entity:Setup-brick]]) | No new fields | |
| **Relations** | None added/removed | |

**New framework entity** (added to `.sdd/data-model.md` in this commit):

> **Pi extension package** — a pi.dev distributable. Lives at `extensions/sdd-pi-extension/` in this repo, published to npm as `sdd-pi-adapter`. Has a `package.json#pi` manifest declaring `extensions:` and `prompts:` paths. The TypeScript extension file at `src/sdd-pi.ts` registers handlers for pi's `context`, `session_start`, `tool_call`, and `tool_result` events plus instant slash-commands via `pi.registerCommand`. Auto-discovered by pi when installed via `pi install npm:sdd-pi-adapter`.

**Edge cases at the data layer (asked-and-answered):**

1. **Both Claude Code and pi.dev SDD installed in the same project.** Both adapters read the same `.sdd/` brain — no conflict. State file is shared; only the access mechanism differs.
2. **Pi `session_start` runs with existing `.pi/sdd/` content.** Per pi-gsd's HRN-01 pattern: copy missing framework files only, leave existing user-edits untouched.
3. **User installs `sdd-pi-adapter` without `pi-mcp-adapter`.** SDD methodology still works — the MCP server simply isn't reachable from pi. Soft dep, not hard.
4. **Pi.dev and Claude Code `session_start` hooks run on the same project simultaneously.** Each writes to its own harness dir (`.claude/` vs `.pi/`); the shared `.sdd/` brain isn't touched by session-start. No race.

**Approved by Sam: 2026-05-08.** Hash recorded in decisions.md audit trail (verification.json deferred to phase-advance time per the v0.8 moat convention discovered during §5).

### action: flows

- [x] flows: 2 critical flows — (1) first-time install + first SDD task (covers stories 2/3/4: Marco/Lucia/new evaluator); (2) multi-model task routing within one session (covers story 1: Sam's per-task model switching). Visual diagram deferred to §13 Wireframe per non-UI visualisation rule.

**Flows (2 critical, mapped to user stories):**

### Flow 1 — First-time install + first SDD task (stories 2, 3, 4)

```
1. Colleague has a project they want to SDD-ify; pi.dev installed already.
2. They run: pi install npm:sdd-pi-adapter
   → pi auto-discovers the package's #pi manifest
   → extension's session_start fires
   → copies framework `.sdd/` brain into `.pi/sdd/` via the HRN-01
     copy-on-first-run pattern (preserves any existing user files)
   → 9 slash-commands now available (/sdd-start, /sdd-next, /sdd-ship,
     /sdd-status, /sdd-compress, /sdd-skip, /sdd-bug, /sdd-idea,
     /sdd-config)
3. (Optional) They run: pi install npm:pi-mcp-adapter
   → adds `.pi/mcp.json` config so SDD's MCP server is reachable
   → without this, slash-commands still work; only MCP-flavored state
     queries become unreachable (soft dep)
4. They open pi.dev in their project, switch model with /model:
   → pick claude-sonnet-4-6, gpt-5, kimi-k2-instruct, llama-4-maverick,
     ollama:custom, or any of pi's 15+ providers
5. They type: /sdd-start build a waitlist landing page
   → prompt template loads, pi calls bash .sdd/scripts/start.sh "..."
   → scaffolds .sdd/features/001-build-a-waitlist-landing-page/spec.md
   → updates INDEX.md, prints "Run /sdd-next to continue"
6. They type: /sdd-next
   → pi.on("context") hook injects current SDD state
     (INDEX.md, active spec.md, principles.md, stack.md, data-model.md,
     patterns.md — same content the Claude Code UserPromptSubmit hook
     injects today)
   → model reads §1.who prompt, asks the user "Who has this problem?"
   → user answers, model commits as `[SDD:001] spec: problem/who`
7. Walk continues identically to Claude Code — same actions, same
   atomic-step rule, same anti-theatre lint, same pre-commit chain
   (running through git pre-commit hooks now, not pi's tool_call event).
```

**What's the same as Claude Code:** slash command surface, action prose, framework scripts, commit shape, safety rails — all reused from `.sdd/`.

**What's different:** the model is whatever pi has selected (`/model`); the harness dir is `.pi/sdd/` (not `.claude/`); the slash-command prefix is `sdd-` (pi convention; Claude Code uses bare `/start /next /ship`). User experience matches what they'd get on Claude Code in spirit; the surface details differ at the harness boundary.

### Flow 2 — Multi-model task routing within one session (story 1)

```
1. Sam is in pi.dev, mid-feature on an SDD work item.
2. He's about to do a heavy codebase exploration step (research recon
   — lots of file reads, big context, low reasoning demand).
3. He runs: /model
   → pi shows model picker; Sam selects a cheaper/larger-context model
     (haiku-3-5, kimi-k2, etc.)
4. He runs: /sdd-next
   → pi.on("context") hook injects state same as before
   → cheap model does the recon, returns synthesis
   → atomic-step commit lands as `[SDD:NNN] spec: <action>/<step>`
5. Next sub-step is a BUILD-TASK code step (needs reasoning quality).
6. Sam runs: /model again
   → switches back to claude-sonnet-4-6, opus-4, or gpt-5
   → continues with /sdd-next
7. The session is one continuous SDD flow; only the LLM behind it
   changes per task.
```

**Net for Sam:** pay Claude prices only on steps that need Claude-quality reasoning. Cheaper models for everything else. Same SDD discipline applied throughout.

**What enables this:** pi.dev's native `/model` command + the fact that SDD's action prose is model-agnostic (the discipline test passed 2/2 today across GPT-5.5 and Kimi K2, confirming the rules travel cleanly across model families).

### Out of scope for §7 (handled elsewhere)

- **Visual flow diagram** (boxes-and-arrows showing pi.dev → extension → SDD scripts → state files) → §13 Wireframe per the non-UI visualisation rule.
- **Adapter update flow** (using existing `sdd-migrate.sh` to refresh the framework brain in `.pi/sdd/`) → not a critical-path user flow; documented in the README at SHIP time.

**Approved by Sam: 2026-05-08.**

### action: dependencies

- [x] deps: zero new framework-borne service costs. Pi.dev (free, MIT), pi-mcp-adapter (free, MIT, optional), npm (free), GitHub Actions (free for public repo), TypeScript+tsup+vitest (all free toolchain). LLM costs borne by user; pi.dev supports OAuth subscription login (Claude Pro/Max, ChatGPT Plus/Pro, GitHub Copilot) AND API keys, so colleagues can use existing subscriptions without provisioning new keys.

**Dependencies — external services (zero new framework-borne cost):**

| Dependency | What it is | Cost to us | Cost to user | Risk |
|---|---|---|---|---|
| **pi.dev** (`@mariozechner/pi-coding-agent`) | The host CLI our extension plugs into | Free (MIT) | Free | Pre-1.0 — API may shift; we follow pi's version closely (pi-gsd does the same) |
| **pi-mcp-adapter** | Community MCP bridge; SDD's MCP server reachable from pi | Free (MIT, 599 stars) | Free | Optional; if abandoned, document fallback (skip MCP) |
| **npm registry** | Distribution path — we publish `sdd-pi-adapter` | Free (public package) | Free (public install) | Low — npm is mature infrastructure |
| **GitHub Actions** | Workflow that auto-publishes the npm package on release tag | Free for public repo (already used by SDD) | N/A | Low — already a SDD dep |
| **TypeScript + tsup + vitest** | Build + test toolchain (matches pi.dev / pi-gsd stack) | Free | Free | Low — standard, widely-used |

**LLM costs (borne by user, not framework) — pi.dev supports two auth modes:**

| Model family | Auth via OAuth subscription (`/login`) | Auth via API key | Notes |
|---|---|---|---|
| **Anthropic** (Claude Sonnet/Opus/Haiku) | ✅ Claude Pro/Max | ✅ ANTHROPIC_API_KEY | Same as Claude Code today |
| **OpenAI** (GPT-5, GPT-4) | ✅ ChatGPT Plus/Pro | ✅ OPENAI_API_KEY | New for SDD users |
| **GitHub Copilot** | ✅ Copilot subscription | (subscription only) | Pi.dev bonus — free for SDD users who already have Copilot |
| **Google** (Gemini Pro/Flash) | ❌ (not documented) | ✅ Google API key (Gemini or Vertex) | New for SDD users |
| **Open-weight** (Kimi K2, Llama, DeepSeek) | ❌ | ✅ Provider-specific keys (OpenRouter, Bedrock) or local Ollama | New for SDD users |

**Important UX implication:** colleagues with existing **Claude Pro/Max, ChatGPT Plus/Pro, or Copilot subscriptions can run SDD-on-pi without provisioning a separate API key.** They run `/login`, pick their provider, and authenticate via the subscription they already pay for. Lowers the install friction for stories 2/3/4 substantially.

**Pricing math scaled to success-volume targets — N/A.**

Per §2's bridge to §11, success is mechanical (every §11 AC passes on both harnesses). There's no volume target to scale pricing math against. The framework adds zero cost-per-use; user LLM costs are unchanged from "whatever the user pays today running their model directly." If anything, SDD-on-pi's `/model` switching helps users pay LESS by routing cheap-tasks to cheap models.

(Speculative pricing figures intentionally omitted — costs vary too widely by model and usage to commit to a number that means anything. Same anti-theatre discipline applied across SDD specs.)

**Approved by Sam: 2026-05-08.**

### action: out-of-scope

- [x] list: 5 explicit deferrals — parallel waves (idea 002), specialised subagents (idea 003), §2 removal (idea 004), other-CLI adapters, CI publish-workflow refinements
- [ ] approval: user_approves

**Out of scope for feature 008 — 5 explicit deferrals:**

1. **Parallel wave execution** ([[ideas/002-parallel-wave-execution]]) — separate feature after 008 ships. Most useful when paired with multi-model + subagents; building parallel waves before the basic adapter exists is premature.
2. **Specialised subagents** (researcher / executor / verifier role-splitting, [[ideas/003-specialized-subagents]]) — separate feature. Same dependency story: subagents pay off most once multi-model is real.
3. **Removing §2 Success from the feature playbook** ([[ideas/004-remove-success-from-feature-playbook]]) — separate framework feature, not part of 008. Captured live during 008's §2 walkthrough; will get its own SPEC → BUILD → SHIP cycle.
4. **Adapters for other CLIs** (Cursor, Aider, Windsurf, Codex direct) — pi.dev already reaches 15+ model providers via one adapter, so these aren't blocking. Future case-by-case work if specific demand surfaces.
5. **CI publish-workflow refinements** (changesets, semver automation, conventional-commits parsing) — start with a simple tag-based npm publish in 008; refine if friction surfaces. Pillar 1 (Simplicity) — don't add tooling complexity until it earns its keep.

Plus one already-handled-elsewhere (not in §9 list because it has its own home):

- **Visual flow diagram** (boxes-and-arrows pi.dev → extension → SDD scripts → state files) — deferred to §13 Wireframe per the non-UI visualisation rule.

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
