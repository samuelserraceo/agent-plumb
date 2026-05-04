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
