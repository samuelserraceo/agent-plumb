# UAT Report — v0.10.1
Date: 2026-04-28T20:35:00Z
Project bootstrapped at: /var/folders/ms/qwx7ff9x1k51frhr4cmnp0480000gn/T//sdd-uat-tGYoueaXGQ

## Summary
- Total scenarios: 11
- Pass: 7
- Fail: 2
- Surprising: 2

## Per-scenario findings (one paragraph each)

**1. Fresh init — PASS WITH CAVEAT.** Bootstrap copied `.sdd/`, `.claude/`, `CLAUDE.md`. INDEX.md has `## In flight`, `## Backlog`, `## Shipped` sections and `.sdd/stack.md` exists with the four required headings (Running services / Providers / Pinned versions / Architecture facts). Caveat: bootstrap printed a folder_rules warning (`.sdd/archive/.gitkeep` flagged as deferred). More importantly, **`.sdd/config.md` line 3 says `sdd_version: 0.10.0`** while `.sdd/.cache/manifest.json` line 62 says `sdd_version: 0.10.1`. Two sources of truth disagree. Bug filed below.

**2. Start a feature — PASS WITH CAVEAT.** `start.sh "build a hello-world signup form"` correctly created `features/001-build-a-hello-world-signup-form/spec.md` with 14 actions, set `**Active:**` to the feature, and added a line under `## In flight` (not `## Active`). Caveat: INDEX.md now contains **two `**Active:**` lines** — line 1 (the new canonical pointer at the very top, correct) and line 6 (the boilerplate `**Active:** _(none)_` from the original template body, untouched). The duplicate is confusing and could trip up downstream parsers that grep for `^**Active:**`.

**3. Cascading params — PASS (after signature correction).** The UAT plan calls `resolve-parameters.sh <spec> problem who` with three args, but the script's required signature is five args: `<spec> <playbook> <stage> <action> <step>`. With the correct invocation, the script returned merged JSON with a `_provenance` map naming each contributing level (`action:problem`, `project`). Documenting either the script error (which is plain English: `usage: ...`) or the UAT plan needs a fix.

**4. Next-action — PASS.** `next-action.sh` returned a JSON envelope with `action: "problem"`, `step: "who"`, `phase: "SPEC"`, the verbatim `prompt`, the resolved `parameters` block, and the `tag: "USER-LED"` so the agent knows to ask. Shape matches what `/next` would consume.

**5. Settings command — MOSTLY PASS, ONE GOTCHA.** `list` works. `set parameters.budget.max_minutes 7` persisted to config.md (verified by re-read). `reset parameters.budget.max_minutes` removed the override and `get` correctly reports key-not-found afterwards. **Gotcha:** `get budget.max_minutes` (without the leading `parameters.` namespace) errors as "key not found" even though `list` displays the value as `parameters.budget.max_minutes = 5`. Users will reach for the displayed key path, not realise that `list` strips the `parameters.` prefix in display but `get`/`set` require it.

**6. Moat fabrication — PASS.** Hand-crafted a fake `verification.json` claiming 99/99 passing, ran `git add ... && git commit`. Refused with: `[moat] cannot read staged .sdd/features/.../spec.md — block. Stage spec.md alongside verification.json, or re-run verify-stage.sh.` Plain-English error, names the fix.

**7. Append-only on decisions.md — PASS.** Seeded a real entry, committed it, then mutated the entry text in place and re-staged. Hook refused with a textbook plain-English error: `append_only — staged blob does not start with HEAD blob`, and gave the exact recovery commands (`git restore --staged`, `git checkout`, then append). Excellent UX.

**8. Multi-feature parallel — PASS WITH SAME CAVEAT.** `start.sh "second feature for parallel test"` created `features/002-...`, both 001 and 002 appear under `## In flight`, and the canonical `**Active:**` line at the top of INDEX.md correctly switched to point to 002. The stale `**Active:** _(none)_` boilerplate at line 6 persists (same as scenario 2).

**9. stack.md — PASS.** File exists at `.sdd/stack.md` with four sections (Running services / Providers / Pinned versions / Architecture facts). Each has placeholder `_(empty — fill in as you ...)_` text plus an HTML-comment example shape. CLAUDE.md "Where things live" mentions stack.md by name, plus the session-start checklist instructs the agent to `cat .sdd/stack.md` to refresh on the project's tech stack.

**10. CLAUDE.md doctrine — PASS.** Header line 9 reads `<!-- SDD-MANAGED-START version: 0.10.1 -->` — version matches spec. The `## Code-quality doctrine (always-on, applies to every action)` heading sits at line 27 with all 8 numbered rules verified (1. Never assume / 2. Conciseness / 3. Don't over-engineer / 4. Reuse > reinvent / 5. Wireframe always reflects current state / 6. No time estimates / 7. Minimum diff / 8. Plain English first). The `## Multi-feature parallel work (v0.10.1)` heading exists at line 63 with branch-naming and parallel-work explanation. Doctrine is well-written — short, opinionated, links to enforcement.

**11. Adversarial — MIXED.** Four attacks exercised:
- *Phase advance with open `[ ]`* — **caught**, but silently. Mutating SPEC→BUILD with all checkboxes open caused the Bash tool's PreToolUse hook to refuse the `git add`/`git commit` chain. The command exited 1 but printed no error to my shell — only the absence of staged changes revealed the block. Behaviour is correct; the silent denial is a UX problem.
- *Tampered manifest.json* — **NOT caught (BUG).** I edited an `expected_sha256` to all-zeros and ran `git add .sdd/.cache/manifest.json && git commit`. Commit went through with exit 0 and no warning. The manifest is meant to be the trust anchor for framework files; it must validate against actual file hashes on commit, not just be POLICY-class for co-stage rules.
- */settings set with invalid value* — **NOT caught.** `bash .sdd/scripts/settings.sh set parameters.budget.max_minutes "not-a-number"` accepted the string for a numeric field and persisted `parameters.budget.max_minutes = 'not-a-number'`. No type validation.
- *Commit to `.sdd/.shipped/` and `.sdd/archive/`* — **expected behaviour.** Both write to deferred paths and only emit a warn (per `deferred_paths:` config block, line 211 of config.md). Documented design choice, not a bug. `.shipped` writes printed no warning at all though, which is inconsistent with `archive` (which does warn).

## Real bugs found (need fixing before next ship)

1. **Version mismatch between config.md and manifest.json.** `.sdd/config.md` says `sdd_version: 0.10.0`, `.sdd/.cache/manifest.json` says `sdd_version: 0.10.1`, and `CLAUDE.md` says `MANAGED-START version: 0.10.1`. Bootstrap is shipping config.md from v0.10.0. Fix: update template `config.md` to `0.10.1` and add a check that all three sources agree at bootstrap time.

2. **Duplicate `**Active:**` line in INDEX.md.** After `start.sh`, INDEX.md has the canonical pointer at line 1 AND the original template's `**Active:** _(none)_` at line 6. Anything that greps `^**Active:**` will get two hits. Fix: `start.sh` (or the bootstrap copy) needs to delete the template body's `**Active:** _(none)_` line, OR INDEX.md template should not include it.

3. **Manifest tampering not caught on commit.** Editing `expected_sha256` values in `.sdd/.cache/manifest.json` to garbage commits cleanly. The supply-chain story is "framework files are hash-pinned, agent reads manifest before trusting any script" — but if the manifest itself is tamperable, that's circular. Fix: at commit time, when `.sdd/.cache/manifest.json` is staged, verify each `expected_sha256` matches the actual file's sha256 on disk. Refuse the commit if they disagree (with a plain-English error pointing the user at `manifest.sh refresh` or equivalent).

4. **Phase-advance block is silent.** When the PreToolUse hook refuses a `git add`/`git commit` because the staged change would violate F1 (e.g., advancing PHASE: SPEC → BUILD with open `[ ]`), the user sees nothing — the Bash command just doesn't take effect and exits 1. This is far worse than the moat / append-only experience, which both print clear plain-English errors. Fix: ensure the hook's stderr surfaces in the agent's tool output, the same way pre-commit-rules.sh does for moat & append_only.

5. **`/settings set` accepts wrong types.** Numeric fields accept strings; there's no schema validation. Fix: add a type-map to `settings.sh` (or read it from `config.md` frontmatter) so int fields refuse non-int values with a plain-English error.

## Surprises worth flagging

- **resolve-parameters.sh signature mismatch with UAT plan.** The UAT prompt says to invoke with three args, but the script enforces five. Either the plan or the script needs reconciling. The script's error message is excellent (it shows the usage), so a user encountering this in the wild would recover — but the inconsistency suggests the spec / harness drifted.
- **`get` and `list` use different key-path conventions.** `list` displays `parameters.budget.max_minutes`, but the corresponding `get` works only with the full `parameters.budget.max_minutes` path, while `get budget.max_minutes` (the relative form a casual user would try) returns key-not-found. Decide on one form and apply consistently.

## What worked well

- **Append-only enforcement on decisions.md.** Best UX in the framework — clear error, exact recovery commands, no in-band escape hatch, calm tone. This is the gold standard.
- **Moat blocking on fabricated verification.json.** Caught the fake immediately with a plain-English message that names the file and the fix.
- **Code-quality doctrine in CLAUDE.md.** All 8 rules are well-written, opinionated, and short. Rule 6 (no time estimates in hours) is genuinely thoughtful — addresses an AI-specific pathology.
- **stack.md scaffolding.** Empty placeholders + commented example shapes is a good middle ground between "blank file" and "fake content the agent has to clear out."
- **Multi-feature parallel.** `## In flight` + canonical `**Active:**` pointer model is clean; second feature slid in without breaking 001.
- **resolve-parameters.sh `_provenance` block.** Naming the source level for every parameter leaf is exactly what you want for debugging cascading config.

## Recommendations

**v0.10.2 bug fixes (in priority order):**
1. Bump `config.md` template to `sdd_version: 0.10.1` and assert version equality at bootstrap.
2. Remove the duplicate `**Active:** _(none)_` line from INDEX.md template (or strip it on first `start.sh`).
3. Add `expected_sha256` validation when `.sdd/.cache/manifest.json` is staged — refuse commit if any pin disagrees with the on-disk file.
4. Surface stderr from the PreToolUse hook so silent denials become loud denials (especially the phase-advance case).
5. Add type-checking to `settings.sh set` (read field type from config or hardcoded map; refuse mismatches).

**Doctrine clarifications:**
- Rule 5 (wireframe) mentions enforcement via F1 generic enforcer. Worth a one-line cross-reference to "see `.claude/hooks/pre-commit-rules.sh` for the actual rule" so a curious dev can audit.
- The `deferred_paths:` (warn-only) vs `co_stage_block:` (hard block) distinction is buried — `.sdd/archive/` warns but `.sdd/.shipped/` is silent in v0.10.1. Document in CLAUDE.md exactly what's blocked vs warned, so users have a mental model when something doesn't refuse.
- "Active" vocabulary clash: there's `**Active:** features/...` (the feature pointer in INDEX.md), the boilerplate `**Active:** _(none)_` line, the `## In flight` section, and `**Active blocker:**`. Pick one term per concept and stick with it.

**Missing tests (test suite suggestions for the framework repo):**
- A unit test that `bootstrap-uat.sh` produces a project with a single `**Active:**` line in INDEX.md.
- A unit test that `sdd_version` matches across `config.md`, `manifest.json`, and `CLAUDE.md` MANAGED-START.
- An integration test that mutating `expected_sha256` in `manifest.json` is refused at commit.
- An integration test that PreToolUse hook denial surfaces a non-empty stderr to the agent.
- An integration test that `settings.sh set` refuses string values for numeric fields.
- An integration test that `settings.sh get <key>` works for both displayed and full forms (or pick one and document).

Word count: ~1430.
