#!/usr/bin/env bash
# AC10 — full framework + MCP regression
set -uo pipefail
out=$(bash test/run-framework-test.sh 2>&1)
ec=$?
if [ "$ec" -ne 0 ] || ! echo "$out" | grep -qE "RESULTS: [0-9]+/[0-9]+ passing"; then
  echo "FAIL: framework regression ec=$ec" >&2
  echo "$out" | grep -E "FAIL|❌|RESULTS" | tail -5 >&2
  exit 1
fi
fwk=$(echo "$out" | grep "RESULTS:" | tail -1)

cd extensions/sdd-mcp-server || { echo "FAIL: cannot cd into MCP" >&2; exit 1; }
mcp_out=$(python3 -m pytest tests/ -q 2>&1)
mcp_ec=$?
cd - >/dev/null || { echo "FAIL: cd back failed" >&2; exit 1; }
if [ "$mcp_ec" -ne 0 ]; then
  echo "FAIL: MCP ec=$mcp_ec" >&2; echo "$mcp_out" | tail -10 >&2; exit 1
fi
echo "PASS: AC10 — framework $fwk; MCP $(echo "$mcp_out" | tail -1)"
