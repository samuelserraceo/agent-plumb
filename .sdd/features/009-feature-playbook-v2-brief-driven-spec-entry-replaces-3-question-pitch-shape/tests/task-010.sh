#!/usr/bin/env bash
# T10: data-contract.md prose includes upload-invitation + format list + failure path
set -euo pipefail
ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../../.." && pwd )"
ACTION="$ROOT/templates/.sdd/actions/data-contract.md"
[ -f "$ACTION" ] || { echo "FAIL: $ACTION missing"; exit 1; }

# Upload invitation
grep -qiE "drop a (Google Sheets|spreadsheet|schema dump)" "$ACTION" || { echo "FAIL: upload-invitation prose missing"; exit 1; }
# Format list (at least 4 of these tokens)
formats=0
for fmt in markdown CSV JSON "plain text" PDF screenshot; do
  if grep -qi "$fmt" "$ACTION"; then formats=$((formats+1)); fi
done
[ "$formats" -ge 4 ] || { echo "FAIL: only $formats format names found in data-contract; need ≥4"; exit 1; }
# Failure path
grep -qiE "(unsupported|format error|can't read|failed to parse)" "$ACTION" || { echo "FAIL: failure-path prose missing"; exit 1; }
echo "PASS: T10 — data-contract has upload-invitation + format list + failure path"
