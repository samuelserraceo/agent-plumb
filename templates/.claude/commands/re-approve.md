---
description: Re-lock a sub-action section after an intentional edit (Theme 1.6).
argument-hint: <slug>
---

# /re-approve

If the moat blocked your phase-advance commit with `"section §<slug>
CHANGED since you approved it"` and the new content is intentional,
run `/re-approve <slug>` to lock the new content as the canonical
approved version.

This recomputes the section hash and writes it to
`verification.json.approved_sections.<slug>`. The next phase-advance
commit will then accept the new content.

## What this command does

1. Reads `spec.md` in the active work item folder (from `INDEX.md`'s
   `**Active:**` line)
2. Re-computes SHA-256 of the §`$1` section using the same
   normalization the moat will use (SCHEMA.md §9)
3. Updates `verification.json.approved_sections["$1"]` to the new hash
4. Tells you the exact `git add` + `git commit` commands to run

## Usage

`/re-approve problem` — re-approve the §problem section
`/re-approve acceptance-criteria` — re-approve §11 ACs
`/re-approve <any-slug>` — re-approve any sub-action with `requires_user_approval: true`

## What this command does NOT do

- It does NOT auto-commit. You review the diff first, then run the
  printed `git add` + `git commit` commands yourself.
- It does NOT bypass the moat for the next commit — the new hash
  must still match the staged spec.md content. If you re-approve
  without first running verify-stage.sh, the moat may still block
  for a different reason (e.g., fabrication detection).
- It does NOT touch other approved_sections entries. If you have
  three sections approved (problem, proposed-approach, acceptance-
  criteria) and only edited §problem, only `/re-approve problem`
  is needed.

## Implementation

The slash command invokes `bash .sdd/scripts/reapprove.sh $1 <work-item-dir>`,
where `<work-item-dir>` is read from `INDEX.md`'s active work item
pointer.

For now (B-1), the agent should resolve the work-item-dir from
INDEX.md and run the script directly.
