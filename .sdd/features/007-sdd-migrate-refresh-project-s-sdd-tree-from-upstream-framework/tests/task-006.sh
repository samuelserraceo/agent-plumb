#!/usr/bin/env bash
# AC6 — --apply on UPDATE-CONFLICT prompts (keep / overwrite / show-diff)
# and the default (Enter) is keep (safe failure mode).

set -uo pipefail

FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
SCRIPT="$FRAMEWORK_ROOT/templates/.sdd/scripts/sdd-migrate.sh"
[ -x "$SCRIPT" ] || { echo "FAIL: sdd-migrate.sh missing"; exit 1; }

# ── Sub-test A: default (Enter) on conflict → keep ───────────────────
d_a=$(mktemp -d) || { echo "FAIL: mktemp -d failed"; exit 1; }
(
  cd "$d_a" || exit 1
  mkdir -p .sdd .claude
  cp -R "$FRAMEWORK_ROOT/templates/.sdd/." .sdd/ 2>/dev/null
  cp -R "$FRAMEWORK_ROOT/templates/.claude/." .claude/ 2>/dev/null

  # Local edit (no manifest patch) → CONFLICT
  echo '#!/usr/bin/env bash' > .sdd/scripts/advance.sh
  echo '# users custom logic' >> .sdd/scripts/advance.sh
  CUSTOM_MARKER="users custom logic"

  # Pipe a single empty line (Enter = default = keep)
  out=$(printf '\n' | bash "$SCRIPT" --apply --upstream="$FRAMEWORK_ROOT" 2>&1)
  ec=$?

  user_content=$(cat .sdd/scripts/advance.sh)
  if [ "$ec" -eq 0 ] && printf '%s' "$user_content" | grep -q "$CUSTOM_MARKER"; then
    echo "PASS_KEEP"
  else
    echo "FAIL_KEEP ec=$ec content=$user_content out=$out"
  fi
)  > "$d_a/result.txt" 2>&1
result_a=$(grep -E '^PASS|^FAIL' "$d_a/result.txt" | tail -1)
rm -rf "$d_a"

# ── Sub-test B: 'overwrite' on conflict → upstream wins ──────────────
d_b=$(mktemp -d) || { echo "FAIL: mktemp -d failed"; exit 1; }
(
  cd "$d_b" || exit 1
  mkdir -p .sdd .claude
  cp -R "$FRAMEWORK_ROOT/templates/.sdd/." .sdd/ 2>/dev/null
  cp -R "$FRAMEWORK_ROOT/templates/.claude/." .claude/ 2>/dev/null
  echo '#!/usr/bin/env bash' > .sdd/scripts/advance.sh
  echo '# users custom logic' >> .sdd/scripts/advance.sh

  out=$(printf 'overwrite\n' | bash "$SCRIPT" --apply --upstream="$FRAMEWORK_ROOT" 2>&1)
  ec=$?
  user_content=$(cat .sdd/scripts/advance.sh)
  upstream_content=$(cat "$FRAMEWORK_ROOT/templates/.sdd/scripts/advance.sh")
  if [ "$ec" -eq 0 ] && [ "$user_content" = "$upstream_content" ]; then
    echo "PASS_OVERWRITE"
  else
    echo "FAIL_OVERWRITE ec=$ec"
  fi
) > "$d_b/result.txt" 2>&1
result_b=$(grep -E '^PASS|^FAIL' "$d_b/result.txt" | tail -1)
rm -rf "$d_b"

fails=()
[[ "$result_a" == PASS_KEEP ]] || fails+=("Sub-A (Enter default keep): $result_a")
[[ "$result_b" == PASS_OVERWRITE ]] || fails+=("Sub-B (overwrite): $result_b")

if [ ${#fails[@]} -ne 0 ]; then
  echo "FAIL: AC6 — conflict prompt should default to keep + accept overwrite"
  for f in "${fails[@]}"; do echo "  - $f"; done
  exit 1
fi

echo "PASS: AC6 — Enter defaults to keep; 'overwrite' picks upstream"
exit 0
