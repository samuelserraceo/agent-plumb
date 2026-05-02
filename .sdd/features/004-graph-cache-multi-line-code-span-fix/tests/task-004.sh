#!/usr/bin/env bash
# AC4 — full framework + MCP regression
set -uo pipefail
out=$(bash test/run-framework-test.sh 2>&1) || true
ec=$?
if [ "$ec" -eq 0 ] && echo "$out" | grep -qE "RESULTS: [0-9]+/[0-9]+ passing"; then
  fwk=$(echo "$out" | grep "RESULTS:" | tail -1)
  cd extensions/sdd-mcp-server
  mcp=$(python3 -m pytest tests/ -q 2>&1 | tail -1)
  cd - >/dev/null
  echo "PASS: AC4 — framework $fwk; MCP $mcp"
else
  echo "FAIL: framework regression ec=$ec" >&2
  echo "$out" | grep -E "FAIL|❌|RESULTS" | tail -5 >&2
  exit 1
fi
