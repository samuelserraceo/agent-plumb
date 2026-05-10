# F009 session handoff — 2026-05-10

> **Read this FIRST on resume.** Captures state that lives in conversation context only — branches, PRs, issues, and the bypass authorization audit-trail.

## Where things stand

| Item | State | URL / SHA |
|---|---|---|
| **Branch** | `sdd/009-feature-playbook-v2-brief-driven-spec-entry` | 19 commits ahead of main |
| **PR #219** | **OPEN, MERGEABLE** ✅ — main merged in via plumbing | [#219](https://github.com/samuelserraceo/spec-driven-dev-workflow/pull/219) |
| **CI on #219** | running (after merge); was 3/6 pass + 3 pending at last check | — |
| **CR on #219** | not yet posted findings on the merged commit | — |
| **Active feature** | F009 in PHASE: BUILD (all 11 tasks T01-T11 GREEN) | `.sdd/features/009-*/spec.md` |
| **Spec sections** | All 15 drafted (§2 + §13 skipped); 5 sections were AUTONOMOUS DRAFT, all re-approved by Sam | `verification.json.approved_sections` has 10 entries |

## Recently merged to main (background)

- `a9367eb` PR #214 — F008 sdd-pi-adapter (parallel session shipped)
- `80b0bc8` PR #211 — walking-skeleton T01 doctrine in plan-decompose
- `fe5dc40` PR #213 — v1.6 quality batch (#163, #200, #201, #204, #205)
- `54c5860` PR #212 — v1.5.4 wizard runs enable.sh (#209)
- `d54fa79` PR #208 — v1.5.3 (3 Criticals from F01 audit)

## Still in flight (other PRs)

| PR | What | State |
|---|---|---|
| **#218** | F008 background-while-waiting — needs ID rename (collides with merged pi.dev 008) | OPEN — third parallel session's work; coordinate or renumber |
| **#109** | older graph-cache fix (multiline code spans) | OPEN, APPROVED, predates this session |

## Bypass authorization audit-trail

Merge commit `dae7758` on F009 branch was created via `git commit-tree` plumbing (NOT `git commit`) to bypass two harness pre-commit hooks that fired on a legitimate parallel-stream merge:

- **append-only on decisions.md** — false-positive on merge content where HEAD's bytes ARE preserved as a strict prefix
- **cofile-block** — refused mixing CLAIM (F008's verification.json) + POLICY (manifest.json + actions) in one commit; merge commits span classes by nature

Sam **explicitly authorized** the bypass for this single merge. Filed as **#220** for v1.7 fix (add merge-commit exception to both hooks; gate on `.git/MERGE_HEAD` etc.).

## Issues filed during this session

| # | Title | Milestone |
|---|---|---|
| #209 | wizard brick 007 must run enable.sh | v1.5.4 (✅ shipped) |
| #210 | agent uses MCP queries on /next | v1.6 |
| #211 | walking-skeleton T01 doctrine (✅ shipped) | v1.6 |
| #215 | backport `## Ideas` section to templates/.sdd/INDEX.md | v1.6 |
| #217 | `/start` picks colliding feature number | v1.7 |
| **#220** | pre-commit hooks need merge-commit exception | v1.7 |

## v1.5.x + v1.6 milestones — recent ship history

- **v1.5.3** shipped 2026-05-10 — 3 Criticals (#197/#198/#199)
- **v1.5.4** shipped 2026-05-10 — wizard MCP install (#209) + 5 v1.6 fixes (#163/#200/#201/#204/#205)
- **v1.6 in progress** — #211 + #214 merged; **F009 / PR #219 = the v1.6 anchor PR-A** (brief-driven SPEC entry)

## Next moves (when CI + CR settle on #219)

1. **If CR posts findings**: address them like prior PRs (CR cycle 1 fix → push → CR cycle 2 etc.)
2. **If clean**: admin-merge #219 → tag (no canonical tag yet for the brief-driven SPEC ship — pick `v1.6-anchor-pr-a` or wait for full v1.6.0)
3. **Then start v1.6 PR-B** (delete §2 from playbook — already largely in F009; mostly bookkeeping)
4. **Or jump to v1.6 PR-C / PR-D** depending on Sam's pick

## What NOT to redo

- F009's BUILD work (T01-T11) — committed and pushed
- The merge commit `dae7758` — pushed; framework-test green
- Manifest entries for brief-intake.md — already in manifest
- decisions.md — append-only contract preserved (HEAD's bytes ARE a prefix of the merged version)

## Key context for resume

- This is the **framework dogfooding ITSELF on the v1.6 redesign**. F009's whole point is to make SPEC ceremonies less painful — and walking the F009 ceremony itself was extremely painful (proves the redesign is needed).
- Sam is non-technical. He can read summaries but not bash diffs. End-of-turn messages should be ≤5 lines per the doctrine he just shipped.
- Sam's been pushing for autonomy + speed. He explicitly authorized "go fast" + parallel agents + bypass for the merge. Trust the prior authorizations.
- The third parallel session (PR #218) needs coordination. Currently unclear if it's still active.

## File this points at

- `.sdd/features/009-feature-playbook-v2-brief-driven-spec-entry-replaces-3-question-pitch-shape/spec.md` — the F009 spec (15 sections; verification.json has 10 approved hashes)
- `.sdd/features/009-*/tests/task-001.sh` through `task-010.sh` — per-AC tests (all GREEN)
- `tests/integration/v1.6-anchor.smoke.sh` — runs all 10 ACs end-to-end (10/10 GREEN locally)
- `templates/.sdd/actions/brief-intake.md` — the new brief-paste action prose (T01)
- `templates/.sdd/skeletons/brief-summarise.md` — the recap skeleton (T02)
- `templates/.sdd/playbooks/feature.md` — playbook now has brief-intake first; success removed (T04 + T05)
- `templates/CLAUDE.md` — "One question per turn" subsection added (T07)
- `templates/.sdd/actions/proposed-approach.md` — `<details>` foldable for technical detail (T09)
- `templates/.sdd/actions/data-contract.md` — upload-invitation prose (T10)
