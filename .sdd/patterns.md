# SDD framework — patterns

> Cross-feature lessons learned while building the framework itself. One block per landed feature. Auto-appended by the `learn` action's `learn-lessons` step at SHIP time.

> **Bootstrap note (2026-04-29):** the framework dogfooding starts here. v0.7.5 → v0.13.6 shipped via ad-hoc PRs without SDD ceremony, so they're not in this file — the lessons-learned for those are scattered across PR descriptions, tagged release notes, and the walkthrough HTML's body cards. From v1.0 Phase B onwards (item 6, #42, and after), every shipped feature lands a block here.

<!-- Append future entries below this line; do not edit existing entries. -->

## [[001-tier-3-llm-driven-synthesis]] — v1.1 (shipped 2026-05-01)

First SDD-ceremony work-item the framework ran on itself. Six load-bearing lessons surfaced; each is a v1.2+ candidate or doctrine-improvement applied immediately.

### Anti-theatre is a layer of foundation 3, not just a one-liner

Sam caught `cost_limit_usd: 0.50` as theatre — looked like a circuit breaker but the framework can't price external services without a per-provider table or live ledger. Generalised: **every numerical / enforcement / quality claim in a spec must declare its verification path or be softened**. Filed as [#111](https://github.com/samuelserraceo/spec-driven-dev-workflow/issues/111). Three layered fixes proposed: extend Plan-decompose coverage check, new `pre-commit-no-theatre.sh` hook, doctrine update in CLAUDE.md.

Source: [[001-tier-3-llm-driven-synthesis]] §5 / §6 / §11 (re-approved twice for theatre fixes during the SPEC walk).

### Framework-shipped action prose drifts technical even when CLAUDE.md says plain-English

Caught four times in one session. The agent reads action files in `templates/.sdd/actions/<slug>.md` and inherits their wording. CLAUDE.md says translate-on-first-use, but the action prose itself doesn't lead by example, so the agent drifts. Filed as [#110](https://github.com/samuelserraceo/spec-driven-dev-workflow/issues/110). Fix: rewrite all action prompts in plain English with concrete "what it looks like" examples.

Source: [[001-tier-3-llm-driven-synthesis]] §4 / §8 / §11 / §12 (each got pushed back on for technical drift).

### Wireframe action needs major redesign — non-UI features still need visualisation

Tier 3 has no UI. The current wireframe action defaults to `[SKIPPABLE: non-UI features]`. That's wrong: backend / library / CLI features need MORE visualisation than UI features (flow diagrams + architecture diagrams + example walkthroughs), not less. Also: the framework needs a global walkthrough that **compounds** at every `/ship`. Filed as [#112](https://github.com/samuelserraceo/spec-driven-dev-workflow/issues/112). Tier 3 dogfooded the redesigned shape — `wireframe.html` has chat examples + flow + architecture + new-vs-existing.

Source: [[001-tier-3-llm-driven-synthesis]] §13 wireframe.

### Default to full-autonomous BUILD for non-technical users — not checkpoint-every-N

The framework's existing run-mode-chosen prompt recommends "checkpoint every 5" as default. For a non-technical user who can't eye-check code between tasks, that's friction without value. The right default is **full autonomous** — the agent loops until done OR a hard halt-trigger fires. Saved as `feedback_full_autonomous_build.md` in memory.

Source: [[001-tier-3-llm-driven-synthesis]] §14 plan-decompose run-mode pre-note.

### Ask for project-specific defaults before drafting (different failure mode from anti-theatre)

I drafted "user-configured provider — OpenAI / Anthropic / Ollama" across §5/§6/§8/§11 when the project's actual scope per the existing PRD was Ollama+Gemma only. Pattern-matching to existing v1.0 conventions (`semantic_search` is provider-agnostic) leaked into the new spec. Generalised: **before drafting any AGENT-LED proposal that involves a project-specific choice (provider, vendor, library, default value, scope), ASK Sam first** — don't reach for generic best-practice. Saved as `feedback_ask_for_project_defaults.md`.

Source: [[001-tier-3-llm-driven-synthesis]] §5 / §6 / §8 / §11 (Ollama+Gemma scope correction sweep).

### Future installs need setup help (v1.2+ work-item)

The wizard today asks Tier 3 sub-questions but doesn't HELP install Ollama / pull the model / set up SSH tunnels. Sam called this out: when new users install the plugin (or when SDD goes public), they need guided setup, not just question-asking. Saved as `feedback_setup_help_v12.md`. Connects to per-machine vs per-project config layering — a v1.2+ work-item should add per-machine config + provider-detection + plain-English error recovery.

Source: [[001-tier-3-llm-driven-synthesis]] T24 + T25 walk.

Source: [[001-tier-3-llm-driven-synthesis]]

### git stash pop --index doesn't survive new files

When a pre-commit hook stashes staged code via `git stash push -- <files>` and at least one of those files is NEW (added but not yet committed at HEAD), `git stash pop --index` refuses with a conflict and leaves the stash in place. The robust pattern for this kind of hook: `git stash pop` (working-tree only) followed by `git add -- "$_f"` for each path. The pop brings working-tree back, the explicit re-stage rebuilds the index. Caught dogfooding feature 006 T01 — the very first commit silently landed only the new files because `pop` (without `--index`) leaves modifications in the working tree but not the index.

Source: [[006-test-first-mechanical-check-verify-red-before-green]] T01 follow-up.

### Anti-theatre lint trips on common stub words

The `refuses?` / `enforces?` / `prevents?` / `ensures?` / `guarantees?` / `always` / `never` / `correctly` / `accurate` / `reliable` / `complete` token list catches innocuous spec prose if you're not careful. "BUILD complete" trips it; "BUILD done" doesn't. "blocks the commit" trips on `blocks` (not currently — but the verb sense is similar). Past-tense forms (`refused`, `blocked`, `completed`) pass because the regex is `refuses?` not `refus(e|ed|al)`. When marking a step `[x]`, prefer past-tense action verbs ("landed", "drafted", "blocked") over absolute-tense ("blocks", "refuses", "completes").

Source: [[006-test-first-mechanical-check-verify-red-before-green]] §13/§15 + multiple BUILD task commits.

### A hook that stashes its own staged file still works

Counterintuitively: when pre-commit-test-first.sh fires on the very commit that introduces it (T01 self-host), the hook's bash process is already loaded into memory. The hook then `git stash push`es itself — the file vanishes from disk, but the running bash continues executing the in-memory copy. eval "$test_runner" runs; tests/task-001.sh executes against the OLD HEAD content (no hook present); the test legitimately fails (real test-first); trap pops the stash; commit lands. The dogfood loop is recursive but stable as long as bash doesn't re-read the script mid-execution.

Source: [[006-test-first-mechanical-check-verify-red-before-green]] T01.

### Self-referential CI claims need an exemption

Any audit-style claim that runs on PR CI and asserts "shipped X is in state Y" must exempt the very PR being CI'd from the check — otherwise the PR's own mark-shipped row references a still-OPEN PR, the claim fails, CI is red, and merge is needed-but-blocked by CI. Caught in feature 006 / PR #153 (first PR after the claims-audit harness landed). Fix shape: read `$GITHUB_REF` (matches `refs/pull/<num>/merge` on PR runs), extract the number, and skip that entry during iteration. See `claim_shipped_pr_links_merged` in `test/run-claims-audit.sh`.

Source: [[003-claims-audit-fails-on-shipped-pr-self-reference-chicken-egg]] T01.

### Channel A vs Channel B framework updates need different tools

A SDD-style framework that ships both as a Claude Code plugin (slash commands, hooks) AND as a project-installed tree (`.sdd/`) has TWO update channels with different semantics. Channel A (plugin layer) auto-flows when users run `/plugin update` — single replacement, no user data at risk. Channel B (project-template layer) does NOT auto-flow because the user's `.sdd/` contains their own project data (spec.md, INDEX.md, decisions.md, patterns.md) that can't be auto-replaced. Without a migration tool for Channel B, downstream teams stay on whatever framework version they first installed — making the "framework dogfoods every change" claim hollow for anyone but the maintainer. Solution: ship a migration tool (`sdd-migrate.sh`) that diffs user's tracked framework files vs upstream by hash, applies non-conflicting changes, prompts on locally-edited conflicts, and re-pins the manifest. User-data files are excluded by walk-list — they're invisible to the tool, not just blacklisted. See `templates/.sdd/scripts/sdd-migrate.sh`.

Source: [[007-sdd-migrate-refresh-project-s-sdd-tree-from-upstream-framework]] feature ship.

### Wizard-records-but-install-side-effect-fires anti-pattern

A common framework anti-pattern: the wizard records the user's intent in some config file (e.g. `mcp.enabled: true`), but the install action that actually wires the feature into the project (`enable.sh`, dropping `.mcp.json`, registering with the host CLI) never fires. The user is convinced the feature is on; the agent never gets the tool calls; nobody notices until someone audits the transcript and sees zero `mcp__*` invocations. Discovered concurrently in two parallel flows: Claude Code's `/sdd-setup` brick 007 (#209 — `mcp.enabled:true` recorded but `enable.sh` never run) and pi.dev's MCP integration (F008 AC10 — manifest expects MCP but `.pi/mcp.json` not written). Same shape, both harnesses. Lesson: every wizard answer that triggers an install side-effect should verify the side-effect fired, ideally by writing a sentinel file the agent or audit can later check. Don't trust "config says yes" as proof — make the install act, then assert.

Source: [[008-build-the-sdd-on-pi-extension-package]] T209 + parallel-session #209.

### Worktree-scoped git config can override local config silently

Git's `extensions.worktreeConfig=true` enables per-worktree config files at `.git/worktrees/<name>/config.worktree`. These take higher precedence than local config. So `git config core.hooksPath .claude/hooks` from a worktree silently writes to `.git/config` (local), but the worktree-scoped value (often pointing at the main repo's absolute path) keeps winning. The naïve `git config core.hooksPath ...` looks like it succeeded but doesn't actually change behaviour. Discovered live during F008's `/start` when SDD's own pre-commit hooks couldn't fire from the worktree. Fix shape: install/init scripts should check `git config --get extensions.worktreeConfig` first — if true, use `git config --worktree core.hooksPath .claude/hooks` instead. Documented as F008 EC#4; T210 wired the check into `session-start.sh`.

Source: [[008-build-the-sdd-on-pi-extension-package]] §15 ec-pick + T210.

### Scaffold templates need to satisfy their own ship-time validators

The framework's own `/start` scaffold emitted exit-checks lines (`C-spec-acs: ≥1 acceptance criterion exists in §11`) that lacked the `{verify-by: verify-stage.sh}` annotation the anti-theatre lint expects. Result: every freshly-scaffolded feature traps on its first commit, until the user (or agent) hand-patches the missing annotation. The scaffold and the validators drift in lockstep — additions to one don't update the other. Lesson: the scaffold itself is a feature with its own AC, and its AC is "every line emitted passes every shipping lint and moat check." When you tighten a lint, run it against the scaffold's output. When you change the scaffold, re-run shipping lints against a freshly-scaffolded feature. Caught + filed as a separate fix-task during F008 SPEC.

Source: [[008-build-the-sdd-on-pi-extension-package]] /start scaffold trip + spawn_task fix.

### Framework-self-modification needs the four-step dance

When SDD itself modifies its own sealed framework script (e.g. `.sdd/scripts/next-action.sh` during F010 to add WAVE-DISPATCH parsing), a single edit isn't enough. Four files must change atomically: (1) the live script `.sdd/scripts/<name>.sh`, (2) the template copy `templates/.sdd/scripts/<name>.sh`, (3) the live manifest pin `.sdd/.cache/manifest.json`, (4) the template manifest pin `templates/.sdd/.cache/manifest.json`. Plus the commit message MUST include `[SDD] manifest: repin — <reason>` so `pre-commit-stage-verified.sh` allows the hash change. Missing any of the four breaks something: missing (1)/(2) breaks T120 self-host drift; missing (3) blocks the commit itself; missing (4) breaks every framework test that builds a fixture via `mkproj_v08` (which copies from `templates/`); missing the commit marker blocks every commit going forward. When a feature like F010 modifies a framework script across multiple BUILD tasks, the dance fires N times. Worth a future shortcut: a `bash .sdd/scripts/repin.sh <path>` helper that performs all four steps + emits the marker for inclusion in the commit message.

Source: [[010-parallel-wave-execution]] T200 + T201 + T205-T207 BUILD walk (F010 itself was the first feature to dogfood this at scale).

### macOS bash 3.2 heredoc-with-single-quoted-delimiter still counts apostrophes

The bash 3.2 that ships with macOS (and is the default `/bin/bash`) has a quirk: even when you open a heredoc with `<<'DELIM'` (single-quoted delimiter, which per POSIX should treat the body as literal with no expansion), bash 3.2's quote-state machine still counts apostrophes inside the body. A single `'` in a comment (e.g. `# subagent inherits orchestrator's model`) confuses the parser at file-load time, producing "unexpected EOF while looking for matching `''" at a line FAR from the actual heredoc. Caught during F010 T205 + T207 code commits. Workaround: avoid apostrophes in comments inside heredoc bodies (use "the X" not "X's"). Doesn't affect modern bash (4+) or the heredoc body's actual semantics — just bash 3.2's lexer pre-pass.

Source: [[010-parallel-wave-execution]] T205 code commit syntax-error rabbit hole.

### Wave-tasks must not touch spec.md — orchestrator owns spec.md edits

Original §6 EC#9 of F010 claimed wave-task subagents could each flip their own row in spec.md, with adjacent row diff context handled by git's 3-way merge. T203 empirically refuted this: even when each wave-task changes a different `[ ] T-NNN` row, git's default 3-line diff context overlaps between adjacent task rows, so concurrent flips conflict. The cleaner model that landed: wave-task subagents commit ONLY their own test + code files (disjoint sets — no two subagents share a file). The orchestrator commits ONE spec.md edit after the wave returns that flips every wave-task row to GREEN at once. Git sees one spec.md edit per wave instead of N concurrent ones. No merge needed at the spec.md layer. Lesson: when claiming "row isolation," verify the claim empirically against the actual diff/merge tool. The architectural correction simplified the data contract too — no `Wave` entity, no special merge driver, just a discipline rule on what each layer is allowed to touch.

Source: [[010-parallel-wave-execution]] T203 BUILD walk.

### Slow project test_runner forces Ralph timeout bump for framework-self-mod features

When a feature modifies sealed framework scripts (like F010 modifying next-action.sh + dispatch-wave.sh), every code commit triggers `pre-commit-test-first.sh` which stashes the code and runs the full project test_runner (`bash test/run-framework-test.sh` ≈ 5 minutes for 218 framework tests). Ralph's stock `timeout_per_iter: 600` (10 min) can't absorb 5 min pre-commit + Claude's actual work + the manifest-repin dance + potential template sync — the iteration times out before commit lands. Bump `parameters.ralph.timeout_per_iter` to `1800` (30 min) for the duration of framework-modifying features; revert to 600 for non-framework features. The pre-commit cost itself isn't fixable without a faster test_runner or hook scope tightening (e.g., only run tests that match staged paths), both of which are separate framework features. Caught during F010 BUILD when Ralph's iteration 1 timed out before T200 landed.

Source: [[010-parallel-wave-execution]] BUILD timeout investigation + config.md bump.

## Cross-branch merge of v1.6.0 entries (2026-05-11 cleanup)

The lessons below + preserved-artifact lines were appended to `.sdd/patterns.md` on origin/main between PRs #218 and #226 (v1.6.0 ship cycle). They re-appear at the bottom rather than in chronological position because the append-only contract on this file requires byte-prefix immutability for the F010 lessons committed at the top of this block. Same pattern Sam used for the decisions.md merge cleanup (see decisions.md L506 / feature/cleanup-residual-marker). The merge commit itself was constructed via `git commit-tree` plumbing (Sam-authorized) because the cofile-block hook lacks a merge-commit exemption (issue #220).

claude/clever-herschel-af8c27
### Behavioural triggers belong in CLAUDE.md doctrine, not in discrete loops

When SDD ships a behavioural rule the agent should apply at certain moments (e.g. "after pushing, run background work"), the load-bearing trigger is the agent reading CLAUDE.md at session start and applying the doctrine — NOT a separate poll loop, hook, or daemon. Caught dogfooding feature 008 §5: I specified "the CR-poll loop calls background-while-waiting.sh" — but the framework has no CR-poll loop, because the agent itself is the poller (it's session-based, not long-running). The fix was to scope the behaviour to the agent's existing post-push pattern via CLAUDE.md doctrine + an idempotent emit script the agent calls — no new infrastructure. The lesson: when SPEC §5 names a "loop" or "service" inside the framework, ASK whether that primitive actually exists before designing on top of it. The brief-builder's terminology drill (e.g. "what does CR-poll loop mean concretely?") catches this earlier.

Source: [[008-background-while-waiting]] §5 / §14 T4 re-scope during BUILD.
=======
main
