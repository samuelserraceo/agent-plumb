#!/usr/bin/env bash
# spec: features/002-plain-english-prose-sweep §11.AC15 — cross-platform sanity
# Test: lint-action-prose.sh uses no GNU-only or BSD-only constructs.

set -uo pipefail  # drop -e so error paths can run (CR cycle 2)
LINT=".sdd/scripts/lint-action-prose.sh"

# Check for known non-portable constructs
# POSIX-safe word boundaries: `\b` is a GNU-grep extension and would
# itself violate the portability claim this test asserts. Use
# character-class anchors `(^|[^[:alnum:]_])` and `([^[:alnum:]_]|$)`.
# CR cycle 3 catch.
np_re='(^|[^[:alnum:]_])(sed -i|sed --regex|grep -P|readlink -f|test -ef)([^[:alnum:]_]|$)'
# Strip comment lines (whose first non-whitespace char is `#`) before
# matching, so a comment in the script that mentions `sed -i` doesn't
# false-positive. CR cycle 4 catch.
if grep -vE '^[[:space:]]*#' "$LINT" | grep -E "$np_re" >/dev/null; then
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
