# safety hook still blocks framework updates after 138 fix

[PHASE: SPEC]

**Active blocker:** §2 (next action: bug-repro)

## PHASE: SPEC

### action: bug-problem

- [x] what: Even after the #138 fix, I still can't save updates to the framework's own files — two more bugs in the same safety hook are also getting in the way.

### action: bug-repro

- [ ] steps: Steps to reproduce — exact sequence. (e.g. '1. Sign up with sam@x.com  2. Click the magic-link email  3. Page shows 'Session not found' instead of dashboard')

### action: bug-root-cause

- [ ] cause: investigate the repro, propose a one-line root cause in plain English, get user confirmation

### action: bug-fix

- [ ] approval: draft the minimal-diff fix, name files touched, get user approval

### action: bug-regression-test

- [ ] approval: draft a test that fails before the fix and passes after, get user approval

### Exit checks
- [ ] C-spec-repro: repro steps captured in §2
- [ ] C-spec-cause: root cause captured in §3
- [ ] C-spec-fix: proposed fix recorded in §4
- [ ] C-spec-regression: regression test drafted in §5
