#!/usr/bin/env bash
# AC4 — full framework + MCP regression
# CR cycle 1: drop `|| true` (was forcing ec=0 and masking failures);
# capture both framework + pytest exit codes separately so neither is
# silenced by the other.
set -uo pipefail
out=$(bash test/run-framework-test.sh 2>&1)
ec=$?
if [ "$ec" -ne 0 ] || ! echo "$out" | grep -qE "RESULTS: [0-9]+/[0-9]+ passing"; then
  echo "FAIL: framework regression ec=$ec" >&2
  echo "$out" | grep -E "FAIL|❌|RESULTS" | tail -5 >&2
  exit 1
fi
fwk=$(echo "$out" | grep "RESULTS:" | tail -1)

cd extensions/sdd-mcp-server
mcp_out=$(python3 -m pytest tests/ -q 2>&1)
mcp_ec=$?
cd - >/dev/null
if [ "$mcp_ec" -ne 0 ]; then
  echo "FAIL: MCP regression ec=$mcp_ec" >&2
  echo "$mcp_out" | tail -10 >&2
  exit 1
fi
mcp_summary=$(echo "$mcp_out" | tail -1)
echo "PASS: AC4 — framework $fwk; MCP $mcp_summary"
