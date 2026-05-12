# Redirect stub — 016-cross-branch-id-collision-detection-007-final

This folder is a **redirect stub**, not a real feature.

The work shipped via a non-ceremony PR (squash-merge with a `[feat NNN]` /
`[fix NNN]` short tag rather than a full SDD spec.md walk). decisions.md
references the work by the slug above; the wiki-link 4-tier resolution
rule (`CLAUDE.md` "Wiki-links — references as a graph") needs an exact
filename match against a feature folder.

The append-only contract on decisions.md prevents editing those entries
in place. This stub exists so the wiki-link resolves and `post-stop-lint`
stays quiet without violating append-only.

## Same pattern elsewhere

`008-background-while-waiting/README.md` — F009 was originally
scaffolded as 008, renamed mid-PR, and the short-slug stub was preserved.

`014-model-right-sizing-per-step/README.md` — same redirect-stub
pattern on a different stale slug.

## Do not delete

Removing this folder breaks the wiki-link resolution from decisions.md
and the post-stop-lint will fire every turn until either the folder
exists or the original entry is edited (the latter is blocked by
append-only).
