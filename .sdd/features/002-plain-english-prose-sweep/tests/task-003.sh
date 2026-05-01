#!/usr/bin/env bash
# spec: features/002-plain-english-prose-sweep §11.AC3 — first-paragraph cap
# Test: short first paragraph passes; long first paragraph fails

set -uo pipefail

LINT=".sdd/scripts/lint-action-prose.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Fixture C — short first paragraph (≤2 sentences, ≤200 chars)
cat > "$TMP/c.md" <<'FIXC'
---
type: action
slug: fixture-c
tag: AGENT-LED
title: "Fixture C"
short_label: "FC"
steps:
  - { id: x, prompt: "y" }
used_by: [feature]
references: []
touches: []
trust: framework
budget: { max_minutes: 1, max_tokens: 100, max_commits: 1 }
requires_user_approval: false
---

What does this need to look like? Read what we know.

**What it looks like:** A concrete example.
FIXC

# Fixture D — long first paragraph (>200 chars)
cat > "$TMP/d.md" <<'FIXD'
---
type: action
slug: fixture-d
tag: AGENT-LED
title: "Fixture D"
short_label: "FD"
steps:
  - { id: x, prompt: "y" }
used_by: [feature]
references: []
touches: []
trust: framework
budget: { max_minutes: 1, max_tokens: 100, max_commits: 1 }
requires_user_approval: false
---

This is an excessively long first paragraph that violates the cap by deliberately exceeding two hundred characters in length so the lint should pick it up as a violation and emit a clear plain-English error message naming this file and the failing first-paragraph check.

**What it looks like:** A concrete example.
FIXD

# Fixture C — should pass
out_c=$(bash "$LINT" "$TMP/c.md" 2>&1)
ec_c=$?
if [ "$ec_c" -ne 0 ]; then
  echo "FAIL: lint flagged compliant short-paragraph fixture C: $out_c" >&2
  exit 1
fi

# Fixture D — should fail with first-paragraph error
out_d=$(bash "$LINT" "$TMP/d.md" 2>&1)
ec_d=$?
if [ "$ec_d" -eq 0 ]; then
  echo "FAIL: lint did NOT flag long-first-paragraph fixture D" >&2
  exit 1
fi
if ! echo "$out_d" | grep -q "$TMP/d.md"; then
  echo "FAIL: lint error didn't name the file. Output: $out_d" >&2
  exit 1
fi
if ! echo "$out_d" | grep -qi "first paragraph"; then
  echo "FAIL: lint error didn't name the failing check. Output: $out_d" >&2
  exit 1
fi

echo "PASS: AC3 — lint correctly enforces first-paragraph cap"
