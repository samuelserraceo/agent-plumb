#!/usr/bin/env bash
# AC3 — line numbers preserved after multi-line mask
set -uo pipefail
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/.sdd/features/001-foo"
# Real link is on line 7. A multi-line code span occupies lines 3-5.
cat > "$TMP/.sdd/features/001-foo/spec.md" <<'F'
# foo

This `[[pattern:fake]]
keeps going
across lines` is masked.

Real link [[001-foo]] on line 7.
F
cd extensions/sdd-mcp-server
out=$(python3 -c "
import sys; sys.path.insert(0, '.')
from queries import _graph_cache
graph = _graph_cache.build('$TMP')
edges = graph.get('edges', [])
real = [e for e in edges if e.get('raw') == '001-foo']
if real:
  print('line:', real[0].get('from_line'))
" 2>&1)
cd - >/dev/null
if echo "$out" | grep -q "line: 7"; then
  echo "PASS: AC3 — line number 7 preserved after masking"
else
  echo "FAIL: line number drifted — $out" >&2; exit 1
fi
