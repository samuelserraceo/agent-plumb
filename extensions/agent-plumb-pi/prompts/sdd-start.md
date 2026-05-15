---
description: Start a new SDD work item — scaffolds the folder, spec.md, and INDEX.md.
argument-hint: "<title for the new work item>"
---

# /sdd-start

Begin a new SDD work item. Pick the kind of work, give it a one-line title, and the framework scaffolds the folder + spec.md + updates INDEX.md.

Run `bash .sdd/scripts/start.sh "$ARGUMENTS"` and report the output verbatim. The script picks the next ID, slugifies the title, creates `.sdd/features/<NNN>-<slug>/spec.md`, updates `INDEX.md`, and prints the exact `/sdd-next` to run first.

Same surface as Claude Code's `/start` — only the slash prefix differs (pi convention is `sdd-`).
