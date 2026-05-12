#!/usr/bin/env bash
# T03: Subagent entity in data-model.md + doctrine paragraph in CLAUDE.md
# AC3: .sdd/data-model.md contains '### Subagent' heading; body names
#      the 3 roles AND declares the 3 frontmatter fields.
#      templates/CLAUDE.md contains a doctrine paragraph naming the
#      3 roles + the /dispatch entry-point.

set -uo pipefail
ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../../.." && pwd )"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

# --- Part 1: data-model.md has the Subagent entity ---
DM="$ROOT/.sdd/data-model.md"
[ -f "$DM" ] || fail "missing .sdd/data-model.md"

# Heading must exist.
grep -qE '^### Subagent$' "$DM" || fail "data-model.md does not have '### Subagent' heading"

# Extract the Subagent section body (between the heading and the next ### or ## heading).
SUB_BODY=$(awk '
  /^### Subagent$/   { capture = 1; next }
  capture && /^##/   { exit }
  capture && /^### / { exit }
  capture            { print }
' "$DM")

[ -n "$SUB_BODY" ] || fail "Subagent section body is empty in data-model.md"

# Body must name the 3 shipped roles.
for role in researcher executor verifier; do
  echo "$SUB_BODY" | grep -q "$role" \
    || fail "data-model.md Subagent section does not name role '$role'"
done

# Body must declare the 3 frontmatter fields.
for field in role model_tier_default tools_allowed; do
  echo "$SUB_BODY" | grep -q "$field" \
    || fail "data-model.md Subagent section does not declare frontmatter field '$field'"
done

# --- Part 2: doctrine paragraph in templates/CLAUDE.md ---
CMD="$ROOT/templates/CLAUDE.md"
[ -f "$CMD" ] || fail "missing templates/CLAUDE.md"

# Must name /dispatch.
grep -q '/dispatch' "$CMD" || fail "templates/CLAUDE.md does not mention /dispatch"

# Must name the 3 roles together (looking for them all in the same file is enough;
# the doctrine paragraph is the only place they all appear together).
for role in researcher executor verifier; do
  grep -q "$role" "$CMD" || fail "templates/CLAUDE.md does not name role '$role'"
done

echo "PASS: T03 — Subagent entity in data-model.md + doctrine in CLAUDE.md (both mention the 3 roles)"
