#!/usr/bin/env bash
# T08: wireframe.md and edge-case-sweep.md frontmatter declare requires_user_approval: false
set -euo pipefail
ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../../.." && pwd )"
WIRE="$ROOT/templates/.sdd/actions/wireframe.md"
EDGE="$ROOT/templates/.sdd/actions/edge-case-sweep.md"

for f in "$WIRE" "$EDGE"; do
  [ -f "$f" ] || { echo "FAIL: $f missing"; exit 1; }
  if grep -qE '^requires_user_approval:\s+true' "$f"; then
    echo "FAIL: $f still declares requires_user_approval: true (must be false in v1.6 — technical/mechanical, no product judgement)"
    exit 1
  fi
  grep -qE '^requires_user_approval:\s+false' "$f" || { echo "FAIL: $f does not declare requires_user_approval: false explicitly"; exit 1; }
done
echo "PASS: T08 — wireframe + edge-case-sweep both declare requires_user_approval: false"
