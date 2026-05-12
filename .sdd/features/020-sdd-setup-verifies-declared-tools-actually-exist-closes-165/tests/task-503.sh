#!/usr/bin/env bash
# T503 — AC4 — Check 3 branch protection.
#
# When stack.md declares "branch protection on main" (mentions
# `protect` AND `main`), verify-stack.sh runs check 3: probes
# `gh api repos/.../branches/main/protection` and emits ✓ on
# 200, ✗ + gh-set-protection hint on failure.
#
# When stack.md does not declare branch protection, check 3 must
# NOT fire.

set -uo pipefail

FRAMEWORK_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../../.." && pwd )"
LIVE_SCRIPT="$FRAMEWORK_ROOT/.sdd/scripts/verify-stack.sh"

fails=()

mkstub_gh_ok() {
  local d
  d=$(mktemp -d -t sdd-t503-stubok.XXXXXX)
  cat > "$d/gh" <<'EOF'
#!/usr/bin/env bash
echo '{"required_status_checks":{"contexts":["typecheck"]}}'
exit 0
EOF
  chmod +x "$d/gh"
  echo "$d"
}

mkstub_gh_fail() {
  local d
  d=$(mktemp -d -t sdd-t503-stubfail.XXXXXX)
  cat > "$d/gh" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
  chmod +x "$d/gh"
  echo "$d"
}

mkproject() {
  # $1 = stack.md content
  local d
  d=$(mktemp -d -t sdd-t503-proj.XXXXXX)
  mkdir -p "$d/.sdd"
  cat > "$d/.sdd/config.md" <<EOF
---
type: config
parameters:
  review:
    bot: ""
  mcp:
    tier3:
      enabled: false
---
EOF
  printf '%s\n' "$1" > "$d/.sdd/stack.md"
  echo "$d"
}

# --- A) stack declares branch protection + gh stub ok -> check 3 fires ✓ ---
STUB=$(mkstub_gh_ok)
PROJ=$(mkproject "# stack
- branch protection on main with required CI checks")
OUT=$(cd "$PROJ" && PATH="$STUB:$PATH" CLAUDE_PROJECT_DIR="$PROJ" bash "$LIVE_SCRIPT" 2>&1)
rm -rf "$STUB" "$PROJ"
if ! printf '%s\n' "$OUT" | grep -qiE "branch protection"; then
  fails+=("A: stack declares branch protection but script emitted no branch-protection line. Output: $OUT")
fi

# --- B) stack declares branch protection + gh stub fail -> ✗ ---
STUB=$(mkstub_gh_fail)
PROJ=$(mkproject "# stack
- branch protection on main with required checks")
OUT=$(cd "$PROJ" && PATH="$STUB:$PATH" CLAUDE_PROJECT_DIR="$PROJ" bash "$LIVE_SCRIPT" 2>&1)
rm -rf "$STUB" "$PROJ"
if ! printf '%s\n' "$OUT" | grep -qiE "branch protection.*not|protection.*missing"; then
  fails+=("B: stack declares branch protection + gh fail: expected fail message, got: $OUT")
fi

# --- C) stack does NOT declare branch protection -> check 3 must NOT fire ---
PROJ=$(mkproject "# stack
- some other line that does not mention the magic words")
OUT=$(cd "$PROJ" && CLAUDE_PROJECT_DIR="$PROJ" bash "$LIVE_SCRIPT" 2>&1)
rm -rf "$PROJ"
if printf '%s\n' "$OUT" | grep -qi "branch protection"; then
  fails+=("C: stack does not declare branch protection but script fired. Output: $OUT")
fi

if [ ${#fails[@]} -gt 0 ]; then
  echo "FAIL: T503 — AC4 violations:"
  for e in "${fails[@]}"; do echo "  - $e"; done
  exit 1
fi

echo "PASS: T503 — check 3 branch protection fires when stack declares it"
