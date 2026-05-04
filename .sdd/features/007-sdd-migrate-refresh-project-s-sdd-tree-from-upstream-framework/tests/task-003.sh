#!/usr/bin/env bash
# AC3 — dry-run on a project where user has stock prior content +
# upstream has newer → reports under UPDATE-CLEAN.

set -uo pipefail

FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
SCRIPT="$FRAMEWORK_ROOT/templates/.sdd/scripts/sdd-migrate.sh"
[ -x "$SCRIPT" ] || { echo "FAIL: sdd-migrate.sh missing"; exit 1; }

tmpdir=$(mktemp -d) || { echo "FAIL: mktemp -d failed"; exit 1; }
trap 'rm -rf "$tmpdir"' EXIT
cd "$tmpdir" || { echo "FAIL: cd $tmpdir failed"; exit 1; }

# Synced project at a "prior version": copy templates/, then alter ONE
# tracked file's content + write a manifest entry whose expected_sha256
# matches the user's altered content. This simulates: user is on an old
# version where this file had different (stock) content, manifest pinned
# that old hash; upstream now has a newer version of the file.
mkdir -p .sdd .claude
cp -R "$FRAMEWORK_ROOT/templates/.sdd/." .sdd/ 2>/dev/null
cp -R "$FRAMEWORK_ROOT/templates/.claude/." .claude/ 2>/dev/null

# Pick a target script the manifest tracks.
target=".sdd/scripts/advance.sh"
[ -f "$target" ] || { echo "FAIL: target script missing"; exit 1; }

# Replace target with prior content (a one-line stub).
echo '#!/usr/bin/env bash' > "$target"
echo '# old version' >> "$target"
chmod +x "$target"

# Compute normalised hash of the new (prior) content using the same
# algorithm sdd-migrate uses, then patch the user manifest so this
# target's expected_sha256 matches → user has stock prior content.
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
hash_val = sys.argv[1]
m = json.load(open('.sdd/.cache/manifest.json'))
m.setdefault('scripts', {})['advance.sh'] = {
  'expected_sha256': hash_val,
  'path': '.sdd/scripts/advance.sh',
  'trust': 'framework',
}
json.dump(m, open('.sdd/.cache/manifest.json', 'w'), indent=2)
PY

out=$(bash "$SCRIPT" --upstream="$FRAMEWORK_ROOT" 2>&1)
ec=$?

fails=()
[ "$ec" -eq 0 ] || fails+=("expected exit 0, got $ec")
printf '%s' "$out" | grep -qE '^\s*~ .sdd/scripts/advance.sh' \
  || fails+=("expected advance.sh in UPDATE-CLEAN list")
printf '%s' "$out" | grep -qE '^\s*! .sdd/scripts/advance.sh' \
  && fails+=("advance.sh wrongly appeared in UPDATE-CONFLICT")

if [ ${#fails[@]} -ne 0 ]; then
  echo "FAIL: AC3 — stock prior + newer upstream should be UPDATE-CLEAN"
  for f in "${fails[@]}"; do echo "  - $f"; done
  echo "  Output:"
  printf '%s\n' "$out" | sed 's/^/    /'
  exit 1
fi

echo "PASS: AC3 — stock prior content + newer upstream → UPDATE-CLEAN"
exit 0
