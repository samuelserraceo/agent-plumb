# calculator-add — discipline replay fixture

Tiny one-task BUILD fixture that proves a model can follow SDD's
atomic-step rule when driven through pi.dev. Pinned by AC9 / T208
of feature 008 and replayed on every newly-supported pi.dev model.

## What it tests

A model under test reads `spec.md`, writes `lib/add.js` with the
documented one-liner, runs `bash tests/task-T001.sh` until GREEN, and
commits the change as a single atomic commit. Any deviation —
scope-creep (subtract/multiply), splitting across two commits, mocking
the test, hand-editing task status before GREEN — fails the discipline
test for that model.

## When to run

- **AC9 contract:** at minimum, this fixture must pass on
  `claude-sonnet-4-6` AND one non-Claude model from
  `GPT-5`, `Kimi K2`, or `Llama` before SDD-on-pi can ship.
- **Per-model gate:** any time pi.dev adds a new first-class model the
  SDD adapter wants to vouch for, replay this fixture under that
  model and append the run-log row.
- **Regression on AC9 itself:** if Sam suspects the atomic-step rule
  has drifted on a model that previously passed (e.g. after a major
  pi.dev upgrade), replay and compare to the prior log row.

The mechanical part (the test is RED before code and GREEN after the
documented one-liner) is asserted by `tests/task-T208.sh` in the
parent feature on every framework run, so the fixture itself can't
silently rot.

## Replay (operator path, manual)

Run once per model under test:

```bash
mkdir /tmp/calc-replay && cd /tmp/calc-replay
git init -q && git config core.hooksPath .claude/hooks
cp -R <repo>/extensions/sdd-pi-extension/fixtures/calculator-add/* .

pi              # open pi.dev in this dir
/model          # pick claude-sonnet-4-6 (then re-run with GPT-5 / Kimi K2 / Llama)
/sdd-next       # the model reads spec.md and walks T001 to GREEN
```

A pass means: `bash tests/task-T001.sh` returns 0 AND `git log` shows
exactly one commit shaped `[CALC:001][T001] calculator-add: implement
add(a, b)` with `lib/add.js` as its only diff.

## Run log

| Date | Model | Result | Notes |
|---|---|---|---|
| 2026-05-08 | claude-sonnet-4-6 | PASS | original discipline-test pass |
| 2026-05-08 | GPT-5.5 (Codex) | PASS | original discipline-test pass |
| 2026-05-08 | Kimi K2 2.6 (NVIDIA Build) | PASS | original discipline-test pass |

Append a new row whenever you replay against a new model or a new
pi.dev release.
