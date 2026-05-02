#!/usr/bin/env bash
# AC1 — multi-line backtick span containing [[pattern:fake]] produces 0 edges
set -uo pipefail
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

# Build a fixture project with a multi-line code span containing a wiki-link
mkdir -p "$TMP/.sdd/features/001-foo"
cat > "$TMP/.sdd/features/001-foo/spec.md" <<'F'
# foo

This `[[pattern:fake]]
keeps going
across lines` is inside a multi-line code span.

Also a real link: [[001-foo]] on its own line.
F

cd extensions/sdd-mcp-server
out=$(python3 -c "
import sys, os
sys.path.insert(0, '.')
from queries import _graph_cache
graph = _graph_cache.build('$TMP')
edges = graph.get('edges', [])
fake_edges = [e for e in edges if e.get('raw') == 'pattern:fake']
print('fake_edges_count:', len(fake_edges))
print('total_edges:', len(edges))
" 2>&1)
ec=$?
cd - >/dev/null

if [ "$ec" -ne 0 ]; then
  echo "FAIL: graph build crashed: $out" >&2
  exit 1
fi

if echo "$out" | grep -q "fake_edges_count: 0"; then
  echo "PASS: AC1 — multi-line span produces 0 phantom edges ($out)"
else
  echo "FAIL: phantom edge from multi-line code span — $out" >&2
  exit 1
fi
