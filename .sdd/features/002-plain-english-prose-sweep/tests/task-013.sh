#!/usr/bin/env bash
# spec: features/002-plain-english-prose-sweep §11.AC13 — ambiguous-tag refusal
set -uo pipefail
LINT=".sdd/scripts/lint-action-prose.sh"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/ambig.md" <<'A'
---
type: action
slug: ambig
tag: USER-LED, AGENT-LED
title: "Ambig"
---

x

**What it looks like:** y
A

out=$(bash "$LINT" "$TMP/ambig.md" 2>&1)
ec=$?
if [ "$ec" -eq 0 ]; then
  echo "FAIL: lint accepted ambiguous tag" >&2; exit 1
fi
if ! echo "$out" | grep -qi "ambiguous tag"; then
  echo "FAIL: lint error didn't mention 'ambiguous tag'. Output: $out" >&2; exit 1
fi
echo "PASS: AC13 — lint refuses ambiguous tag"
