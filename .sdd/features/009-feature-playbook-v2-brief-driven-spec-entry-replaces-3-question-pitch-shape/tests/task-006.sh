#!/usr/bin/env bash
# T06: F010+ specs scaffold without §2
set -euo pipefail
ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../../.." && pwd )"

SCRATCH=$(mktemp -d)
trap 'rm -rf "$SCRATCH"' EXIT
mkdir -p "$SCRATCH/.sdd/playbooks" "$SCRATCH/.sdd/actions" "$SCRATCH/.sdd/features" "$SCRATCH/.sdd/scripts"
cp "$ROOT"/templates/.sdd/playbooks/feature.md "$SCRATCH/.sdd/playbooks/"
cp "$ROOT"/templates/.sdd/actions/*.md "$SCRATCH/.sdd/actions/"
cp "$ROOT"/templates/.sdd/scripts/*.sh "$SCRATCH/.sdd/scripts/" 2>/dev/null || true
cp "$ROOT"/templates/.sdd/config.md "$SCRATCH/.sdd/"
cat > "$SCRATCH/.sdd/INDEX.md" <<INDEXEOF
# INDEX
**Active:**
**Playbook:** feature
**Active blocker:**

## In flight

(none)

## Shipped

INDEXEOF

cd "$SCRATCH"
bash "$ROOT/.sdd/scripts/start.sh" "T06 scaffold smoke test" >/dev/null 2>&1 || { echo "FAIL: start.sh failed"; exit 1; }

SCAFFOLD_SPEC=$(find "$SCRATCH/.sdd/features/" -name "spec.md" -type f | head -1)
[ -f "$SCAFFOLD_SPEC" ] || { echo "FAIL: scaffolded spec.md not found"; exit 1; }

if grep -q "^### action: success" "$SCAFFOLD_SPEC"; then
  echo "FAIL: scaffold contains '### action: success' — should be removed in v1.6"
  exit 1
fi

if ! grep -q "^### action: brief-intake" "$SCAFFOLD_SPEC"; then
  echo "FAIL: scaffold missing '### action: brief-intake'"
  exit 1
fi

echo "PASS: T06 — F010+ scaffold has brief-intake, NO success"
