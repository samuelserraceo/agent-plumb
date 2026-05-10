# SDD framework — INDEX

**Active:** _(none)_
**Playbook:** feature
**Active blocker:** _(no active feature — v1.6 anchor (#207) fully shipped 2026-05-10/11 across PR-A (#219, brief-driven SPEC entry) + PR-B (#222, §2 cleanup) + PR-C (#223, requires_user_approval matrix lock) + PR-D (#224, plain-English-first doctrine), plus same-day F008 pi-adapter (#214) and 009-background-while-waiting (#218); tagged `v1.6.0`. Pick next: v1.7 work — possibilities include #220 hook merge-commit exception, #217 `/start` ID collision, or a feature from ## Ideas below.)_

> The SDD framework dogfooding itself. Every v1.0 item below is a real GitHub issue tracked under [milestone v1.0](https://github.com/samuelserraceo/spec-driven-dev-workflow/milestone/8). When an item is in flight, it gets a `.sdd/features/<NNN>-<slug>/spec.md` walked through the SPEC → BUILD → SHIP loop.


## In flight

(none)


## Ideas

- ideas/001-brief-builder-prefills-spec — brief from `/write-brief` plugin pre-fills SPEC §0; SDD grills only the gaps + audits against project corpus — captured 2026-05-10
- ideas/002-lego-style-model-right-sizing — each step declares thinking/routine/mechanical tier; framework picks model per tier; works for Claude-only + pi.dev — captured 2026-05-10
- ideas/003-prompt-caching-across-turns — order prompt so stable corpus comes first, variable turn comes last; provider cache picks up the prefix — captured 2026-05-10
- ideas/004-background-while-waiting — fill CR/CI deadtime with next-safe-thing (most isolated speed lever, lowest collision risk) — captured 2026-05-10
- ideas/005-auto-advance-agent-led-steps — default `requires_user_approval` false; setup-time automation-level toggle; extends BUILD-autonomy across SPEC/SHIP — captured 2026-05-10
- ideas/006-plain-english-sweep-sdd-prose — survey + rewrite SDD's user-facing prose to match brief-builder v0.4's plain-English bar (jargon → notes-from-a-colleague tone) — captured 2026-05-10
- ideas/007-cross-branch-feature-id-collision — three SDD rules (append-only / cofile-block / wiki-link resolution) collide on git merges when two branches both scaffold the same feature ID — captured 2026-05-10


## Shipped

- **[[009-feature-playbook-v2-brief-driven-spec-entry-replaces-3-question-pitch-shape]]** — closes the F01/pipelogic_v2 audit's SPEC-ceremony pain (4 failure modes — startup-pitch §1, redundant §2, lazy first-pass record, bundled-question turns) by replacing the 3-question Pitch (`who / why-now / what-breaks`) with a brief-paste flow as the feature playbook's first action. Ships new `brief-intake` action + `brief-summarise` skeleton (paste a brief / upload a doc / use the v2 template; agent grills, summarises, pre-fills §1, §3, §6, §7, §8, §10 — 6 sections instead of ~20 follow-up questions). `success.md` marked `deprecated: true` and removed from `feature.md` SPEC actions list (§2 Success folds into §11 ACs); `success.md` retained for backward-compat with in-flight features whose spec.md scaffolded pre-PR-A. `CLAUDE.md` gains "One question per turn" doctrine (closes #207 Part 3) + `lint-action-prose.sh` heuristic warning on bundled-question example blocks. `proposed-approach.md` updated as the representative AGENT-LED action with `<details>` foldable for technical detail (plain-English-first default). `data-contract.md` adds upload-invitation prose. **3 CR review cycles** (24 of 25 actionable findings closed; #11 declined per byte-prefix append-only contract on `decisions.md` — same precedent as F008 (#214) MD022 deferral; filed as #220 for v1.7 hook merge-commit exception). **4 cosmetic §-level re-approvals** preserving audit trail (§5 + §7 + §12 + §14, all logged in `decisions.md`). 6/6 CI checks GREEN; 11 BUILD tasks T01-T11 + integration smoke `tests/integration/v1.6-anchor.smoke.sh` GREEN.
  - Shipped: 2026-05-10 · PR: https://github.com/samuelserraceo/spec-driven-dev-workflow/pull/219 · Tag: `v1.6-anchor-pr-a`
  - Data-model: (none — framework-prose-only redesign; no entity changes)
  - Extends: (root); first of 4 sub-PRs in v1.6 anchor (#207). PR-B (#222, §2 doctrine cleanup), PR-C (#223, `requires_user_approval` matrix regression-lock), PR-D (#224, plain-English-first doctrine + canonical `<details>` in `data-contract.md`) all shipped 2026-05-10/11; full v1.6 anchor tagged as `v1.6.0`.
  - Patterns: cosmetic re-approval pattern proven (4 §-level hash bumps + decisions.md audit entries handled cleanly across 3 CR cycles); cofile-block CLAIM/POLICY split forced 2-commit cadence per CR cycle.
  - Deferred: same MD022 blank-line cosmetic on F009's first cosmetic-fix entry (#220 v1.7 fix); CR cycle-3 #11 chronological misorder of decisions.md entries from the merge bypass in `dae7758` (Sam-authorized git-commit-tree plumbing — preserves byte-prefix append-only; reorder would break it).

- **[[009-background-while-waiting]]** — closes the agent-idle gap during CR/CI wait windows. Ships `.sdd/scripts/background-while-waiting.sh` (emit + `--list-candidates` + `--update-last-action`) + `.sdd/scripts/background-metric.sh` helper + "Background while waiting" doctrine section in `templates/CLAUDE.md`. Agent reads doctrine post-push, picks from the safe-set (re-read corpus, pre-fetch next-feature context, draft PR description, draft commit msgs), declares the chosen action via `--update-last-action`. Marker log at `.sdd/.cache/background-emit.log` (JSONL, gitignored) is the §2 metric counter. Cross-process locking via mkdir-as-lockdir (portable, no flock dep). Originally scaffolded as feature 008; renamed to 009 mid-PR to resolve ID collision with merged 008-pi-adapter (PR #214). 9 CR review cycles (~17 unique findings closed; 2 hash-locked sections re-approved twice for AC + metric-consistency fixes). 218/218 framework + 7/7 per-feature tests GREEN.
  - Shipped: 2026-05-10 · PR: https://github.com/samuelserraceo/spec-driven-dev-workflow/pull/218
  - Data-model: (none — single new internal telemetry log, gitignored)
  - Extends: (root); ships idea 004 from the speed-improvements brainstorm captured the same day
  - Patterns: 1 lesson appended ("Behavioural triggers belong in CLAUDE.md doctrine, not in discrete loops" — from T4 re-scope during BUILD)
  - Deferred: cross-branch ID-collision pattern (idea 007) — surfaced by this PR's two folder renames (008→009 mid-PR after collision with origin's pi-adapter, then 009 number collision with #219's brief-driven feature). Filed as idea 007 for future framework work.

- **[[008-build-the-sdd-on-pi-extension-package]]** — closes SDD's "Claude Code only" lock by shipping `sdd-pi-adapter`, a pi.dev extension that brings SDD's spec-driven workflow to any model behind pi's harness (15+ providers: Anthropic, OpenAI, Google, Ollama, Bedrock, Groq, xAI, OpenRouter, etc.). Same `/sdd-start /sdd-next /sdd-ship` loop, same atomic-step-per-commit discipline, same anti-theatre lint, same trust-boundary state injection — running on whatever model the user picks via pi's `/model` command. Hand-written CommonJS extension at `extensions/sdd-pi-extension/dist/sdd-pi.js` registers three pi lifecycle handlers: `pi.on("context")` for state injection (AC3), `pi.on("session_start")` for HRN-01 install + worktree-config check (AC4), `pi.registerCommand("sdd-status")` for instant zero-LLM status (AC7). Validated by 2/2 single-turn discipline test (GPT-5.5 + Kimi K2) before BUILD, then by 13/13 mechanical AC tests (T200-T212) at SHIP. T212 added mid-SHIP after partial e2e surfaced that manifest declared `dist/sdd-pi.js` but no such file existed — closed via test → code → green. 3 CR review cycles (24/25 findings closed; C2-4 MD022 deferred — append-only contract on decisions.md blocks blank-line edits to historical entries). 218/218 framework + 13/13 per-feature GREEN.
  - Shipped: 2026-05-10 · PR: https://github.com/samuelserraceo/spec-driven-dev-workflow/pull/214
  - Data-model: [[entity:pi-extension-package]] (added — new framework-level distributable unit)
  - Extends: (root)
  - Patterns: 3 lessons appended (wizard-records-but-install-side-effect-fires anti-pattern — parallel with #209; worktree-scoped git config can override local config silently — EC#4; scaffold templates need to satisfy their own ship-time validators).
  - Deferred: scaffold-fix follow-up filed as separate task (the `/start` template emits `≥1 AC exists`-style exit checks without `{verify-by:}` annotation, tripping anti-theatre lint on every freshly-scaffolded feature); MD022 blank-line cosmetic on F008 decisions.md entries (append-only contract blocks the fix; cosmetic only).

- **[[007-sdd-migrate-refresh-project-s-sdd-tree-from-upstream-framework]]** — closes the load-bearing gap that prevented SDD from being a real updatable internal package. Ships `bash .sdd/scripts/sdd-migrate.sh --upstream=<path>` (dry-run by default) + `--apply` mode with per-file confirmation on conflicts. Categorises every framework-tracked file as ADD / UPDATE-CLEAN / UPDATE-CONFLICT / REMOVED via the framework's normalised SHA-256 hash. User-data files (spec.md, INDEX.md, decisions.md, patterns.md, data-model.md, stack.md, principles.md, .sdd/features/**, .sdd/bugs/**, .sdd/refactors/**, .sdd/ideas/**) are invisible to the tool by walk-list design. After --apply the manifest is re-pinned to upstream so commits stop tripping drift errors. Bash 3.2 compat (tempfile-backed prior-hash lookup; declare -A would crash on macOS). 1 CR review cycle (5 Major + 4 Minor closed: bit-for-bit hash check on AC7, apply error handling pre-manifest-repin, T161 UPDATE-CLEAN + post-apply idempotence, REMOVED-only message, MD022, decisions.md correction).
  - Shipped: 2026-05-04 · PR: https://github.com/samuelserraceo/spec-driven-dev-workflow/pull/157
  - Patterns: 1 lesson appended ("Channel A vs Channel B framework updates need different tools").
  - Deferred: managed-section auto-update for CLAUDE.md / config.md (today they go through the standard CONFLICT prompt); manifest schema extension to cover hooks/commands/skeletons (so they can become UPDATE-CLEAN when stock-prior, not always CONFLICT); auto-fetch upstream URL; --rollback flag.

- **bugs/003-claims-audit-fails-on-shipped-pr-self-reference-chicken-egg** — closes the chicken-egg surfaced by feature 006 / PR #153: `claim_shipped_pr_links_merged` in `test/run-claims-audit.sh` now reads `$GITHUB_REF` + `$GITHUB_REPOSITORY` and skips the PR currently being CI'd from the merged-state check. Without this, every shipped PR's CI failed on its own audit run (because the row in INDEX.md added by mark-shipped pointed at the still-OPEN PR), and merge needed admin override. PR #154's own CI is the meta-validation that the fix works. T159 (with negative + positive controls) covers the regression. Bug-playbook lighter SPEC: 5 sections (problem, repro, root-cause, fix, regression-test) walked in a single ceremony.
  - Shipped: 2026-05-04 · PR: https://github.com/samuelserraceo/spec-driven-dev-workflow/pull/154
  - Patterns: 1 lesson appended ("self-referential CI claims need an exemption").

- **[[006-test-first-mechanical-check-verify-red-before-green]]** — closes the SDD-identity gap surfaced in the v1.0 audit: BUILD's test-first claim was discipline-only with no mechanical check. Ships `pre-commit-test-first.sh` — a 9-AC pre-commit hook that detects staged tests/task-NNN.* + non-test code pairs, stashes the code, runs the project's test_runner via Approach A (or falls back to commit-order check via Approach B when test_runner is empty), and decides theatre-vs-real-RED based on the staged test's actual result against HEAD content (CR L248 fix). 3 review cycles closed: 1 Critical (L193 stash-pop must block), 4 behavioural Majors (L58 message detection extended to -F + COMMIT_EDITMSG via shim signature, L248 staged-test-specific check, L7783 T158 ec assertion, L24 test trap quoting). 9 per-feature tests + T150-T158 framework regression. 215/215 framework tests passing.
  - Shipped: 2026-05-04 · PR: https://github.com/samuelserraceo/spec-driven-dev-workflow/pull/153
  - Data-model: (none — single backend hook + 9 regression tests)
  - Patterns: 3 lessons appended (`git stash pop --index` doesn't survive new files; anti-theatre lint trips on common stub words; a hook that stashes its own staged file still works in memory).
  - Deferred to follow-up: L69 NUL-safe paths in hook (rare, paths-with-spaces); EC3 initial-commit-on-fresh-repo (corner case).

- **bugs/002-safety-hook-still-blocks-framework-updates-after-138-fix** — closes 3 false-positive paths in the safety hook that #138 didn't cover. Bug A: tightens the staged-manifest path regex so it doesn't match both live + template copies. Bug B: skips the per-file HEAD content check ONLY when the manifest is being repinned AND the file is staged in the same commit (closes the cross-commit attack false-positive on legitimate framework updates while still firing on real attacks). Bug D: the trust-baseline marker check defers to commit-msg whenever the message isn't readable from the cmd (no -m / -F, or stdin-backed -F -, or compound-command false-positives). Validated end-to-end by Tier 0 lego cleanup committing cleanly through the fixed hook.
  - Shipped: 2026-05-03 · PR: https://github.com/samuelserraceo/spec-driven-dev-workflow/pull/147
  - Data-model: (none — single-file hook fix + 3 new regression tests)
  - Extends: bugs/001 (#138 fix); narrow follow-up surfacing the 3 sibling bugs that #138's verification didn't catch
  - Lesson: forward-pointer to a future `[[pattern:gate-on-parsed-result-not-raw-input]]` — when an early gate decides whether a parser runs, prefer scoping the gate's regex to the same segment the parser will examine (not the raw input string). Raw-input regex false-positives on tool-prefix flags + edge cases like stdin-backed files; segment-scoped + edge-stripped regex aligns the gate with the parser's actual capabilities. Plus: when refining a guard, use existing tests (T45) to verify the refinement doesn't regress the original defence — single-condition fixes are tempting but break attack scenarios; dual-condition fixes are safer.
  - 3 CR cycles, 6 findings closed (3 → 2 → 1 → silent). 200/200 framework tests + 31/31 claims audit + relevant MCP tests.

- **bugs/001-safety-hook-blocks-legitimate-framework-updates** — moves the manifest-repin marker check from pre-commit to a new commit-msg hook so legitimate `git commit -m '[SDD] manifest: repin — ...'` from the terminal works (native git pre-commit fundamentally cannot see -m text — verified empirically). _(plain text — wiki-link form blocked by graph-cache resolver only walking `.sdd/features/`; bugs/refactors handling tracked separately)_
  - Shipped: 2026-05-03 · PR: https://github.com/samuelserraceo/spec-driven-dev-workflow/pull/144
  - Data-model: (none — adds new `templates/.claude/hooks/commit-msg`, gates existing pre-commit marker block behind `git_commit_cmd` non-empty)
  - Extends: (root); narrow follow-up to #137's framework-self-hosts-hooks
  - Lesson: forward-pointer to a future `[[pattern:hook-stage-must-match-data-availability]]` — when a hook needs to see commit message text, it must run at commit-msg time, not pre-commit. Pre-commit is for staged-content checks; commit-msg is for message-context checks.
  - Filed 2 sibling bugs surfaced during this fix's verification: Bug A (multi-manifest path regex breaks `git show`); Bug B (HEAD content check fires false-positive cross-commit-attack on every legitimate repin). Tracked as the in-flight bugs/002 follow-up. T142 regression test covers the commit-msg flow.

- **[[005-wireframe-action-redesign]]** — v1.2 wireframe action redesign: drops `[SKIPPABLE: non-UI features]`, branches on UI vs non-UI shape with two skeleton starters (`wireframe-ui.html` + `wireframe-non-ui.html`). Non-UI features now ship a flow + architecture diagram + concrete chat/CLI examples — visualisation a non-technical reviewer can read end-to-end without reading code.
  - Shipped: 2026-05-03 · PR: https://github.com/samuelserraceo/spec-driven-dev-workflow/pull/128
  - Data-model: (none — action-prose rewrite + 2 new HTML skeleton files)
  - Extends: (root)
  - Lesson: forward-pointer to a future `[[pattern:non-ui-features-need-more-visualisation-not-less]]` — the wireframe is the only doc a non-technical reviewer can read to decide *"yes, that's what I asked for"*. UI features inherit visualisation from the screens themselves; non-UI features need MORE explicit visualisation (flow + architecture diagrams + concrete examples), not less, because reviewers can't infer behaviour from code.
  - 5 CR cycles, 20 findings closed (8 → 5 → 4 → 3 → silent). 196/196 framework + 161/161 MCP + 10/10 task tests.

- **[[004-graph-cache-multi-line-code-span-fix]]** — v1.2 graph-cache multi-line code span fix: `_INLINE_CODE_MULTILINE_RE` + `_mask_inline_code_in_content()` mask CommonMark backtick spans across newlines while preserving line numbers. `_CACHE_VERSION` bumped 1 → 2 so old caches regenerate.
  - Shipped: 2026-05-02 · PR: https://github.com/samuelserraceo/spec-driven-dev-workflow/pull/124
  - Data-model: (none — single-function rewrite + new helper)
  - Extends: (root); narrow follow-up to PR #104's graph-integrity gate
  - Lesson: when a parser is line-by-line by construction, content that crosses line boundaries needs a pre-mask pass on the full content with newlines preserved (so downstream line-by-line walkers still see correct line numbers). Position-preserving masks beat content-deleting strips.
  - 3 CR cycles, 6 findings closed (4 → 1 → silent). 196/196 framework + 161/161 MCP + 4/4 task tests.

- **[[003-anti-theatre-lint]]** — v1.2 anti-theatre lint + pre-commit hook + CI gate: spec.md content can't ship sentences that LOOK like enforced guards but aren't (`cost_limit_usd: 0.50`, `enforces 1KB`, `≥80% correctly`). The lint at `lint-no-theatre.sh` refuses theatre tokens unless an adjacent `{verify-by}` / `{best-effort}` / `{prod-only}` annotation is present.
  - Shipped: 2026-05-02 · PR: https://github.com/samuelserraceo/spec-driven-dev-workflow/pull/121
  - Data-model: (none — bash lint + pre-commit hook, no new entities)
  - Extends: (root)
  - Lesson: forward-pointer to a future `[[pattern:annotated-theatre-instead-of-soft-prose]]` — Foundation 3 applied at the spec layer. Every claim either checks (`{verify-by}`), admits judgement (`{best-effort}`), or names live-infra (`{prod-only}`) — soft prose alone isn't enough.
  - 4 CR cycles, 11 findings closed (7 → 3 → 1 → silent). 196/196 framework + 15/15 task tests.

- **[[002-plain-english-prose-sweep]]** — v1.2 plain-English prose sweep + lint: every USER-LED / AGENT-LED action file ships a concrete plain-English example block (`**What it looks like:**`) the agent can mirror; `lint-action-prose.sh` catches future drift on every PR.
  - Shipped: 2026-05-02 · PR: https://github.com/samuelserraceo/spec-driven-dev-workflow/pull/118
  - Data-model: (none — markdown sweep + bash lint, no new entities)
  - Extends: (root)
  - Lesson: forward-pointer to a future `[[pattern:plain-english-mum-test-overrides-mechanical-proxies]]` — when a quality concern is human-judged ("would mum understand this?"), the lint enforces a positive concrete fact (the example block exists), not a heuristic proxy (sentence count, char count, jargon denylist). Foundation 3 applied at the lint layer.
  - 5 CR cycles, 38 findings closed (24 → 5 → 3 → 3 → 0). 195/195 framework + 10/10 task tests.

- **[[001-tier-3-llm-driven-synthesis]]** — v1.1 Tier 3 LLM-driven synthesis: chat-style answers over `.sdd/` corpus with cite-checked `[[…]]` citations.
  - Shipped: 2026-05-01 · PR: https://github.com/samuelserraceo/spec-driven-dev-workflow/pull/114
  - Data-model: [[entity:Tier3Config]] + [[entity:SynthesisCache]] (added)
  - Extends: (root)
  - Lesson: [[pattern:anti-theatre-is-a-layer-of-foundation-3-not-just-a-one-liner]] — every numerical / enforcement / quality claim in a spec must declare its verification path or be softened
  - First SDD-ceremony work-item the framework dogfooded on itself

## Pending production verification

After Tier 3 first-prod deploy, walk these `[PROD-ONLY]` ACs manually per §12 of the [[001-tier-3-llm-driven-synthesis]] spec:

- [ ] **AC18 (T26)** — Real-provider naturalness check. Against your live Ollama+Gemma VPS, ask one of the §3 stories' questions and confirm the answer (a) passes the cite-check mechanically and (b) reads naturally to you as a human reviewer. *Naturalness is your judgment; cite-check is mechanical.*
- [ ] **AC19 (T27)** — Real-provider rate-limit response shape matches what AC#12 mocks. Manual confirmation against actual Ollama behaviour, once.

Tick each as `[x] PROD-VERIFIED` in this list once walked. If either fails in prod, file a bug task back to BUILD.

## Shipped via ad-hoc PRs (pre-self-host)

The framework's history before self-hosting. Each entry is a tagged release; full details live in `.sdd/decisions.md` and the GitHub release notes linked below.

- **v0.7.5 → v0.13.6** — 18 releases shipped via direct PRs against `main`. Tags v0.7.5 through v0.13.6, all live at https://github.com/samuelserraceo/spec-driven-dev-workflow/releases.
- **v0.13.4** — chore sweep (plain-English rewording #66 + npm install auto-run #70 + doctrine drift cleanup #73). [PR #75](https://github.com/samuelserraceo/spec-driven-dev-workflow/pull/75).
- **v0.13.5** — adversarial-review re-run wiring (closes #65). [PR #76](https://github.com/samuelserraceo/spec-driven-dev-workflow/pull/76).
- **v0.13.6** — five-PR feature pack (#69 / #67 / #68 / #72 / #71). [PRs #77–#82](https://github.com/samuelserraceo/spec-driven-dev-workflow/pulls?q=is%3Apr+is%3Amerged+v0.13.6+).

## Backlog (post-v1.0)

Tracked outside the v1.0 milestone — see open issues at https://github.com/samuelserraceo/spec-driven-dev-workflow/issues for current state.

- Cross-platform (Windows) support — bash-only is fine for v1.0.
- Anthropic plugin marketplace listing — after v1.0 ships and is dogfooded.
- Additional extension Lego bricks: Cypress, Vitest, pytest, Jest, Stripe-specific, Vercel-specific.
- Additional install walkthroughs (Resend, Sentry, Stripe, etc.) following the v0.13.6 CodeRabbit walkthrough pattern.
- User community surfaces (Discord, gallery, etc.) — after v1.0 ships.
- Dedicated security audit pass — separate hostile-reviewer pass on every script.
- Onboarding video / 5-min demo — once the walkthrough HTML is the canonical surface.

## Ideas

Cheap parking spots — no commitment to build. Promote via `/start` when one earns it.

- [`ideas/001-multi-platform-pi-adapter`](ideas/001-multi-platform-pi-adapter.md) — pi.dev adapter as second harness, unlocking GPT-5/Kimi/Llama via pi's 15+ model providers — captured 2026-05-07
- [`ideas/002-parallel-wave-execution`](ideas/002-parallel-wave-execution.md) — parallel BUILD-task waves with fresh per-wave contexts (GSD-style) — captured 2026-05-07
- [`ideas/003-specialized-subagents`](ideas/003-specialized-subagents.md) — small set of role-specialised subagents (researcher / executor / verifier) — captured 2026-05-07
- [`ideas/004-remove-success-from-feature-playbook`](ideas/004-remove-success-from-feature-playbook.md) — drop §2 Success from feature playbook, lean on §11 Acceptance Criteria as the AI-verifiable success layer — captured 2026-05-08

## How this differs from a downstream user's INDEX.md

A downstream user's `.sdd/INDEX.md` lists features they're building. This file lists the framework's OWN work items — meta, but the same shape. The framework's "features" are the issues that change `templates/`, `.github/workflows/`, `scripts/`, etc.

When the framework reads its own state via `next-action.sh`, it walks this file the same way it walks any project's INDEX.md. The framework doesn't care that the project happens to BE the framework.
