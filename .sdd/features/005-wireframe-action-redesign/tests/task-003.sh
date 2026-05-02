#!/usr/bin/env bash
set -uo pipefail
F="templates/.sdd/actions/wireframe.md"
grep -qF '**What it looks like:**' "$F" || { echo "FAIL: example block missing" >&2; exit 1; }
echo "PASS: AC3 — **What it looks like:** block lands"
