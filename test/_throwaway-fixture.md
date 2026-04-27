# Feature: Personal landing page + email waitlist

> **Branch:** `sdd/001-landing-page-waitlist`
> **Active blocker:** §1 Problem

[PHASE: SPEC]

<!--
Throwaway feature for stress-testing SDD v0.7.5-phase-a.
The agent drives this through SPEC → BUILD → SHIP using the inner loop:
  - bash .sdd/scripts/next-action.sh <spec.md>   → returns the next blocker
  - bash .sdd/scripts/verify-stage.sh <spec.md> <PHASE>  → at each transition
-->

## PHASE: SPEC

### §1 Problem
- **Who has it:** [ ]
- **Why now:** [ ]
- **What breaks without it:** [ ]

### §2 Success
- **Verifiable outcomes:** [ ]

### §3 User stories
- [ ]

### §4 UX & Design brief
- **Tone / feel:** [ ]
- **Reference sites / apps (3 candidates):** [ ]
- **Primary screen size & device posture:** [ ]
- **Information density:** [ ]
- **Motion / interactivity:** [ ]
- **Accessibility floor:** [ ]

### §5 Proposed approach
- **Recommended approach:** [ ]
- **Alternatives considered (≥2):** [ ]
- **What we trade off:** [ ]
- **Key technical choices for sign-off:** [ ]

### §6 Data contract
- **Entities affected:** [ ]
- **New fields / migrations:** [ ]
- **Relations created or removed:** [ ]
- **Edge cases at the data layer:** [ ]

### §7 Flows
- **Flow 1:** [ ]

### §9 Out of scope
- [ ]

### §11 Acceptance criteria
- [ ] AC1: ...

### §12 Human sign-off steps
- [ ]

### Wireframe
- **Approved by user:** [ ]

### plan-decompose
- [ ] task list

### Exit checks
- [ ] C-spec-acs: §11 has ≥1 acceptance criterion — grep -q '\[ \] AC' "$SECTION_FILE"
- [ ] C-spec-tasks: plan-decompose produced ≥1 task — grep -Eq '\[ \] T[0-9]' "$SECTION_FILE"

## PHASE: BUILD

### run-mode-chosen
- **Run mode:** [ ]

### build-task
- [ ] T1 ...

### Exit checks
- [ ] C-build-tasks-green: every task is GREEN — ! grep -Eq '\[ \] T[0-9]' "$SECTION_FILE"

## PHASE: SHIP

### verify-test-run
- **All ACs pass (excluding PROD-ONLY):** [ ]

### verify-prod-only-acs
- [ ]

### learn-summary
- **Summary:** [ ]

### learn-lessons
- **Lesson 1:** [ ]

### push-pr
- **PR URL:** [ ]

### verify-ci-green
- **CI green:** [ ]

### mark-shipped
- **Shipped:** [ ]

### Exit checks
- [ ] C-ship-pr-url: PR URL present — grep -Eq 'PR URL:.*https?://' "$SECTION_FILE"
- [ ] C-ship-marked: mark-shipped filled — grep -Eq 'Shipped:.*\[(x|GREEN)' "$SECTION_FILE"
