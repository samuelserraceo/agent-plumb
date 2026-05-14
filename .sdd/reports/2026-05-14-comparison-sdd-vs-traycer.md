# SDD vs Traycer — head-to-head comparison

> Written 2026-05-14. Sources: docs.traycer.ai + traycer.ai/ (fetched via WebFetch) and the SDD framework's own README + CLAUDE.md + walkthrough.html.

## TL;DR

Same problem, opposite philosophy.

- **Traycer** = a polished SaaS platform you sign up for, point at your codebase, and get spec-guided AI plans for $0-$100/user/month.
- **SDD** = a free Claude Code plugin (markdown + bash + git hooks) that lives entirely in your repo, refuses commits that drift from spec, and never sends a byte off your machine.

Both call themselves "spec-driven development." Both bridge AI agents and production code. The differences are in **where state lives**, **what enforces discipline**, and **who's renting whom**.

## Side-by-side

| Dimension | **Traycer** | **SDD (this framework)** |
|---|---|---|
| **What it is** | SaaS platform at platform.traycer.ai | Claude Code plugin (open-source) — clones into `.sdd/` + `.claude/` in your repo |
| **Pricing** | Free ($5 credits) / Lite $20mo / Pro $40mo / Ultra $100mo | Free, no credits, no usage caps, no account |
| **Where state lives** | Cloud (specs, plans, verification state stored on Traycer's backend) | Local filesystem — `spec.md`, `INDEX.md`, `decisions.md`, `patterns.md` — files you can `cat` |
| **Where your code goes** | Sent to Traycer for analysis (no explicit on-device claim) | Stays on your machine. Framework never reaches a third-party server |
| **Workflow** | Plan → Execute → Verify | SPEC → BUILD → SHIP (with mechanical gates between phases) |
| **Multi-agent support** | Cursor + Claude Code + Cline + GitHub Copilot + Windsurf + custom CLI | Claude Code natively + 15+ providers via pi.dev adapter (Anthropic / OpenAI / Google / Ollama / Bedrock / Groq / xAI / OpenRouter / etc.) |
| **Enforcement** | "Implementation verification" + "gap detection" (feedback-shape) | Pre-commit hooks REFUSE commits that drift. The agent literally cannot commit code that wanders from spec. Filesystem-level mechanical gate, not feedback. |
| **Audit trail** | Not documented in their public docs | Append-only `decisions.md` ledger (every approval, every phase advance, hash-pinned to the section). Plus git history (1 atomic step = 1 commit). |
| **Lock-in** | Cloud account + credits + their proprietary plan format | Markdown files. Forever. Delete the `.sdd/` folder and you keep your repo + history. |
| **Customization** | SaaS UI / agent settings | Edit any markdown file. The agent reads CLAUDE.md every turn — change a rule, change behaviour. |
| **Setup** | Sign up, pick a plan, configure credits | `bash .sdd/scripts/init.sh` on a fresh repo. Five plain-English wizard questions. |
| **Open source** | Proprietary (no source on their site) | MIT-licensed; full source on GitHub |
| **Extensibility model** | "Plan Mode / Phase Mode / YOLO Mode" — modes you turn on | "Lego bricks" — every action / playbook / hook is a markdown file you compose |
| **Compliance posture** | SOC2 Type 2 + GDPR (cloud-grade) | None claimed (it's bash + markdown — no servers to certify) |
| **Bias on UX** | Engineer-shape docs ("agents drift," "phase orchestration") | Explicit non-technical-user lens — every term gets a plain-English translation on first use |

## Where Traycer wins

1. **Polish + discoverability.** The product is a website you can sign up for. SDD requires you to install Claude Code first, then install the plugin, then run the wizard. Traycer's onboarding is one click; SDD's is three.
2. **Multi-agent natively.** Traycer was built day-one to plug into Cursor / Cline / Copilot / Windsurf as well as Claude Code. SDD reaches the same agents but only via the pi.dev adapter (extra step).
3. **Cloud features.** Multi-user collaboration, history accessible from any device, Traycer team's models doing the planning. SDD has none of that — it's purely local.
4. **YOLO Mode (full autonomy).** Traycer's Phase Mode + YOLO is an explicit "walk away and let it run" path. SDD has the equivalent (full-autonomous BUILD mode + parallel waves) but it's documented in CLAUDE.md doctrine, not surfaced as a one-click toggle.

## Where SDD wins

1. **Free + no lock-in.** Traycer's $40-$100/user/month adds up; SDD costs $0 and the spec format is markdown you own forever. Cancel SDD, your specs still work in any text editor.
2. **Mechanical enforcement, not feedback.** Traycer's "verification" tells you if the implementation matches the plan. SDD's pre-commit hooks REFUSE the commit if it doesn't. Traycer can be ignored; SDD cannot.
3. **Code never leaves your machine.** For solo founders / regulated teams / paranoid devs, this is non-negotiable. Traycer is SaaS — your code goes to their servers for analysis.
4. **Plain-English-first design.** SDD's whole CLAUDE.md is built around "the user is non-technical." Translation on first use, common-pattern multi-choice with free-form escape, mum-test on every paragraph. Traycer's docs assume you're already an engineer.
5. **Audit trail is a git log + a markdown ledger.** Six months later, a non-coder can `cat decisions.md` and read why every choice was made. Traycer's audit trail (if it has one) lives in their cloud — you depend on them keeping it.
6. **Hash-pinned framework + manifest.** Edit a hook file in SDD without re-pinning the manifest, the moat refuses your commit. Catches accidental drift + a class of tamper attack. Traycer's docs don't mention an equivalent integrity layer.
7. **Bash + markdown + git only.** Zero `node_modules`, no daemon, no SaaS dependency. The whole framework is files you can `cat`. Disaster-recoverable from a bare clone.

## Where they overlap (genuinely the same)

- Both reject "AI builds whatever it feels like" and force a plan-then-execute loop.
- Both have an explicit verification step after implementation.
- Both work with multiple coding agents (different mechanisms; same result).
- Both target the gap between AI's eagerness and production code's precision.

## Honest verdict

| If you... | Pick |
|---|---|
| Want a polished SaaS, will pay $40/mo per user, don't mind code on someone else's servers, value team collaboration features | **Traycer** |
| Want $0 cost, zero lock-in, code that never leaves your machine, mechanical (not advisory) discipline, and a non-technical-user-first UX | **SDD** |
| Run a regulated codebase (HIPAA / FedRAMP / proprietary IP) | **SDD** (no SaaS in the loop) |
| Lead a team of 10+ engineers using Cursor + Cline + Copilot in different combos | **Traycer** today; SDD via pi.dev once that adapter is more polished |
| Are a non-technical founder who wants to build alongside the AI without learning the lingo | **SDD** (its whole reason for existing) |

## What we'd steal from Traycer if we were redesigning SDD

1. **One-click signup parity.** SDD's install is 4 steps; Traycer is 1. The marketplace plugin install (already shipped) closes most of this gap, but documentation could lead with it.
2. **"YOLO Mode" as a named first-class toggle.** SDD has full-autonomous mode + parallel waves but they're buried in CLAUDE.md. Naming + UI-surfacing the autonomy tier (the F011 work that already shipped) would match Traycer's framing.
3. **Multi-user state visualisation.** Traycer's cloud means your team sees the same plan. SDD is local-only by design — but a *read-only* web viewer over a `.sdd/` folder would be a nice optional add (still no SaaS lock-in, just a viewer).

## What Traycer would steal from SDD if they could

1. **Mechanical enforcement.** Their "verification" is an after-the-fact check; SDD's hooks refuse the commit. Cloud-based platforms can't do this without owning the entire dev environment.
2. **Filesystem-as-the-database.** No backend to maintain. Cheaper to run, infinite uptime, zero lock-in. Traycer can't deliver this without giving up the SaaS business model.
3. **Plain-English-first doctrine + mum-test enforcement.** Traycer's docs are engineer-shape; SDD's are non-technical-user-first. This isn't a feature — it's a culture choice that's harder to retrofit.

## One-paragraph executive summary

Traycer is the SaaS answer to "how do I make AI agents not drift" — polished, multi-agent, $0-$100/user/month, code goes to their cloud. SDD is the open-source answer to the same question — free, filesystem-only, mechanical hooks refuse drift at commit time, code never leaves your machine, designed for non-technical users to drive. Pick Traycer if you want a turn-key SaaS your engineering team can adopt today. Pick SDD if you want zero-lock-in mechanical discipline you own forever. They're both valid; they're solving the same problem from opposite ends of the build-vs-buy axis.
