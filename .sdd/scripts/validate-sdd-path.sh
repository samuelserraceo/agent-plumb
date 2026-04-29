#!/usr/bin/env bash
# validate-sdd-path.sh — F1 path safety helper.
#
# Validates that a path stays inside the project's `.sdd/` directory.
# Used by F1 generic enforcer (and the moat) to refuse user-editable
# paths from `events:` / `touches:` / `file_rules:` declarations that
# would escape the project root.
#
# Usage:
#   validate-sdd-path.sh <path>
#
# Exit:
#   0 — path is safe (relative-to-project, under .sdd/, no `..` segments)
#   2 — path is unsafe (absolute, escapes .sdd/, or contains `..`)
#   1 — usage error (no path given)
#
# Stdout (on exit 0): the canonicalised path (with `<work-item>` placeholders preserved).
# Stderr (on exit 2): plain-English explanation of the rejection.
#
# Why this matters: config.md `events:` block has lines like
#   target: ".sdd/<work-item>/spec.md"
# `<work-item>` is substituted at runtime from INDEX.md's `**Active:**`
# line — which is user-editable. A malicious or buggy edit to the
# Active path could put a payload like `../../etc/passwd`. F1 will read
# resolved targets and use them to validate staged files; without this
# check, the path traversal becomes a real attack surface.
#
# Determinism: pure string check; no file IO; no subprocess.

set -uo pipefail

if [ $# -lt 1 ]; then
  echo "validate-sdd-path.sh: missing path argument" >&2
  exit 1
fi

path="$1"

# Empty path → reject (defensive; declarations should always have a target).
# Done first so later checks don't trip set -u on empty arrays.
if [ -z "$path" ]; then
  echo "validate-sdd-path.sh: rejected — empty path" >&2
  exit 2
fi

# Reject absolute paths (Unix-style and Windows-style).
case "$path" in
  /* | [A-Za-z]:[/\\]*)
    echo "validate-sdd-path.sh: rejected — absolute path not allowed in framework declarations: $path" >&2
    exit 2
    ;;
esac

# Reject any segment equal to `..` (after normalising separators).
# Strategy: split on `/`, check each segment.
#
# CodeRabbit cycle 9: the prefix check + final emit must use the
# normalised form, not the raw input. Otherwise a Windows-style
# input (`.sdd\\foo\\bar`) would normalise to `.sdd/foo/bar`,
# pass the `..`-segment check, then echo back the raw mixed-slash
# form — leaving downstream callers to either re-normalise or
# trip on the wrong separator. Emit canonical.
normalised="${path//\\//}"  # back-slashes → forward-slashes (Windows tolerance)
IFS='/' read -r -a parts <<< "$normalised"
for seg in "${parts[@]}"; do
  if [ "$seg" = ".." ]; then
    echo "validate-sdd-path.sh: rejected — '..' segment escapes project root: $path" >&2
    exit 2
  fi
done

# Require the path to start with `.sdd/` (or be a literal `.sdd` directory ref).
# This is intentionally strict: framework declarations are always inside .sdd/.
# A future relaxation may allow a configurable prefix list.
case "$normalised" in
  .sdd|.sdd/*)
    ;;
  *)
    echo "validate-sdd-path.sh: rejected — path not under .sdd/: $path" >&2
    exit 2
    ;;
esac

# Emit the CANONICAL (normalised) form so callers chain on a single
# separator convention: `path=$(validate-sdd-path.sh "$x")`.
printf '%s\n' "$normalised"
exit 0
