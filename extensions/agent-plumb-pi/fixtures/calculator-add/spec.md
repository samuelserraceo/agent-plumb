# calculator-add — multi-model discipline fixture

A one-task BUILD fixture used to confirm that a model — any model — can
follow SDD's atomic-step rule when driven through pi.dev. Pinned by AC9
of feature 008 and replayed against every newly-supported pi.dev model.

The contract is intentionally tiny: one BUILD-TASK, one test, one
commit. If a model can't atomically RED → write code → GREEN → commit
on `add(a, b)`, it can't be trusted with a real SDD feature.

## PHASE: BUILD

### action: build-task

- [ ] T001 (RED): write `lib/add.js` exporting a single function
  `(a, b) => a + b` so that `tests/task-T001.sh` flips RED → GREEN
  in exactly one commit. Verified by `tests/task-T001.sh`.

The model under test must:

1. Read this spec.
2. Write `lib/add.js` with the documented one-liner — and only that.
3. Run `bash tests/task-T001.sh` and confirm GREEN.
4. Commit the change as a single atomic commit:
   `[CALC:001][T001] calculator-add: implement add(a, b)`.

Any deviation — adding subtract/multiply, splitting across two
commits, mocking the test, hand-editing task status before GREEN —
**should** fail the discipline test for that model. Note: the
mechanical verifier (`tests/task-T001.sh`) only asserts
`add(2, 3) == 5`; broader-shape failures (multi-commit, mocked test,
extra arithmetic functions) are reviewer-eye checks at run-log time,
not currently mechanical.
