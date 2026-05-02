#!/usr/bin/env bash
# AC2 — single-line code span still produces 0 edges (regression)
set -uo pipefail
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/.sdd/features/001-foo"
cat > "$TMP/.sdd/features/001-foo/spec.md" <<'F'
# foo

The token `[[pattern:fake]]` on a single line.

A real link: [[001-foo]].
F
cd extensions/sdd-mcp-server
out=$(python3 -c "
import sys; sys.path.insert(0, '.')
from queries import _graph_cache
graph = _graph_cache.build('$TMP')
edges = graph.get('edges', [])
fake_edges = [e for e in edges if e.get('raw') == 'pattern:fake']
print('fake_edges_count:', len(fake_edges))
" 2>&1)
cd - >/dev/null
if echo "$out" | grep -q "fake_edges_count: 0"; then
  echo "PASS: AC2 — single-line span still produces 0 phantom edges"
else
  echo "FAIL: $out" >&2; exit 1
fi
