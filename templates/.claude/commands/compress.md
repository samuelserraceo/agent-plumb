---
description: Consolidate a shared knowledge file (patterns or data-model) when it gets noisy.
---

$ARGUMENTS

Target file: based on `$ARGUMENTS`, operate on one of:
- `patterns` → `.sdd/patterns.md`
- `data-model` → `.sdd/data-model.md`

If `$ARGUMENTS` is empty or ambiguous, ask the user which file.

## What to do

1. Read the target file end to end.
2. Identify:
   - **Duplicates:** entries restating the same rule/decision/entity in slightly different words.
   - **Stale entries:** rules referencing features that are no longer in the project, or entities that were removed from the schema. Use `git log` or `.sdd/INDEX.md` shipped section to verify.
   - **Contradictions:** entries that conflict with each other or with current reality (for `data-model`, cross-check the actual schema / migrations if available).
   - **Over-long entries** that should link out rather than live inline.
3. Propose the consolidated version to the user BEFORE writing. Show:
   - What you'll merge
   - What you'll remove and why
   - What you'll keep verbatim
4. On user approval, rewrite the file. Commit with `[SDD] compress: <patterns|data-model>`.
5. If anything was removed or substantially reworded, note it in `.sdd/patterns.md` under "Known pitfalls / lessons learned" so we don't lose the thread.

## Rules

- Do not silently drop information. Every removal must be justified to the user.
- For `data-model.md`, NEVER remove an entity/field that is still referenced by any feature's spec.md or by live code. Grep first.
- Keep the file's structure (same headings, same conventions). Only the content inside gets compacted.
