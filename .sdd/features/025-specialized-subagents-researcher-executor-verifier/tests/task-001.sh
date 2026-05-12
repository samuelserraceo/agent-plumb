#!/usr/bin/env bash
# T01: 3 agent role files exist with correct frontmatter
# AC1: templates/.sdd/agents/{researcher,executor,verifier}.md + .sdd/agents/{...}
#      each has frontmatter declaring role, model_tier_default, tools_allowed.
#      role matches filename basename; model_tier_default ∈ {thinking, routine, mechanical}.

set -uo pipefail
ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../../.." && pwd )"

ROLES="researcher executor verifier"
VALID_TIERS="thinking routine mechanical"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

# Helper: extract scalar value of a frontmatter key from a markdown file.
# Reads the leading YAML block between '---' fences. Returns empty string
# if not found. Bash 3.2 compat — no associative arrays.
fm_get() {
  local file="$1" key="$2"
  python3 - "$file" "$key" <<'PY' 2>/dev/null
import sys, re
path, key = sys.argv[1], sys.argv[2]
with open(path) as f:
    body = f.read()
m = re.match(r'^---\n(.*?)\n---\n', body, re.DOTALL)
if not m:
    print("")
    sys.exit(0)
for line in m.group(1).splitlines():
    line = line.strip()
    if line.startswith(key + ":"):
        val = line.split(":", 1)[1].strip()
        # strip quotes + leading brackets (arrays start with [)
        val = val.strip('"').strip("'")
        print(val)
        sys.exit(0)
print("")
PY
}

# Check both mirrors (templates + live).
for prefix in "templates/.sdd/agents" ".sdd/agents"; do
  for role in $ROLES; do
    file="$ROOT/$prefix/$role.md"
    [ -f "$file" ] || fail "missing $prefix/$role.md"

    # role: must match filename basename
    role_val=$(fm_get "$file" "role")
    [ "$role_val" = "$role" ] || fail "$prefix/$role.md frontmatter role='$role_val' ≠ filename basename '$role'"

    # model_tier_default: must be one of valid tiers
    tier=$(fm_get "$file" "model_tier_default")
    [ -n "$tier" ] || fail "$prefix/$role.md missing model_tier_default in frontmatter"
    found=0
    for valid in $VALID_TIERS; do
      [ "$tier" = "$valid" ] && found=1 && break
    done
    [ $found -eq 1 ] || fail "$prefix/$role.md model_tier_default='$tier' not in {$VALID_TIERS}"

    # tools_allowed: must be present (any non-empty value).
    # We check for the literal key (the value is a YAML list — fm_get returns
    # the array marker for empty arrays or the leading '[' for inline arrays).
    grep -qE '^tools_allowed:' "$file" || fail "$prefix/$role.md missing tools_allowed in frontmatter"
  done
done

echo "PASS: T01 — 3 agent role files exist with correct frontmatter (both mirrors)"
