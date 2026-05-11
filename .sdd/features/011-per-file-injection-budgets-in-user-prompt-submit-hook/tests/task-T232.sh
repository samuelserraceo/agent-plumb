#!/usr/bin/env bash
# T232 — AC13 — no new network surface: git diff of the new hook +
# resolver adds zero new matches for curl/wget/http[s]:// /nc /socket.

set -uo pipefail

FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
HOOK="$FRAMEWORK_ROOT/templates/.claude/hooks/user-prompt-submit.sh"
HELPER="$FRAMEWORK_ROOT/templates/.sdd/scripts/get-injection-budget.sh"

# Both files must exist.
[ -f "$HOOK" ] || { echo "FAIL: T232 — hook missing"; exit 1; }
[ -f "$HELPER" ] || { echo "FAIL: T232 — helper missing"; exit 1; }

fails=()

# Grep for network-call patterns in the new code. Note: we check
# the WHOLE file, not just a diff, because (a) git's worktree-aware
# diff plumbing is fragile in test contexts, and (b) the assertion
# we care about is "the new hook does not introduce a network call",
# which the file-contents grep also satisfies.
#
# Exclusions: matches inside comments or string literals that
# document network-related concepts (e.g. the "no network surface"
# comment) are allowed; we look for actual command invocations.
for pat in '^[[:space:]]*curl ' '^[[:space:]]*wget ' '\$\(curl' '\$\(wget' '^[[:space:]]*nc ' "socket\\." "socket("; do
  hits=$(grep -E -c "$pat" "$HOOK" "$HELPER" 2>/dev/null | grep -v ':0$' | head -5)
  if [ -n "$hits" ]; then
    fails+=("new network surface match '$pat': $hits")
  fi
done

# Specifically: the hook must not contain http:// or https:// outside
# comments. Strip comment-leading-# lines first.
http_matches=$(grep -nE '(http|https)://' "$HOOK" "$HELPER" 2>/dev/null | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#')
if [ -n "$http_matches" ]; then
  fails+=("http(s):// URL in non-comment line: $http_matches")
fi

if [ ${#fails[@]} -gt 0 ]; then
  echo "FAIL: T232 — AC13 no-network-surface violations:"
  for f in "${fails[@]}"; do
    echo "  - $f"
  done
  exit 1
fi

echo "PASS: T232 — AC13 no new network surface: zero curl/wget/http[s]:///nc /socket calls in hook + resolver"
