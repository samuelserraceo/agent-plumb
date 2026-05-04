#!/usr/bin/env bash
# AC5 — --apply mode applies ADD + UPDATE-CLEAN automatically and
# writes the new manifest. Fresh dry-run after = 0 changes.

set -uo pipefail

FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
SCRIPT="$FRAMEWORK_ROOT/templates/.sdd/scripts/sdd-migrate.sh"
[ -x "$SCRIPT" ] || { echo "FAIL: sdd-migrate.sh missing"; exit 1; }

tmpdir=$(mktemp -d) || { echo "FAIL: mktemp -d failed"; exit 1; }
trap 'rm -rf "$tmpdir"' EXIT
cd "$tmpdir" || { echo "FAIL: cd $tmpdir failed"; exit 1; }

mkdir -p .sdd .claude
cp -R "$FRAMEWORK_ROOT/templates/.sdd/." .sdd/ 2>/dev/null
cp -R "$FRAMEWORK_ROOT/templates/.claude/." .claude/ 2>/dev/null

# Drift A: ADD — delete a hook that exists upstream
rm -f .claude/hooks/pre-commit-test-first.sh

# Drift B: UPDATE-CLEAN — alter advance.sh + pin its hash in manifest
target=".sdd/scripts/advance.sh"
echo '#!/usr/bin/env bash' > "$target"
echo '# old version' >> "$target"
chmod +x "$target"
prior_hash=$(python3 - "$target" <<'PY'
import hashlib, sys
with open(sys.argv[1], 'rb') as f: data = f.read()
text = data.decode('utf-8', errors='replace')
if text.startswith('﻿'): text = text[1:]
text = text.replace('\r\n', '\n').replace('\r', '\n')
lines = [ln.rstrip() for ln in text.split('\n')]
while lines and lines[0] == '': lines.pop(0)
while lines and lines[-1] == '': lines.pop()
print(hashlib.sha256('\n'.join(lines).encode('utf-8')).hexdigest())
PY
)
python3 - "$prior_hash" <<'PY'
import json, sys
m = json.load(open('.sdd/.cache/manifest.json'))
m.setdefault('scripts', {})['advance.sh'] = {
  'expected_sha256': sys.argv[1],
  'path': '.sdd/scripts/advance.sh',
  'trust': 'framework',
}
json.dump(m, open('.sdd/.cache/manifest.json', 'w'), indent=2)
PY

# Apply
out=$(bash "$SCRIPT" --apply --upstream="$FRAMEWORK_ROOT" 2>&1)
ec=$?

fails=()
[ "$ec" -eq 0 ] || fails+=("apply exit code: $ec")
[ -f .claude/hooks/pre-commit-test-first.sh ] \
  || fails+=("ADD: pre-commit-test-first.sh not added")

# Compare current advance.sh hash vs upstream's
upstream_advance="$FRAMEWORK_ROOT/templates/.sdd/scripts/advance.sh"
hash_norm() {
  python3 - "$1" <<'PY'
import hashlib, sys
with open(sys.argv[1], 'rb') as f: data = f.read()
text = data.decode('utf-8', errors='replace')
if text.startswith('﻿'): text = text[1:]
text = text.replace('\r\n', '\n').replace('\r', '\n')
lines = [ln.rstrip() for ln in text.split('\n')]
while lines and lines[0] == '': lines.pop(0)
while lines and lines[-1] == '': lines.pop()
print(hashlib.sha256('\n'.join(lines).encode('utf-8')).hexdigest())
PY
}
user_advance_hash=$(hash_norm ".sdd/scripts/advance.sh")
upstream_advance_hash=$(hash_norm "$upstream_advance")
[ "$user_advance_hash" = "$upstream_advance_hash" ] \
  || fails+=("UPDATE-CLEAN: advance.sh not refreshed to upstream hash")

# Fresh dry-run after apply → 0 changes
out2=$(bash "$SCRIPT" --upstream="$FRAMEWORK_ROOT" 2>&1)
ec2=$?
[ "$ec2" -eq 0 ] || fails+=("post-apply dry-run exit: $ec2")
printf '%s' "$out2" | grep -qiE 'in sync|no changes' \
  || fails+=("post-apply dry-run should report in-sync")
printf '%s' "$out2" | grep -qE '^\s*[+~]' \
  && fails+=("post-apply dry-run still reports ADD/CLEAN drift")

if [ ${#fails[@]} -ne 0 ]; then
  echo "FAIL: AC5 — --apply should refresh ADD + UPDATE-CLEAN + re-pin manifest"
  for f in "${fails[@]}"; do echo "  - $f"; done
  echo "  apply output:"
  printf '%s\n' "$out" | sed 's/^/    /'
  echo "  post-apply dry-run output:"
  printf '%s\n' "$out2" | sed 's/^/    /'
  exit 1
fi

echo "PASS: AC5 — --apply refreshed ADD + UPDATE-CLEAN; fresh dry-run = 0 changes"
exit 0
