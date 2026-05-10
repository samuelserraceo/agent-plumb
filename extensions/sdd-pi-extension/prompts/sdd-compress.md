---
description: Consolidate a shared knowledge file (patterns.md or data-model.md) when it grows noisy.
argument-hint: "patterns | data-model"
---

# /sdd-compress

Consolidate `patterns.md` or `data-model.md` when it grows noisy. Pass `patterns` or `data-model` as the argument.

Run `bash .sdd/scripts/compress.sh "$ARGUMENTS"` and surface the proposed merge to the user for approval before committing. Same flow as Claude Code's `/compress`.
