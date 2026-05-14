# External review brief — for ChatGPT (GPT-5.5)

> **Instructions to Sam:** copy everything below the `---` line into a fresh ChatGPT conversation. The brief is self-contained — GPT has the URL, the goals, and a structured evaluation rubric. If GPT can fetch from the web (web browse / Bing / Code Interpreter with `git clone`), let it explore the repo; otherwise it can reason from the framing alone and tell you where it'd want to look.

---

# Independent review request — Spec-Driven Development (SDD) framework

You are an independent technical reviewer. I built (with Claude Code) an opinionated agent-driven workflow called **SDD** — Spec-Driven Development. It's now at v1.8.3 + v1.9 patch line; ~248 framework tests, 33 claims-audit assertions, all GREEN on `main`. I want your honest external eye on it: **does it actually achieve what I set out to build, or is it ceremony pretending to be substance?**

## 1. What SDD is (in one paragraph)

A workflow for using AI to build real software without the AI making stuff up. The state file (markdown spec.md) IS the program. The playbook (markdown action files) is the questioning agent. The filesystem is the retrieval system. There's no orchestrator, no database, no embedded LLM, no SaaS — three plain ideas wired together by markdown + bash pre-commit hooks. The framework refuses commits that drift from spec; the agent literally cannot write code that doesn't trace to a verified `[ ]` step the user approved.

## 2. What I set out to achieve (the explicit goals)

From the README + CLAUDE.md, these are the stated promises. **Please grade each against the actual repo state.**

### 2a. Foundation 3 — load-bearing design pillars
1. **Simplicity over capability.** Files you can `cat`. Bash + markdown + YAML. No build step, no SaaS, no database, no `node_modules`. Deps: `bash` + `python3` + PyYAML + `git` + `gh`. *Question: did SDD honour this, or did it accumulate complexity it didn't need?*
2. **Composable Lego bricks.** Actions are atoms slot-able into any playbook. Notebooks (INDEX / decisions / patterns / data-model / stack) are separate bricks. Playbooks are compositions. *Question: do the bricks actually compose, or is there hidden coupling?*
3. **Never assume — always check.** The manifest hash never trusts a file is unchanged — it checks. The moat hook never trusts the agent's "I'm done" claim — it re-runs verification. *Question: where does the framework still assume? Find every place it shortcuts the check.*

### 2b. The 8 code-quality doctrine rules
1. Never assume — always ask
2. Conciseness is an asset
3. Don't over-engineer
4. Reuse > reinvent (use Stripe SDK, don't reinvent card validation)
5. Wireframe reflects current state (mechanically enforced)
6. No clock-time estimates (size in atomic steps / files / S-M-L)
7. Minimum diff
8. Plain English first (mum-test)

### 2c. The user promises
- The agent **literally cannot** commit code that wanders from its spec (pre-commit hooks refuse)
- The non-technical user brings the WHAT (in plain English); agent proposes the HOW (with tradeoffs you can react to)
- Every decision lands in markdown a non-coder can read 6 months later
- The "moat" hook re-runs verification on the staged file, ignoring what the agent claims
- Wrong path is **mechanically impossible**, not just discouraged

## 3. Where to look (the artifacts)

**Public repo:** https://github.com/samuelserraceo/spec-driven-dev-workflow

If you can `git clone` or browse it, key files in priority order:

| Priority | File | What to look at |
|---|---|---|
| 1 | `docs/walkthrough.html` | The full UX surface — open in a browser. Has 7 SVG diagrams + 30+ jargon tooltips. ~1900 lines self-contained. |
| 1 | `CLAUDE.md` (root) | The agent's behavioural contract. Foundation 3 + 8 doctrine rules + every hard rule. ~800 lines. |
| 1 | `README.md` | User-facing entry point. |
| 2 | `templates/.sdd/playbooks/feature.md` | The canonical 15-action playbook (SPEC → BUILD → SHIP). |
| 2 | `templates/.sdd/actions/*.md` | 26 action files — the atomic prose units. |
| 2 | `templates/.claude/hooks/pre-commit-stage-verified.sh` | THE MOAT — pre-commit hook that re-runs verification. ~1100 lines bash. |
| 3 | `test/run-framework-test.sh` | 248 mutation-verified tests. |
| 3 | `test/run-claims-audit.sh` | 33 claims a marketing-shape sentence makes → verified by execution. |
| 3 | `.sdd/decisions.md` | Append-only audit trail — every approval + phase advance since v0.1. |
| 4 | `.sdd/INDEX.md` | The project's own catalog. ~250 lines. |
| 4 | `.sdd/patterns.md` | Cross-feature lessons. |
| 4 | `.sdd/reports/2026-05-12-cross-session-audit.md` + `2026-05-14-full-final-audit.md` | Two prior internal audits — second opinions. |

If you **can't** browse, reason from the framing and tell me what you'd want to inspect to validate each claim.

## 4. The specific questions I want answered

Please respond in this structure:

### Q1. Does the framework deliver "mechanically impossible to drift"?
The README claims the agent cannot commit code that wanders from spec. Find the hooks that enforce this. Are they actually enforcing, or are they reminders dressed up as enforcers? Specifically check: (a) the moat re-runs verify-stage on staged content — does it really, or does it trust verification.json? (b) the manifest hash-pin catches edited framework files — does the marker bypass work as documented? (c) the anti-theatre lint refuses unverified claims — is the regex tight enough?

### Q2. Is the plain-English promise honoured?
Open `docs/walkthrough.html` (or `README.md`). Read 5 random paragraphs. Could a non-technical founder follow each one without a dictionary? If not, name the exact sentences that fail the mum-test.

### Q3. Is Foundation 1 (Simplicity) honoured, or did SDD become what it warned against?
Count: lines of bash, lines of python, lines of markdown, lines of HTML, number of npm packages, number of external services. Does the dep envelope match the README's claim ("bash + python3 + PyYAML + git + gh")? Anything in node_modules / package-lock.json / etc.? If you find scope creep, name it.

### Q4. Where does the framework still assume?
Foundation 3 says "Never assume — always check." Scan for any code path where the framework SHORTCUTS the check. Examples that already shipped: `start.sh` previously assumed the next feature ID by counting local folders (didn't check origin/main) — fixed in PR #231. Find the next 3-5 places this pattern still exists.

### Q5. Is the SDD discipline going to survive its first real downstream user?
This repo dogfoods itself, which is convenient. But the first downstream project (pipelogic_v2) surfaced ~6 friction points that drove v1.6 + v1.7 + v1.8 + v1.9. Imagine a second downstream user with a *different* shape — say, a Python data pipeline, not a TypeScript webapp. Where will the framework's bash + markdown + filesystem layer hurt? Name 3 concrete failure modes.

### Q6. Are the "shipped" features actually shipped?
Pick 3 features from `INDEX.md`'s `## Shipped` section at random. For each, verify: (a) the spec.md has the marker `.shipped` file in its folder, (b) the PR linked actually merged, (c) the code claimed in the spec actually exists at the paths the spec names, (d) the tests claimed (T-NNN) actually exist in `test/run-framework-test.sh`. If any of the 3 picks fails the audit, that's a structural problem.

### Q7. Goals not met (the honest verdict)
List goals from §2 above that SDD does NOT fully deliver. Each entry should name: (a) the goal, (b) the gap, (c) what would close it. No "looks good" — be specific.

### Q8. Goals MET that I shouldn't take credit for
If a goal is delivered, is it delivered by SDD's own design — or is it delivered by Claude Code's harness, by GitHub Actions, by CodeRabbit, by the user's discipline? Separate "SDD does this" from "the surrounding ecosystem does this for SDD".

### Q9. Risks for v2.0
If I were to start v2.0 tomorrow, what should I rip out, what should I double down on, and what should I leave alone? One sentence each.

## 5. Format I want back

A single markdown response, ~1500–2500 words. Plain English (Sam is non-technical). Structured by Q1–Q9 above. Concrete file paths + line numbers when citing evidence. If you can't answer a question with the artifacts you have access to, say so explicitly — don't fill the gap with educated guesses.

End with a **single-paragraph executive summary**: did SDD achieve its goals? GREEN / YELLOW / RED with one-sentence justification.

---

## Sam's notes

This brief was generated 2026-05-14, post the v1.9 ship batch. The framework is in "audit-close territory" — zero open GitHub issues, zero open PRs, v1.0 milestone 100% closed (17/17), latest tags v1.7.0-v1.8.3 + v1.9 patch line. Two prior internal audits (`.sdd/reports/2026-05-12-cross-session-audit.md` + `2026-05-14-full-final-audit.md`) both came back GREEN. **What I want from GPT is an independent external check** — not another internal sweep.

Email the response back / paste it into a fresh Claude session for a third-party comparison.
