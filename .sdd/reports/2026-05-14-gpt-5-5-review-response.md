# GPT-5.5 external review — verbatim + my digest

> Received 2026-05-14 in response to the brief at `.sdd/reports/2026-05-14-external-review-brief-for-gpt-5-5.md`. GPT-5.5 reviewed the public repo at main commit `2a395f7`. **Verdict: YELLOW.** This is a substantive critique with specific fixable findings, not a friendly nod.

---

## GPT-5.5's headline

> "SDD is real, not empty ritual, but the strongest claims are overstated. The executable claims audit passed 33/33; the full framework suite did not pass for me: 234/248, with failures around manifest/self-host drift tests. I also found one shipped feature whose spec names a file that no longer exists."

---

## The 6 actionable findings (sorted by impact)

### 1. **Anti-theatre lint is weak** (Q1, weakest of the three enforcers)

GPT got these past the lint:
- "The command must halt on drift"
- "The tool blocks unsafe changes"
- "The hook guarantees safe commits. {verify-by: totally-made-up}"

The lint catches some theatre tokens but doesn't validate that `{verify-by: T-NNN}` actually points at an executable test. **Fix shape:** extend `lint-no-theatre.sh` to grep `test/run-framework-test.sh` for the named T-ID; refuse if not found. Plus tighten the regex to catch "halts" / "blocks" / "guarantees" verb forms.

### 2. **README claim "wrong path is mechanically impossible" is overstated**

GPT's recommended rewording: *"configured SDD commits are mechanically checked."* Honest correction. The moat IS load-bearing; the claim just shouldn't promise something fail-open paths can't deliver. **Fix shape:** edit one sentence in README.md.

### 3. **5 fail-open paths in the hooks** (Q4)

Concrete, line-numbered:
- `pre-commit-stage-verified.sh:154` — moat fails open if `verify-stage.sh` is missing
- `pre-commit-stage-verified.sh:795 + 818` — section-lock coverage skips if `hash-section.sh` or `approved_sections` absent
- `pre-commit-rules.sh:261` — allows commits when PyYAML / config / frontmatter parsing fails
- `.claude/hooks/pre-commit:78` — native shim warns + continues when configured hook missing
- `pre-commit-test-first.sh:217` — passes through when stash fails

**Fix shape:** flip each to fail-closed for any initialised SDD project (detect via `.sdd/INDEX.md` presence). Migration mode = explicit env var.

### 4. **Doc drift: action count off** (Q3)

The brief I wrote said 26 actions; actual count is 44 in `templates/.sdd/actions/`. Walkthrough claims 42. **Fix shape:** add a claim to `test/run-claims-audit.sh` that grep-counts the actions and asserts agreement with the README + walkthrough. Then update both docs to the actual number.

### 5. **F007 spec names a file that doesn't exist** (Q6)

`features/007-sdd-migrate/spec.md:44` claims `templates/.claude/commands/sdd-migrate.md` exists. It doesn't. Same shape as the broken-wiki-link class but applied to spec-named code paths.

**Fix shape:** add a CI claim: for every shipped feature, every file path mentioned in spec.md must either exist OR be tagged as `{deferred}`. Catches spec lying about delivered code.

### 6. **bug-002 still says `[PHASE: SPEC]` despite being shipped** (Q6)

Audit-trail consistency smell. **Fix shape:** add a CI claim: if `.shipped` marker exists, spec.md PHASE must be `SHIPPED`. Catches stale state in the catalog.

## What GPT correctly identified as real load-bearing wins (Q8)

- The staged moat (`pre-commit-stage-verified.sh:1125-1215`) genuinely re-runs verify-stage on staged blobs
- Manifest pinning + commit-msg marker enforcement is real
- Append-only decisions ledger
- 33/33 claims-audit (mechanical, not aspirational)
- Action/playbook composable atoms

## What GPT correctly attributed to the surrounding ecosystem (not SDD's own credit)

- Git: staged blob inspection, hook timing, branches
- GitHub + gh: PR merge truth, CI status, review state
- Claude Code: PreToolUse/Stop/UserPromptSubmit hook surfaces, slash commands
- The user: discipline to not `--no-verify`, to keep `core.hooksPath`, to approve sections honestly

## Local-test discrepancy (234/248 vs 248/248)

GPT's local run reproduced the same DRIFT-TEST-MARKER leak my own audits hit. T120 / manifest-self-host tests fail when the marker leaks into `templates/.sdd/actions/problem.md` mid-run. **Already filed as a recommended hardening item in `.sdd/reports/2026-05-12-cross-session-audit.md` §7A.** GPT's run independently confirms the gap is real + happens to fresh sessions, not just mine.

## My honest reaction

GPT is right on every concrete finding. The 6 actionables above are real, bounded, and fixable in a v1.10 hardening sprint:

- **2 are docs-only** (README sentence rewording + doc-vs-actual count audit) — under 30 min total
- **3 are CI claim additions** (verify-by points at real test, spec-named files exist, .shipped → PHASE: SHIPPED) — single PR, ~1 hour
- **1 is fail-open → fail-closed conversion** across 5 hook sites — single PR, real testing required, half-day

**The big one I'd debate:** GPT recommends fail-closed across all 5 sites. Some of those (the "warn and continue when hook missing" path) are deliberate migration-friendly behaviour from when the framework was younger. Flipping them to fail-closed without a migration window could break downstream projects mid-upgrade. Recommend keeping migration mode as an explicit env-var escape hatch (`SDD_STRICT=1` or similar), default ON for new projects.

## Recommended v1.10 hardening sprint (4 items)

1. **README + walkthrough wording** — soften "mechanically impossible" to "mechanically checked"; fix action count drift. (S, ~30 min, 1 PR)
2. **Anti-theatre lint hardening** — verify-by must point at real T-ID; tighten verb regex. (S, ~1 hour, 1 PR)
3. **3 new CI claims** — verify-by-points-at-real-test + spec-named-files-exist + shipped-PHASE-consistency. (M, ~2 hours, 1 PR)
4. **Fail-closed hooks with `SDD_STRICT=1` env-var escape** — flip the 5 sites; default new projects strict, leave existing projects on old default until they opt in. (M, half-day, 1 PR + 5 new T-tests)

Total: 4 PRs, half-day-ish of focused work. Would move the verdict from YELLOW to GREEN against GPT's same rubric.

## What I'd defer to v2.0+

- Q5's "second downstream user" friction (Python pipeline, no-GitHub team) — real but needs a real second user to inform, not speculation.
- Q7's "every doc rewrite for plain-English" — sprint #3 already added jargon tooltips, which closes most of the surface; full prose rewrite is a separate book.

## Bottom line

GPT-5.5's review is **the most useful single critique we've gotten** — concrete, line-numbered, fixable, and honest about what SDD owns vs what the surrounding ecosystem owns. Earnest 6/6 actionable findings. **Recommend filing the 4 hardening items as a v1.10 sprint and circling back to GPT after they ship for a re-grade.**

---

## Appendix — GPT's full review (verbatim)

I reviewed the public repo at main commit 2a395f7. Short version: SDD is real, not empty ritual, but the strongest claims are overstated. The executable claims audit passed 33/33; the full framework suite did not pass for me: 234/248, with failures around manifest/self-host drift tests. I also found one shipped feature whose spec names a file that no longer exists.

**Q1. Does the framework deliver "mechanically impossible to drift"?**
Partly. The core moat is not theatre. pre-commit-stage-verified.sh (line 1125) reads staged spec.md with `git show ":$spec_path"`, copies it into a temp tree, reruns verify-stage.sh (line 118), then compares the fresh result against staged verification.json at line 1215. That is real staged-content verification.

Manifest pinning is also substantial. The moat detects staged framework files at lines 92-134, verifies the hash manifest, and requires a commit-message marker for repins. The native commit-msg hook separately enforces that marker at commit-msg (line 45) and commit-msg (line 168). The marker bypass exists, but it is not invisible.

The anti-theatre lint is the weakest of the three. lint-no-theatre.sh (line 69) has a useful token regex, but I could get sentences like "The command must halt on drift", "The tool blocks unsafe changes", and "The hook guarantees safe commits. {verify-by: totally-made-up}" through it. It catches some theatre, not all theatre, and it does not validate that verify-by names a real executable proof.

Verdict: the moat is an enforcer; the theatre lint is a guardrail. The README claim at README.md (line 21) should say "configured SDD commits are mechanically checked," not "wrong path is mechanically impossible."

**Q2. Is the plain-English promise honoured?**
Mixed. I could not open docs/walkthrough.html in the in-app browser because the Browser tool rejected the local file:// URL, so I audited the source directly.

Some paragraphs pass the mum-test. The "ask the human" framing around docs/walkthrough.html (line 889) is understandable.

Several fail. docs/walkthrough.html (line 1083) says "staged tests/task-NNN.* + non-test pairs, stashes code-side, runs parameters.test_runner…" That is engineer-to-engineer language. docs/walkthrough.html (line 1143) uses "safe-set," "JSONL," "mkdir-as-lockdir," and "no flock dep." docs/walkthrough.html (line 1247) talks about gh api, HEAD SHA, CHANGES_REQUESTED, and bypass flags.

The plain-English doctrine exists in templates/CLAUDE.md (line 467), but the public walkthrough still has too much implementation texture for a non-technical founder.

**Q3. Is Foundation 1 honoured?**
The core still mostly honours the spirit: plain files, bash, Python, markdown, git. But the literal "no build step, no node_modules" claim at templates/CLAUDE.md (line 33) is no longer clean.

Tracked-file count I measured:
- Bash / hook scripts: 238 files, 42,413 lines
- Python: 53 files, 9,526 lines
- Markdown: 218 files, 22,698 lines
- HTML: 16 files, 9,890 lines
- TypeScript: 5 files, 430 lines
- JS: 1 file, 149 lines

There is no tracked node_modules, but there is package.json (line 11) and package-lock.json (line 1) for Playwright. That is reasonable for walkthrough testing, but it means the repo is no longer purely "bash + python3 + PyYAML + git + gh."

Also, the brief says 26 action files; the repo has 44 under templates/.sdd/actions. The walkthrough claims all 42 at docs/walkthrough.html (line 1232). The docs are drifting against the actual catalog.

**Q4. Where does the framework still assume?**
1. The moat fails open if verify-stage.sh is missing: pre-commit-stage-verified.sh (line 154). Close it by failing closed for any initialized SDD project.
2. Section-lock coverage skips if hash-section.sh or approved_sections are absent: pre-commit-stage-verified.sh (line 795) and line 818. Good compatibility, weak certainty.
3. pre-commit-rules.sh allows commits when PyYAML/config/frontmatter parsing fails: pre-commit-rules.sh (line 261). That is the opposite of "never assume."
4. The native pre-commit shim warns and continues when a configured hook file is missing: pre-commit (line 78). Missing enforcement should block, unless explicitly in migration mode.
5. The test-first hook passes through when stash fails: pre-commit-test-first.sh (line 217). It even documents path-with-space limitations at line 25.

**Q5. Will this survive a different downstream user?**
Yes, but with friction.

For a Python data pipeline, the first pain is GitHub-shaped workflow. Actions like push-pr, verify-ci-green, and CodeRabbit convergence assume gh, PRs, and review bots. A GitLab/Airflow/data-platform team will need adapters.

Second, test-first enforcement is biased toward tests/task-NNN.* and simple script runners. It handles .py, but real data pipelines use pytest fixtures, snapshots, external services, and slow integration tests. The framework can express that, but the mechanical hook is narrower.

Third, non-UI work still has UI ceremony nearby. Some files say to skip when no UI, but wireframe.md (line 21) still makes static HTML/Tailwind the default mental model. For a batch pipeline, that can feel like proving seriousness by drawing boxes.

**Q6. Are shipped features actually shipped?**
I sampled three.

F006, 006-test-first-mechanical-check-verify-red-before-green, passes. It has .shipped, PR #153 is merged, the hook exists at pre-commit-test-first.sh (line 1), and tests T150-T158 exist in run-framework-test.sh (line 7368).

F007, 007-sdd-migrate-refresh-project-s-sdd-tree-from-upstream-framework, mostly ships but fails one requested audit check. .shipped exists, PR #157 is merged, and sdd-migrate.sh (line 1) exists with T160/T161 in run-framework-test.sh (line 8076). But the spec claims templates/.claude/commands/sdd-migrate.md at spec.md (line 44), and that file is not tracked. That is a structural ledger miss.

Bug 002 passes the four requested checks. .shipped exists, PR #147 is merged, the moat file exists, and T143-T145 exist at run-framework-test.sh (line 7077). But its spec.md still says [PHASE: SPEC] at line 3 despite being shipped. That is another ledger consistency smell.

**Q7. Goals not fully met**
"Mechanically impossible to drift": not fully. Hooks, staged checks, and manifests make normal drift hard, but fail-open paths, missing hooks, --no-verify, and unvalidated theatre annotations remain. Close it with fail-closed mode for modern SDD projects and CI-side enforcement of the same invariants.

"Simplicity over capability": partially. The core is simple in kind, but not in size, and Playwright/Node/package-lock weaken the literal promise. Close it by separating "core SDD" from "docs/test harness."

"Plain English first": partially. CLAUDE.md says it; the walkthrough often violates it. Close it by rewriting the walkthrough with founder-facing summaries first and implementation details folded.

"Every decision lands in markdown": mostly, but stale phase/state and missing claimed files show markdown can lie. Close it with a shipped-feature ledger audit that checks spec phase, named files, markers, PRs, and tests.

"Composable Lego bricks": mostly, but hidden coupling remains around GitHub, Claude hooks, .sdd paths, and test naming.

**Q8. Goals met that SDD should not take full credit for**
SDD deserves credit for the staged moat, manifest pins, action/playbook structure, append-only decisions, and executable claims audit.

Git deserves credit for staged blob inspection, hooks, commit-msg timing, branches, and diff mechanics.

GitHub and gh deserve credit for PR merge truth, CI status, review state, and issue/PR workflow.

Claude Code deserves credit for PreToolUse/Stop/UserPromptSubmit hook surfaces and slash-command behaviour. Without that harness, parts of SDD become conventions plus git hooks, not the full agent workflow.

The user still provides discipline: not bypassing hooks, keeping core.hooksPath, approving sections honestly, and treating markdown as the source of truth.

**Q9. Risks for v2.0**
Rip out: stale duplicated catalog claims and any doc/test layer that makes "no Node/build step" untrue for the core story.

Double down on: staged-content verification, manifest pinning, section hashes, executable claims audits, and migration tooling.

Leave alone: markdown-first state, bash/Python/plain-file mechanics, append-only decisions, and the action/playbook atom model.

**Executive summary:** YELLOW. SDD is not ceremony pretending to be substance; the moat and manifest system are genuinely load-bearing. But "mechanically impossible," "plain English," and "simplicity" are currently stronger as aspirations than as literal truths, and the failed framework test run plus shipped-ledger misses keep this from GREEN.
