# v0.8 Schema Test Fixtures

These fixtures exercise edge cases of the v0.8 schema (defined in repo-root `SCHEMA.md`). Theme 1's loader tests (T27-T30) and Theme 1.5's manifest tests (T34-T35) consume them.

| Fixture | Demonstrates | Expected loader behavior |
|---|---|---|
| `valid-playbook.md` | Complete valid playbook with 1 stage / 1 action / 1 exit_check | LOAD OK |
| `valid-subaction.md` | Complete valid USER-LED action | LOAD OK |
| `invalid-unknown-tag.md` | `tag: BOGUS` (not in SCHEMA.md §6 closed enum) | ERROR — unknown tag |
| `invalid-slug-mismatch.md` | `slug: actual-slug` inside, but filename suggests different slug | ERROR — slug must equal filename |
| `invalid-missing-tag.md` | Action missing required `tag:` field | ERROR — missing required field |
| `invalid-yaml-duplicate.md` | Duplicate YAML key (Codex finding #4) | ERROR — duplicate YAML key (silent corruption risk) |
| `multi-match/dup-a.md` + `multi-match/dup-b.md` | Two files with the same `slug: dup-test` | ERROR on `[[dup-test]]` resolution — multi-match |

## How tests use these

Theme 1 tests will:
1. Set up a temp `.sdd/` scaffold (via `mkproj()` refactor in `run-framework-test.sh`)
2. Copy a fixture into the appropriate path (e.g., `invalid-unknown-tag.md` → `.sdd/actions/foo.md`)
3. Run `load-playbook.sh` (or its validation flag)
4. Assert exit code + stderr message match expectations

Mutation-verification: each test must fail RED if the corresponding loader check is removed. Tests that don't fail RED on a deliberately-broken loader are shallow — rewrite them.

## Adding new fixtures

Each new fixture should demonstrate ONE specific rule. If a fixture exercises two rules at once, the test that consumes it can't isolate which rule failed. Keep one rule per file. Document the rule in this README's table.
