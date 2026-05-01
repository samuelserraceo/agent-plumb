#!/usr/bin/env bash
# spec: features/002-plain-english-prose-sweep §11.AC2 — example block check
# Test: fixture A (with block) passes; fixture B (without block) flagged

set -uo pipefail

LINT=".sdd/scripts/lint-action-prose.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Fixture A — has the block
cat > "$TMP/a.md" <<'FIXA'
---
type: action
slug: fixture-a
tag: USER-LED
title: "Fixture A"
short_label: "FA"
steps:
  - { id: x, prompt: "y" }
used_by: [feature]
references: []
touches: []
trust: framework
budget: { max_minutes: 1, max_tokens: 100, max_commits: 1 }
requires_user_approval: false
---

Short opening question.

**What it looks like:** A concrete example.

(rest of body)
FIXA

# Fixture B — missing the block
cat > "$TMP/b.md" <<'FIXB'
---
type: action
slug: fixture-b
tag: USER-LED
title: "Fixture B"
short_label: "FB"
steps:
  - { id: x, prompt: "y" }
used_by: [feature]
references: []
touches: []
trust: framework
budget: { max_minutes: 1, max_tokens: 100, max_commits: 1 }
requires_user_approval: false
---

Short opening question.

(no example block here — should fail)
FIXB

# Run lint on A only — should pass
out_a=$(bash "$LINT" "$TMP/a.md" 2>&1)
ec_a=$?
if [ "$ec_a" -ne 0 ]; then
  echo "FAIL: lint flagged compliant fixture A: $out_a" >&2
  exit 1
fi

# Run lint on B only — should fail with stderr containing the file path
out_b=$(bash "$LINT" "$TMP/b.md" 2>&1)
ec_b=$?
if [ "$ec_b" -eq 0 ]; then
  echo "FAIL: lint did NOT flag non-compliant fixture B (missing example block)" >&2
  exit 1
fi
if ! echo "$out_b" | grep -q "$TMP/b.md"; then
  echo "FAIL: lint error didn't name the file. Output: $out_b" >&2
  exit 1
fi
if ! echo "$out_b" | grep -qi "What it looks like"; then
  echo "FAIL: lint error didn't name the failing check. Output: $out_b" >&2
  exit 1
fi

echo "PASS: AC2 — lint correctly flags missing **What it looks like:** block"
