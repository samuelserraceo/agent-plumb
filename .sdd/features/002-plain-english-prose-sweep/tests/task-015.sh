#!/usr/bin/env bash
# spec: features/002-plain-english-prose-sweep §11.AC15 — cross-platform sanity
# Test: lint-action-prose.sh uses no GNU-only or BSD-only constructs.

set -euo pipefail
LINT=".sdd/scripts/lint-action-prose.sh"

# Check for known non-portable constructs
if grep -E "^[^#]*(\bsed -i\b|\bsed --regex|\bgrep -P\b|\breadlink -f\b|\btest -ef\b)" "$LINT" >/dev/null; then
  echo "FAIL: $LINT uses non-portable construct (sed -i / GNU-only flag)" >&2
  exit 1
fi

# Confirm shebang is /usr/bin/env bash (portable) not /bin/bash hardcoded
shebang=$(head -1 "$LINT")
if [ "$shebang" != "#!/usr/bin/env bash" ]; then
  echo "FAIL: $LINT shebang is '$shebang'; expected '#!/usr/bin/env bash'" >&2
  exit 1
fi

# Confirm the lint runs cleanly via plain `bash` (not requiring zsh / dash /
# specific shell features beyond bash)
out=$(bash "$LINT" 2>&1)
ec=$?
if [ "$ec" -ne 0 ]; then
  echo "FAIL: lint failed when run via plain bash. Output: $out" >&2
  exit 1
fi

echo "PASS: AC15 — lint uses portable bash (no GNU-only / BSD-only constructs)"
