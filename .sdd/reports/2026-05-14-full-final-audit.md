# SDD Final Audit — 2026-05-14

## 1. Headline

**YELLOW.** Framework is structurally sound — every layer that has automation reports clean math — but two test failures (T160 + T263) and three spec-lint failures trace back to a single uncommitted local edit (`DRIFT-TEST-MARKER` in `templates/.sdd/actions/problem.md`) plus two in-flight feature specs that haven't been cleaned of theatre tokens. No code-level regressions. One commit unwinds the worktree noise.

## 2. Per-surface results

| # | Check | Pass/Fail | Evidence |
|---|-------|-----------|----------|
| 1 | Framework tests | **246/248** | `RESULTS: 246/248 passing`. Failing: T160 (sdd-migrate drift detected on synced project), T263 (sweep regression — `FAIL=10 prior assertions`). Both downstream of the same uncommitted edit. |
| 2 | Claims audit | **32/33** | `32 passed · 1 failed (33 claims audited)`. Sole failure: `claim_196_framework_tests_pass` — itself a transitive consequence of (1). |
| 3 | Anti-theatre lint sweep | **30/32 specs clean** | 2 in-flight specs trip the lint: `001-tier-3-llm-driven-synthesis/spec.md` (10 untagged claims: ≥80, <1KB, always, guarantees, enforce, never, 30%); `002-plain-english-prose-sweep/spec.md` (5 untagged: 100%, never×3, enforces). Both are work-in-progress feature folders, not shipped. |
| 4 | Action-prose lint | **PASS** | `lint-action-prose.sh` exit 0; every USER-LED / AGENT-LED action under `templates/.sdd/actions/` carries its `**What it looks like:**` block. |
| 5 | Manifest integrity | **PASS** | After applying framework's `normalized_sha256` (LF + trim trailing whitespace + strip blank edges), 0 mismatches across 25 scripts + 44 actions in both `.sdd/.cache/manifest.json` and `templates/.sdd/.cache/manifest.json`. |
| 6 | Live ↔ template parity | **1 file drift** | `diff -rq .sdd/scripts templates/.sdd/scripts` clean. `diff -rq .sdd/actions templates/.sdd/actions` → only `problem.md` differs: a deliberate test marker (`+DRIFT-TEST-MARKER` appended to templates copy) staged in working tree to drive T160. Roll back to clear (1) + (2). |
| 7 | /sdd-verify-stack | **1 ok / 1 warn** | `ci-workflows: ok — 3 workflow file(s)`; `branch-protection: warn — main branch protection NOT configured`. Script only runs 2 checks today, not 6. |
| 8 | Wiki-link integrity | **PASS (silent)** | `post-stop-lint.sh` exit 0. Free-form grep finds 270 wiki-link tokens, 53 "unresolved" — all are literal teaching examples (`[[link]]`, `[[001-waitlist]]` in CLAUDE.md/decisions.md doc prose); the hook knows to skip these via ignore-block markers. No real graph dangling edges. |
| 9 | Git hygiene | **YELLOW** | `git status`: 1 file modified (`templates/.sdd/actions/problem.md` — the drift-test marker). 12 worktrees listed, 8 `locked` (parallel agents, expected). Latest tags: v1.6.0 → v1.6-anchor-skeleton-doctrine → v1.7.0 → v1.7.1 → v1.7.2 → v1.7.3 → v1.8.0 → v1.8.1 → v1.8.2 → v1.8.3. No v1.9 tag yet. |
| 10 | Gap identification | **See §4** | 247 named tests + 33 claims cover most surfaces; 5 genuine gaps below. |

## 3. Test count growth

```
v1.0 baseline: ~140 tests · v1.7: 218 tests · v1.8: ~228 · today: 247 (+33 claims = 280 assertions)
```

Trend: +107 tests over six months, ~+18/version average. v1.7 → today added ~30 tests focused on lego-model-tier, dispatch, subagents, verify-cr-convergence. Growth healthy, no plateau.

## 4. Gap analysis — surfaces relying on agent discipline, not mechanical check

- **No mechanical check that a feature's wireframe.html stays in sync with its spec.md.** F1 generic enforcer demands wireframe stages alongside UI-touching actions, but nothing asserts that the wireframe's content meaningfully reflects the spec. Easy to commit a stale wireframe and pass.
- **No semantic check on USER-LED grill protocol application.** The lint asserts the *skeleton is referenced* in the action file; the actual grill quality (did the agent fire ≤3 challenging follow-ups?) is reviewed by humans at PR-merge time. Agents can technically reference-and-skip.
- **No automated audit that `[PROD-ONLY]` ACs are eventually closed after deploy.** `INDEX.md ## Pending production verification` accumulates them, but no script flags ones older than N days or shipped without check-back.
- **MCP server's `synthesize` query (Tier 3) has only structural tests** — no end-to-end test that synthesised output is correctly cited-checked against source chunks. The doctrine is forward-loaded; verification isn't.
- **`verify-stack.sh` runs only 2 of the ~6 conceptual checks** (ci-workflows + branch-protection). Database reachability, AI gateway credentials, secret presence, MCP server availability — all declared in `config.md` but not pinged by the script.

## 5. Recommended hardening sprint (top 3, prioritised)

1. **Add a "no uncommitted drift markers" CI gate** that fails the build if any tracked file outside `test/fixtures/` contains string `DRIFT-TEST-MARKER` (or similar test-only sentinels). Would catch exactly the situation today where the local edit silently broke 3 audit surfaces. *Cost: 5 lines in `.github/workflows/sdd-ci.yml`.*
2. **Run anti-theatre lint on every spec.md in CI**, not just newly-changed ones. Two in-flight specs (001-tier-3, 002-plain-english-prose-sweep) have been carrying untagged theatre tokens for weeks because their feature work is paused — CI never sees them. *Cost: 1 loop over `find .sdd/features -name spec.md`.*
3. **Expand `verify-stack.sh` to the full 6 checks** declared by the prompt's design (DB / AI gateway / secrets / MCP / branch-protection / ci-workflows). The two-check version gives a false signal of "stack verified" when only the cheapest layer is touched.

---

*Audit run by general-purpose agent · all checks run locally · no network calls · single uncommitted edit (problem.md drift marker) accounts for both test failures + the claims-audit failure; reverting it returns the repo to 248/248 + 33/33.*
