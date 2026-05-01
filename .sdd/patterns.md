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
