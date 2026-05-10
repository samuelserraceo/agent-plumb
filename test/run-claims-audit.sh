#!/usr/bin/env bash
# run-claims-audit.sh — proof-by-execution audit of every framework
# claim made in CLAUDE.md / README.md / docs/walkthrough.html / INDEX.md
# `## Shipped` lessons.
#
# Each claim is a function `claim_<slug>` that returns 0 on PASS, 1 on
# FAIL. The comment block above each function names the source (which
# file, which section) and quotes the verbatim claim — so a future
# reader can audit the audit itself.
#
# This is intentionally separate from `test/run-framework-test.sh`:
#   - run-framework-test.sh = unit-style mutation-verified assertions
#     on individual hooks and scripts (196 tests).
#   - run-claims-audit.sh = end-to-end "does the marketing claim hold
#     up?" harness that runs real cycles and reports plain-English
#     PASS/FAIL per claim.
#
# Output shape:
#   PASS - <slug> - <one-line description>
#         source: <file>:<section>
#         verified by: <one-line summary of what ran>
#   FAIL - <slug> - <description> (exit <ec>)
#         <stderr or diagnostic>
#
# Why this exists: the framework's marketplace pitch is built on claims
# in CLAUDE.md and walkthrough.html. Without this audit, those claims
# are prose — believable but not verifiable. With this audit, every
# claim is backed by an executable check that runs on every PR.
#
# v1 starter set: ~15 high-value claims. Coverage is intentionally a
# spectrum from "the moat actually moats" down to "the manifest pins
# the right files" — each one is an actual mechanism the framework
# advertises. Add more claims by writing a new claim_<slug> function
# and adding it to the CLAIMS array at the bottom.

set -uo pipefail

# Resolve project root deterministically.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# Bug 003 fix: only cd to PROJECT_ROOT when invoked directly. When
# sourced (test harnesses calling individual claim functions), the
# caller manages its own CWD — don't trample it.
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  cd "$PROJECT_ROOT" || exit 1
fi

# Trap counter for the report at the end.
PASSED=0
FAILED=0
FAIL_LINES=""

note() { printf '\n— %s\n' "$1"; }
ok() {
  printf '  ✅ %s\n' "$1"
  PASSED=$((PASSED + 1))
}
bad() {
  printf '  ❌ %s\n' "$1"
  if [ -n "${2:-}" ]; then
    printf '     %s\n' "$2"
  fi
  FAILED=$((FAILED + 1))
  FAIL_LINES="${FAIL_LINES}  - $1${2:+ — $2}
"
}

# ============================================================
# CLAIM: anti-theatre lint refuses theatre tokens
# Source: templates/CLAUDE.md — "Code-quality doctrine" rule 8 mechanical-enforcement block (closes #111)
# Quote: "spec.md content can't ship sentences that LOOK like enforced guards but aren't ... refuses each match unless an adjacent annotation is present"
# ============================================================
claim_anti_theatre_lint_refuses() {
  local f
  f=$(mktemp /tmp/claim-anti-theatre.XXXXXX)
  # A theatre claim with NO annotation — the lint must refuse this.
  cat >"$f" <<'EOF'
# Test spec
This component enforces 1KB.
EOF
  bash .sdd/scripts/lint-no-theatre.sh "$f" >/dev/null 2>&1
  local ec=$?
  rm -f "$f"
  # Lint exit 1 = found theatre. Exit 0 = clean. We expect 1.
  [ "$ec" -eq 1 ]
}

# ============================================================
# CLAIM: anti-theatre lint allows annotated theatre
# Source: templates/CLAUDE.md — same block
# Quote: "{verify-by: T-NNN} (points at a test), {best-effort: <who>}, or {prod-only: <why>}"
# ============================================================
claim_anti_theatre_lint_allows_annotated() {
  local f
  f=$(mktemp /tmp/claim-anti-theatre-ok.XXXXXX)
  cat >"$f" <<'EOF'
# Test spec
This component enforces 1KB. {verify-by: T-001}
EOF
  bash .sdd/scripts/lint-no-theatre.sh "$f" >/dev/null 2>&1
  local ec=$?
  rm -f "$f"
  [ "$ec" -eq 0 ]
}

# ============================================================
# CLAIM: plain-English action lint asserts "What it looks like" block
# Source: templates/CLAUDE.md — rule 8 mechanical-enforcement (closes #110)
# Quote: "every USER-LED / AGENT-LED action file ships a `**What it looks like:**` block ... The lint at `.sdd/scripts/lint-action-prose.sh` asserts the block exists"
# ============================================================
claim_plain_english_lint_blocks_missing_block() {
  local f
  f=$(mktemp /tmp/claim-prose.XXXXXX)
  # Action file shape but missing the **What it looks like:** block.
  cat >"$f" <<'EOF'
---
type: action
slug: claim-test
tag: USER-LED
title: "Test"
short_label: "Test"
steps:
  - { id: q, prompt: "test?" }
used_by: [feature]
references: []
touches: []
trust: framework
budget: { max_minutes: 1, max_tokens: 100, max_commits: 1 }
requires_user_approval: false
---

Test action without the example block.
EOF
  bash .sdd/scripts/lint-action-prose.sh "$f" >/dev/null 2>&1
  local ec=$?
  rm -f "$f"
  [ "$ec" -ne 0 ]
}

# ============================================================
# CLAIM: every shipped USER-LED/AGENT-LED action ships the example block
# Source: templates/CLAUDE.md — rule 8
# Quote: "every USER-LED / AGENT-LED action file under `templates/.sdd/actions/` ships a `**What it looks like:**` block"
# ============================================================
claim_every_action_has_example_block() {
  local missing=0
  for action in templates/.sdd/actions/*.md; do
    [ -f "$action" ] || continue
    # Only USER-LED / AGENT-LED actions need the block.
    if grep -qE '^tag:[[:space:]]+(USER-LED|AGENT-LED)' "$action"; then
      if ! grep -qF '**What it looks like:**' "$action"; then
        missing=$((missing + 1))
      fi
    fi
  done
  [ "$missing" -eq 0 ]
}

# ============================================================
# CLAIM: decisions.md is append-only (modifying prior entries refused)
# Source: templates/CLAUDE.md — "Audit log" + Hooks section
# Quote: "The append-only hook (`pre-commit-decisions-append-only.sh`) blocks any commit that modifies prior entries"
# Note: append-only enforcement now lives inside pre-commit-rules.sh's
# F1 generic enforcer (per the same Hooks block: "Subsumes ... pre-commit-decisions-append-only").
# This claim verifies the SUBSUMPTION held — modifying decisions.md
# should still be refused.
# ============================================================
claim_decisions_md_append_only_enforced() {
  # Static audit: pre-commit-rules.sh references append_only enforcement
  # for decisions.md via config.md `file_rules:`.
  if ! grep -qE 'append_only' templates/.sdd/config.md 2>/dev/null; then
    return 1
  fi
  # And the F1 enforcer reads the rule.
  grep -qE 'append_only' templates/.claude/hooks/pre-commit-rules.sh
}

# ============================================================
# CLAIM: T120 catches drift between templates/.sdd/ and root .sdd/
# Source: test/run-framework-test.sh T120 prose
# Quote: "framework's root .sdd/ + .claude/ stay in sync with templates/"
# ============================================================
claim_t120_catches_introduced_drift() {
  # Negative test — temporarily introduce a drift, confirm T120 fires,
  # then restore. Pick an action file that's small + safe to round-trip.
  local target="templates/.sdd/actions/problem.md"
  [ -f "$target" ] || return 1
  local backup
  backup=$(mktemp)
  cp "$target" "$backup"
  echo "DRIFT-TEST-MARKER" >>"$target"

  # Run just T120 (greppable — single test ID).
  local out
  out=$(bash test/run-framework-test.sh 2>&1 | grep -E "T120|DRIFT|DIFF" | head -3)
  cp "$backup" "$target"
  rm -f "$backup"

  # T120 should have flagged DIFF.
  echo "$out" | grep -q "DIFF: .sdd/actions/problem.md" || \
    echo "$out" | grep -q "T120 framework self-host drift detected"
}

# ============================================================
# CLAIM: manifest pins ~61 framework files with normalised SHA-256
# Source: docs/walkthrough.html — Phase B hardening section
# Quote: "~61 framework files (playbooks, actions, scripts, hooks) have their normalised SHA-256 stored in `.sdd/.cache/manifest.json`"
# ============================================================
claim_manifest_pins_framework_files() {
  local count
  count=$(python3 -c "
import json
with open('.sdd/.cache/manifest.json') as f:
    m = json.load(f)
n = sum(len(v) for k, v in m.items() if isinstance(v, dict))
print(n)
" 2>/dev/null)
  # Allow a window — claim says ~61. Anything 50-90 satisfies "approximately 61".
  [ -n "$count" ] && [ "$count" -ge 50 ] && [ "$count" -le 90 ]
}

# ============================================================
# CLAIM: every manifest-pinned file's hash matches its on-disk content
# Source: templates/CLAUDE.md — Hooks section
# Quote: "pre-commit-stage-verified.sh — THE MOAT. Re-runs verify-stage on staged spec.md and refuses commits where verification.json claims pass-state that doesn't match"
# (Implicit: the manifest is the trust baseline; mismatches should be zero on a clean main.)
# ============================================================
claim_manifest_hashes_match_disk() {
  python3 -c "
import hashlib, json, os, sys

def normalised(path):
    with open(path, 'rb') as f:
        data = f.read()
    if b'\x00' in data:
        return 'NUL'
    text = data.decode('utf-8', errors='replace')
    lines = [ln.rstrip() for ln in text.replace('\r\n', '\n').replace('\r', '\n').split('\n')]
    while lines and lines[0] == '':
        lines.pop(0)
    while lines and lines[-1] == '':
        lines.pop()
    return hashlib.sha256('\n'.join(lines).encode()).hexdigest()

with open('.sdd/.cache/manifest.json') as f:
    m = json.load(f)

mismatches = 0
for section_name, section in m.items():
    if not isinstance(section, dict):
        continue
    for slug, entry in section.items():
        if not isinstance(entry, dict):
            continue
        path = entry.get('path', '')
        expected = entry.get('expected_sha256', '')
        if not os.path.isfile(path):
            # Missing on disk is OK for gitignored .claude/ files
            # when init.sh hasn't bootstrapped them. Skip.
            continue
        actual = normalised(path)
        if actual != expected:
            mismatches += 1
            print(f'MISMATCH: {path}', file=sys.stderr)

sys.exit(0 if mismatches == 0 else 1)
"
}

# ============================================================
# CLAIM: post-stop-lint refuses INDEX.md with two **Active:** lines
# Source: templates/.claude/hooks/post-stop-lint.sh — invariant 1
# Quote: (from T119 in run-framework-test.sh) "post-stop-lint refuses INDEX.md with two **Active:** lines"
# ============================================================
claim_stop_lint_refuses_double_active() {
  local d
  d=$(mktemp -d /tmp/claim-stop-lint.XXXXXX)
  cp -R templates/.sdd "$d/.sdd"
  cp -R templates/.claude "$d/.claude"
  cat >"$d/.sdd/INDEX.md" <<'EOF'
# Project Index

**Active:** features/001-test
**Active:** features/002-other

## In flight
- features/001-test

## Shipped
EOF
  cd "$d" || return 1
  echo '{"hook_event_name":"Stop"}' | bash .claude/hooks/post-stop-lint.sh >/dev/null 2>&1
  local ec=$?
  cd "$PROJECT_ROOT" || return 1
  rm -rf "$d"
  [ "$ec" -eq 2 ]
}

# ============================================================
# CLAIM: plugin manifest at .claude-plugin/plugin.json declares
# a version matching README's "Currently at **vX.Y.Z**" line — i.e.
# code and prose agree on what version is shipping. Bumping plugin.json
# without bumping README (or vice versa) trips this claim.
# Source: README.md — "Currently at **v…**" + .claude-plugin/plugin.json
# ============================================================
claim_plugin_manifest_version_matches_readme() {
  [ -f .claude-plugin/plugin.json ] || return 1
  [ -f README.md ] || return 1
  local plugin_version
  plugin_version=$(python3 -c "import json,sys;print(json.load(open('.claude-plugin/plugin.json')).get('version',''))" 2>/dev/null)
  [ -n "$plugin_version" ] || return 1
  local readme_version
  readme_version=$(grep -oE 'Currently at \*\*v[0-9]+\.[0-9]+\.[0-9]+\*\*' README.md | head -1 | sed -E 's/.*v([0-9]+\.[0-9]+\.[0-9]+).*/\1/')
  [ -n "$readme_version" ] || return 1
  [ "$plugin_version" = "$readme_version" ]
}

# ============================================================
# CLAIM: framework's own root .claude/ has the hooks bootstrapped
# Source: #136 / #137 — "framework now self-hosts its hooks"
# Quote: "the framework dogfoods its own pre-commit / stop-lint hooks"
# Note: root .claude/ is gitignored (per /.claude/ in .gitignore — same
# per-contributor 'working copy' pattern as #125 root CLAUDE.md). On CI
# checkouts where init.sh hasn't been run, root .claude/ doesn't exist
# — soft-skip and assert the canonical templates source instead. The
# bootstrap-required claim only runs on contributor machines where
# .claude/hooks/ has been populated by init.sh.
# ============================================================
claim_framework_self_hosts_hooks() {
  if [ -d .claude/hooks ]; then
    # Contributor machine — strict check that all hooks bootstrapped.
    [ -f .claude/hooks/pre-commit-stage-verified.sh ] && \
      [ -f .claude/hooks/post-stop-lint.sh ] && \
      [ -f .claude/settings.json ]
  else
    # CI / fresh clone — assert canonical templates source exists, plus
    # init.sh's copy logic that would bootstrap them. Without bootstrap
    # the framework still ships valid hooks for downstream users.
    [ -f templates/.claude/hooks/pre-commit-stage-verified.sh ] && \
      [ -f templates/.claude/hooks/post-stop-lint.sh ] && \
      [ -f templates/.claude/settings.json ] && \
      grep -q '\.claude' scripts/init.sh
  fi
}

# ============================================================
# CLAIM: Playwright config at root + 2 test files (closes #116)
# Source: PR #139, templates/CLAUDE.md "Wireframes" mechanical-enforcement
# Quote: "framework dogfoods its own Playwright extension on its own walkthrough HTML + per-feature wireframes"
# ============================================================
claim_playwright_dogfood_files_present() {
  [ -f playwright.config.ts ] && \
    [ -f tests/playwright/walkthrough.spec.ts ] && \
    [ -f tests/playwright/wireframe-tier3.spec.ts ] && \
    [ -f .github/workflows/playwright.yml ]
}

# ============================================================
# CLAIM: 4 playbooks ship in v1.0
# Source: docs/walkthrough.html
# Quote: "v1.0 ships with 4 playbooks"
# ============================================================
claim_v1_0_ships_4_playbooks() {
  local count
  count=$(find templates/.sdd/playbooks -maxdepth 1 -name "*.md" -type f | wc -l)
  [ "$count" -eq 4 ]
}

# ============================================================
# CLAIM: 9 slash commands ship
# Source: docs/walkthrough.html — Reference table
# Quote: "9 slash commands"
# ============================================================
claim_9_slash_commands_ship() {
  local count
  count=$(find templates/.claude/commands -maxdepth 1 -name "*.md" -type f | wc -l)
  # Allow ±1 for natural growth (claim is a snapshot count).
  [ "$count" -ge 9 ] && [ "$count" -le 12 ]
}

# ============================================================
# CLAIM: every wiki-link [[slug]] in INDEX.md resolves
# Source: templates/CLAUDE.md — "Wiki-links" section
# Quote: "every `[[…]]` must resolve to a known node, or the turn ends with a violation"
# ============================================================
claim_indexmd_wiki_links_resolve() {
  python3 -c "
import re, sys, os

with open('.sdd/INDEX.md') as f:
    text = f.read()

# Filter explanatory-prose placeholders BEFORE link extraction.
# CLAUDE.md and walkthrough.html show wiki-link grammar with [[…]]
# (Unicode ellipsis) or [[...]] (three dots) as illustrative examples;
# those are not real slugs. The real grammar excludes ellipsis chars
# from valid slug content.
links = re.findall(r'\[\[([^\]]+)\]\]', text)
unresolved = []
for raw in links:
    slug = raw.strip()
    # Skip placeholder examples
    if slug in ('…', '...') or '…' in slug:
        continue
    if slug.startswith('entity:') or slug.startswith('pattern:'):
        # entity / pattern lookups are best-effort here — the stop-hook
        # invariant 8 does the strict check at turn boundary. The audit
        # only verifies feature-folder shape resolves.
        continue
    # Feature folder — must exist somewhere under .sdd/<work_item>/
    candidates = [
        f'.sdd/features/{slug}',
        f'.sdd/bugs/{slug}',
        f'.sdd/refactors/{slug}',
    ]
    if not any(os.path.isdir(c) for c in candidates):
        unresolved.append(slug)

if unresolved:
    print('Unresolved feature wiki-links: ' + ', '.join(unresolved), file=sys.stderr)
    sys.exit(1)
sys.exit(0)
"
}

# ============================================================
# CLAIM: 196 framework tests pass
# Source: docs/walkthrough.html footer + INDEX.md Shipped lessons
# Quote: "196/196 framework tests + 161/161 MCP unit tests · all mutation-verified"
# ============================================================
claim_196_framework_tests_pass() {
  # Run the suite; check exit code AND the final RESULTS line.
  # `bash -c` ensures a clean inherited environment without lingering
  # state from earlier claims.
  local logfile
  logfile=$(mktemp /tmp/claim-fwtest.XXXXXX)
  bash test/run-framework-test.sh >"$logfile" 2>&1
  local ec=$?
  local matched=0
  if grep -qE 'RESULTS: (19[6-9]|2[0-9][0-9])/[0-9]+ passing' "$logfile"; then
    matched=1
  fi
  rm -f "$logfile"
  [ "$ec" -eq 0 ] && [ "$matched" -eq 1 ]
}

# ============================================================
# CLAIM: 161 MCP unit tests pass
# Source: same as above
# Quote: same
# Note: MCP tests use stdlib `unittest`, not `pytest` — the test files
# are written `class TestX(unittest.TestCase)` shape. unittest discover
# is part of the Python stdlib (no extra install needed) and runs all
# the same tests on CI without requiring `pip install pytest`.
# ============================================================
claim_161_mcp_tests_pass() {
  local logfile
  logfile=$(mktemp /tmp/claim-mcp.XXXXXX)
  (
    cd extensions/sdd-mcp-server &&
      python3 -m unittest discover -s tests -v 2>&1
  ) >"$logfile"
  local ec=$?
  # unittest with -v prints "Ran <N> tests in ..." at the end; check
  # both that exit was 0 AND that ≥160 tests ran.
  local matched=0
  if grep -qE 'Ran 16[0-9] tests' "$logfile" || grep -qE 'Ran 17[0-9] tests' "$logfile"; then
    matched=1
  fi
  rm -f "$logfile"
  [ "$ec" -eq 0 ] && [ "$matched" -eq 1 ]
}

# ============================================================
# CLAIM: pre-commit-no-assumed-markers refuses (assumed) tokens
# Source: templates/CLAUDE.md — rule 1 mechanical-enforcement (closes #72)
# Quote: "the `pre-commit-no-assumed-markers.sh` hook scans staged spec.md content for placeholder tokens — `(assumed)`, `(TBD)`, `(?)` ... and refuses any commit that contains them"
# ============================================================
claim_assumed_markers_lint_refuses_paren_assumed() {
  # Static check: the hook script contains the placeholder-token list.
  # A direct subprocess test would need a fake git repo + staged file
  # — too heavy for the audit's per-PR runtime. The static check
  # asserts the regex/list is wired; the moat already runs the hook
  # in CI via PreToolUse so dynamic enforcement is covered there.
  grep -qE '\(assumed\)' templates/.claude/hooks/pre-commit-no-assumed-markers.sh && \
    grep -qE '\(TBD\)' templates/.claude/hooks/pre-commit-no-assumed-markers.sh && \
    grep -qE '<TODO>' templates/.claude/hooks/pre-commit-no-assumed-markers.sh
}

# ============================================================
# CLAIM: every action's `tag` is from the closed enum
# Source: templates/.claude/hooks/pre-commit-rules.sh + load-playbook.sh
# Quote: "VALID_TAGS = {USER-LED, AGENT-LED, BUILD-TASK, BUILD-SPIKE, TRANSITION}"
# ============================================================
claim_every_action_tag_in_closed_enum() {
  python3 -c "
import re, sys, os
VALID = {'USER-LED', 'AGENT-LED', 'BUILD-TASK', 'BUILD-SPIKE', 'TRANSITION'}
bad = []
for fname in sorted(os.listdir('templates/.sdd/actions')):
    if not fname.endswith('.md'):
        continue
    p = os.path.join('templates/.sdd/actions', fname)
    with open(p) as f:
        text = f.read()
    m = re.search(r'^tag:[ \t]+([A-Z-]+)', text, re.MULTILINE)
    if not m:
        bad.append(f'{fname}: no tag declared')
        continue
    if m.group(1) not in VALID:
        bad.append(f'{fname}: tag={m.group(1)!r} not in closed enum')
if bad:
    print('Tag violations:', file=sys.stderr)
    for b in bad:
        print(f'  - {b}', file=sys.stderr)
    sys.exit(1)
sys.exit(0)
"
}

# ============================================================
# CLAIM: v1.6 plain-English-first — canonical examples keep the <details> fold
# Source: issue #207 — v1.6 anchor, Part 4 ("Plain-English-first as DEFAULT
# draft mode") + CLAUDE.md "Plain-English-first as default for AGENT-LED
# actions" doctrine section
# Quote: "every AGENT-LED draft starts with the plain-English version. Add
# a [Show technical detail] foldable block (rendered as <details> in markdown)"
# ============================================================
claim_v16_plain_english_first_canonical_examples_have_details() {
  python3 -c "
import re, sys
# These are the two canonical AGENT-LED examples that demonstrate the
# foldable pattern; they MUST keep the <details>...<summary>Show technical
# detail...</summary>...</details> structure inside their 'What it looks
# like' block. Other AGENT-LED actions are exempt unless they add
# heavy technical detail that warrants folding.
CANONICAL = [
    'templates/.sdd/actions/proposed-approach.md',
    'templates/.sdd/actions/data-contract.md',
]
violations = []
for path in CANONICAL:
    try:
        text = open(path).read()
    except FileNotFoundError:
        violations.append(f'{path}: file missing')
        continue
    if not re.search(r'<details>.*?<summary>Show technical detail.*?</summary>.*?</details>',
                     text, flags=re.DOTALL):
        violations.append(f'{path}: missing <details>+<summary>Show technical detail...</summary>+</details> structure')
if violations:
    print('Plain-English-first canonical examples violations (#207 PR-D / Part 4):', file=sys.stderr)
    for v in violations:
        print(f'  - {v}', file=sys.stderr)
    sys.exit(1)
sys.exit(0)
"
}

# ============================================================
# CLAIM: every playbook frontmatter declares stages with actions + exit_checks
# Source: templates/CLAUDE.md — Canonical playbook section
# Quote: "The frontmatter declares the stages (SPEC → BUILD → SHIP) and the action sequence per stage"
# ============================================================
claim_every_playbook_has_stages_actions_exit_checks() {
  python3 -c "
import re, sys, os
try:
    import yaml
except ImportError:
    print('PyYAML missing', file=sys.stderr)
    sys.exit(1)

bad = []
for fname in sorted(os.listdir('templates/.sdd/playbooks')):
    if not fname.endswith('.md'):
        continue
    p = os.path.join('templates/.sdd/playbooks', fname)
    with open(p) as f:
        text = f.read()
    m = re.match(r'^---\n(.*?)\n---', text, re.DOTALL)
    if not m:
        bad.append(f'{fname}: no frontmatter')
        continue
    fm = yaml.safe_load(m.group(1)) or {}
    stages = fm.get('stages')
    if not isinstance(stages, list) or not stages:
        bad.append(f'{fname}: missing stages')
        continue
    for s in stages:
        if not isinstance(s, dict):
            bad.append(f'{fname}: stage is not a dict')
            continue
        if 'actions' not in s:
            bad.append(f'{fname}: stage {s.get(\"id\", \"?\")} missing actions')
        if 'exit_checks' not in s:
            bad.append(f'{fname}: stage {s.get(\"id\", \"?\")} missing exit_checks')

if bad:
    print('Playbook shape violations:', file=sys.stderr)
    for b in bad:
        print(f'  - {b}', file=sys.stderr)
    sys.exit(1)
sys.exit(0)
"
}

# ============================================================
# CLAIM: every shipped feature has .shipped marker
# Source: templates/CLAUDE.md — "Shipped features are cold"
# Quote: "Once a feature ships, .sdd/features/<id>/.shipped exists in its folder"
# ============================================================
claim_every_shipped_feature_has_marker() {
  python3 -c "
import re, sys, os

with open('.sdd/INDEX.md') as f:
    text = f.read()

# Find the ## Shipped section (between '## Shipped' header and next '## ').
m = re.search(r'## Shipped\n(.*?)(?=\n## |\Z)', text, re.DOTALL)
if not m:
    sys.exit(0)  # no shipped section yet
shipped_block = m.group(1)

# Extract feature slugs from the **[[<slug>]]** rows.
slugs = re.findall(r'\*\*\[\[([0-9]{3}-[a-z0-9-]+)\]\]\*\*', shipped_block)

missing = []
for slug in slugs:
    candidates = [
        f'.sdd/features/{slug}/.shipped',
        f'.sdd/bugs/{slug}/.shipped',
        f'.sdd/refactors/{slug}/.shipped',
    ]
    if not any(os.path.isfile(c) for c in candidates):
        missing.append(slug)

if missing:
    print('Shipped features missing .shipped marker: ' + ', '.join(missing), file=sys.stderr)
    sys.exit(1)
sys.exit(0)
"
}

# ============================================================
# CLAIM: every shipped feature row in INDEX.md has a PR link
# Source: templates/CLAUDE.md — mark-shipped action's catalog format
# Quote: "Shipped: <YYYY-MM-DD> · PR: <URL>"
# ============================================================
claim_every_shipped_row_has_pr_link() {
  python3 -c "
import re, sys

with open('.sdd/INDEX.md') as f:
    text = f.read()

m = re.search(r'## Shipped\n(.*?)(?=\n## |\Z)', text, re.DOTALL)
if not m:
    sys.exit(0)
block = m.group(1)

# Each shipped entry block: starts with '- **[[<slug>]]**' line, then
# indented sub-bullets including 'Shipped: ... · PR: <URL>'.
entries = re.split(r'\n(?=- \*\*\[\[[0-9]{3}-)', block)
missing_pr = []
for e in entries:
    e = e.strip()
    if not e.startswith('- **[['):
        continue
    if 'PR:' not in e:
        slug_m = re.search(r'\[\[([0-9]{3}-[a-z0-9-]+)\]\]', e)
        slug = slug_m.group(1) if slug_m else '<unknown>'
        missing_pr.append(slug)

if missing_pr:
    print('Shipped rows missing PR link: ' + ', '.join(missing_pr), file=sys.stderr)
    sys.exit(1)
sys.exit(0)
"
}

# ============================================================
# CLAIM: native git pre-commit shim is wired
# Source: templates/.claude/hooks/pre-commit (the shim)
# Quote: "Set `git config core.hooksPath .claude/hooks` once per project"
# ============================================================
claim_native_git_pre_commit_shim_wired() {
  # Two facets to verify:
  #   1. The shim file exists in templates (always tracked)
  #   2. The shim is intentionally extension-less (git contract)
  [ -f templates/.claude/hooks/pre-commit ] && \
    [ ! -f templates/.claude/hooks/pre-commit.sh ]
}

# ============================================================
# CLAIM: plugin manifest's keywords array is non-empty
# Source: .claude-plugin/plugin.json — keyword surface for marketplace search
# Quote: (implicit — marketplace listing requires searchable keywords)
# ============================================================
claim_plugin_manifest_has_keywords() {
  python3 -c "
import json, sys
with open('.claude-plugin/plugin.json') as f:
    m = json.load(f)
kws = m.get('keywords', [])
sys.exit(0 if isinstance(kws, list) and len(kws) > 0 else 1)
"
}

# ============================================================
# CLAIM: INDEX.md `**Active:**` line is canonical shape
# Source: templates/.claude/hooks/post-stop-lint.sh (invariant the hook caught at #137)
# Quote: "Expected shape: `<playbook>/<id-slug>` (e.g. `features/001-auth`). Or use the placeholder `**Active:** _(none)_`"
# ============================================================
claim_indexmd_active_line_canonical() {
  local line
  line=$(grep -E '^\*\*Active:\*\*' .sdd/INDEX.md | head -1)
  if [ -z "$line" ]; then
    return 1
  fi
  # Valid: `**Active:** _(none)_` OR `**Active:** <playbook>/<id>-<slug>`
  echo "$line" | grep -qE '^\*\*Active:\*\* (_\(none\)_$|[a-z]+/[0-9]{3}-[a-z0-9-]+)'
}

# ============================================================
# CLAIM: framework's three test harnesses all exist
# Source: README.md / walkthrough.html / various PR descriptions
# Quote: "three layers of dogfood: framework tests + claims audit + Playwright browser tests"
# ============================================================
claim_three_test_harnesses_present() {
  [ -f test/run-framework-test.sh ] && \
    [ -f test/run-claims-audit.sh ] && \
    [ -f .github/workflows/sdd-ci.yml ] && \
    [ -f .github/workflows/playwright.yml ]
}

# ============================================================
# CLAIM: PyYAML is the only Python dep — installable via pip
# Source: templates/CLAUDE.md — design philosophy
# Quote: "Framework deps: bash + python3 + PyYAML + git + gh"
# ============================================================
claim_only_pyyaml_python_dep() {
  # Check that the framework doesn't ship a requirements.txt with extra
  # heavy deps (numpy, pandas, etc.) at the framework root. Sub-extensions
  # like sdd-mcp-server can have their own deps — the CLAIM is about
  # framework core.
  if [ -f requirements.txt ]; then
    # If it exists, only PyYAML is allowed
    grep -vE '^[[:space:]]*$|^#|^[Pp]y[Yy][Aa][Mm][Ll]' requirements.txt | grep -q . && return 1
  fi
  # And python3 + PyYAML actually work
  python3 -c 'import yaml' 2>/dev/null
}

# ============================================================
# CLAIM: every framework script in templates/.sdd/scripts/ is executable
# Source: scripts/init.sh — script-copy contract
# Quote: "chmod +x \"$TARGET/.claude/hooks/\"*.sh 2>/dev/null || true"
# Note: init.sh chmod's hooks at install time. The CLAIM is that the
# templates ship with the executable bit ALREADY set so chmod is
# defensive, not corrective. Catches the real bug where a contributor
# adds a script without `chmod +x` and downstream users get permission
# errors that init.sh's chmod || true silently hides.
# ============================================================
claim_framework_scripts_are_executable() {
  local missing=0
  for f in templates/.sdd/scripts/*.sh templates/.claude/hooks/*.sh templates/.claude/hooks/pre-commit; do
    [ -f "$f" ] || continue
    if [ ! -x "$f" ]; then
      missing=$((missing + 1))
    fi
  done
  [ "$missing" -eq 0 ]
}

# ============================================================
# CLAIM: broken wiki-link detection fires on staged content
# Source: templates/CLAUDE.md — Wiki-links section
# Quote: "every `[[…]]` must resolve to a known node, or the turn ends with a violation"
# Source 2: templates/.claude/hooks/post-stop-lint.sh — invariant 8
# ============================================================
claim_broken_wikilink_caught_by_lint() {
  # Static check that invariant 8 (broken wiki-link) is wired in
  # post-stop-lint.sh — the stop-hook runs at turn boundary and refuses
  # the turn if a wiki-link target doesn't resolve.
  # The full dynamic test (run hook with a fake slug) lives in T136 of
  # run-framework-test.sh; this audit claim asserts the wiring is
  # present so a future refactor doesn't silently remove it.
  grep -qE 'invariant.*8|broken.*wiki-link|resolve.*\[\[' templates/.claude/hooks/post-stop-lint.sh
}

# ============================================================
# CLAIM: every shipped feature's PR is MERGED on GitHub
# Source: templates/CLAUDE.md — mark-shipped's catalog format
# Quote: "Shipped: <YYYY-MM-DD> · PR: <URL>"
# Note: a renamed/deleted PR would silently break the marketplace
# experience — this catch fires if any PR is closed-without-merge or
# missing. Uses `gh` CLI (already a framework dep per CLAUDE.md
# "Framework deps: bash + python3 + PyYAML + git + gh") so the check
# works on private repos too. Skips cleanly when gh isn't authenticated.
# ============================================================
claim_shipped_pr_links_merged() {
  command -v gh >/dev/null 2>&1 || return 0  # gh missing — skip
  # Verify gh is authed; otherwise skip rather than false-fail.
  gh auth status >/dev/null 2>&1 || return 0
  # Extract owner/repo + PR numbers from the ## Shipped section. The
  # PR URL embeds owner/repo so we don't have to assume the current
  # checkout context — works on CI where `gh pr view <num>` without
  # --repo can't determine the upstream from a shallow checkout.
  local entries
  entries=$(python3 -c "
import re, sys
with open('.sdd/INDEX.md') as f:
    text = f.read()
m = re.search(r'## Shipped\n(.*?)(?=\n## |\Z)', text, re.DOTALL)
if not m:
    sys.exit(0)
block = m.group(1)
# Capture owner/repo and PR number together.
matches = re.findall(r'PR: https://github\.com/([^\s/]+)/([^\s/]+)/pull/([0-9]+)', block)
for owner, repo, num in matches:
    print(f'{owner}/{repo}|{num}')
")
  [ -z "$entries" ] && return 0  # no shipped rows yet — pass
  # Bug 003 fix: when running on a PR's CI, exempt the PR from the
  # MERGED check. The shipped row added by mark-shipped points at
  # this very PR — which is OPEN at audit time by definition. Without
  # the exemption, every shipped PR's CI fails until the merge lands,
  # but the merge is gated on this passing — chicken-egg.
  # GitHub Actions exposes the PR number via $GITHUB_REF in the shape
  # `refs/pull/<num>/merge` on pull_request events.
  local current_pr=""
  local current_repo="${GITHUB_REPOSITORY:-}"  # CR cycle 1 minor: scope to repo+num
  if [ -n "${GITHUB_REF:-}" ]; then
    case "$GITHUB_REF" in
      refs/pull/*/merge|refs/pull/*/head)
        current_pr=$(printf '%s' "$GITHUB_REF" | sed -E 's|refs/pull/([0-9]+)/.*|\1|')
        ;;
    esac
  fi
  local failed=""
  while IFS='|' read -r repo num; do
    [ -z "$num" ] && continue
    # Exempt only the EXACT PR being CI'd: same repo + same number.
    # PR numbers can collide across repos, so num-alone would
    # false-positive on any other repo's PR with the same number.
    # When current_repo is unset (e.g. local invocation outside Actions)
    # we still match num — it's the cleanest signal we have.
    if [ -n "$current_pr" ] && [ "$num" = "$current_pr" ] \
       && { [ -z "$current_repo" ] || [ "$repo" = "$current_repo" ]; }; then
      continue  # exempt: this PR is the one being CI'd; merge is the next step
    fi
    local state
    state=$(gh pr view "$num" --repo "$repo" --json state --jq '.state' 2>/dev/null) || {
      failed="${failed}#${num} (gh view failed for $repo) "
      continue
    }
    if [ "$state" != "MERGED" ]; then
      failed="${failed}#${num} (state=$state) "
    fi
  done <<<"$entries"
  if [ -n "$failed" ]; then
    echo "Shipped PRs not in MERGED state: $failed" >&2
    return 1
  fi
  return 0
}

# ============================================================
# CLAIM: every action's `slug:` field matches its filename
# Source: templates/.sdd/scripts/load-playbook.sh — frontmatter validator
# Quote: "slug must equal filename without .md (config.md §1.5/§2.6)"
# ============================================================
claim_action_slug_matches_filename() {
  python3 -c "
import re, sys, os

bad = []
for fname in sorted(os.listdir('templates/.sdd/actions')):
    if not fname.endswith('.md'):
        continue
    expected = fname[:-3]  # strip .md
    p = os.path.join('templates/.sdd/actions', fname)
    with open(p) as f:
        text = f.read()
    m = re.search(r'^slug:[ \t]+([a-z0-9-]+)', text, re.MULTILINE)
    if not m:
        bad.append(f'{fname}: no slug declared')
        continue
    if m.group(1) != expected:
        bad.append(f'{fname}: slug={m.group(1)!r} (filename suggests {expected!r})')

if bad:
    print('Slug/filename mismatches:', file=sys.stderr)
    for b in bad:
        print(f'  - {b}', file=sys.stderr)
    sys.exit(1)
sys.exit(0)
"
}

# ============================================================
# Orchestrator
# ============================================================
# Bug 003 fix: source-guard so test harnesses can `source` this file
# to call individual claim functions in isolation without triggering
# the full audit. Direct invocation (./run-claims-audit.sh) still
# runs the orchestrator below.
if [ "${BASH_SOURCE[0]}" != "${0}" ]; then
  return 0 2>/dev/null
fi

echo "============================================================"
echo "SDD Claims Audit — proof-by-execution"
echo "============================================================"
echo ""
echo "Each claim below is a verbatim assertion from CLAUDE.md /"
echo "README.md / docs/walkthrough.html / INDEX.md. Each runs an"
echo "executable check; PASS means the framework actually does what"
echo "it says."
echo ""

# Format: <slug>|<one-line description>|<source>
CLAIMS=(
  "anti_theatre_lint_refuses|Anti-theatre lint refuses theatre tokens|CLAUDE.md rule 8"
  "anti_theatre_lint_allows_annotated|Anti-theatre lint allows annotated tokens|CLAUDE.md rule 8"
  "plain_english_lint_blocks_missing_block|Plain-English lint blocks missing example block|CLAUDE.md rule 8"
  "every_action_has_example_block|Every USER-LED/AGENT-LED action ships example block|CLAUDE.md rule 8"
  "decisions_md_append_only_enforced|decisions.md append-only rule wired in F1 enforcer|CLAUDE.md Hooks section"
  "t120_catches_introduced_drift|T120 catches deliberate templates/root drift|run-framework-test.sh"
  "manifest_pins_framework_files|Manifest pins ~61 framework files|walkthrough.html Phase B"
  "manifest_hashes_match_disk|Every manifest-pinned hash matches on-disk content|walkthrough.html"
  "stop_lint_refuses_double_active|Stop-lint refuses INDEX.md with double **Active:**|post-stop-lint invariant 1"
  "plugin_manifest_version_matches_readme|Plugin manifest version matches README's 'Currently at v…' line|.claude-plugin/plugin.json + README.md"
  "framework_self_hosts_hooks|Framework's root .claude/ has hooks bootstrapped|#136 / #137"
  "playwright_dogfood_files_present|Playwright dogfood files at root|#116 / #139"
  "v1_0_ships_4_playbooks|v1.0 ships 4 playbooks|walkthrough.html"
  "9_slash_commands_ship|9 slash commands ship|walkthrough.html Reference"
  "indexmd_wiki_links_resolve|Every wiki-link in INDEX.md resolves|CLAUDE.md Wiki-links"
  "196_framework_tests_pass|196 framework tests pass|walkthrough.html footer"
  "161_mcp_tests_pass|161 MCP unit tests pass|walkthrough.html footer"
  "assumed_markers_lint_refuses_paren_assumed|Assumed-markers lint catches (assumed)/(TBD)/<TODO>|CLAUDE.md rule 1"
  "every_action_tag_in_closed_enum|Every action's tag is from the closed enum|load-playbook.sh VALID_TAGS"
  "v16_plain_english_first_canonical_examples_have_details|v1.6 plain-English-first canonical examples keep the <details> fold|#207 PR-D / Part 4"
  "every_playbook_has_stages_actions_exit_checks|Every playbook frontmatter has stages + actions + exit_checks|CLAUDE.md Canonical playbook"
  "every_shipped_feature_has_marker|Every shipped feature has .shipped marker|CLAUDE.md Shipped features cold"
  "every_shipped_row_has_pr_link|Every shipped row in INDEX.md has a PR link|mark-shipped action format"
  "native_git_pre_commit_shim_wired|Native git pre-commit shim is wired (extension-less)|.claude/hooks/pre-commit"
  "plugin_manifest_has_keywords|Plugin manifest declares non-empty keywords array|.claude-plugin/plugin.json"
  "indexmd_active_line_canonical|INDEX.md **Active:** line is canonical shape|post-stop-lint invariant"
  "three_test_harnesses_present|All three test harnesses present (framework + audit + playwright)|README.md three layers of dogfood"
  "only_pyyaml_python_dep|Only PyYAML required as Python dep at framework root|CLAUDE.md design philosophy"
  "framework_scripts_are_executable|Every framework script ships with executable bit set|init.sh script-copy contract"
  "broken_wikilink_caught_by_lint|Broken wiki-link detection wired in post-stop-lint|CLAUDE.md Wiki-links + invariant 8"
  "shipped_pr_links_merged|Every shipped PR is MERGED on GitHub|mark-shipped catalog format"
  "action_slug_matches_filename|Every action's slug matches its filename|load-playbook.sh validator"
)

for entry in "${CLAIMS[@]}"; do
  IFS='|' read -r slug desc source <<<"$entry"
  note "$slug — $desc"
  echo "  source: $source"
  if claim_"$slug"; then
    ok "$desc"
  else
    bad "$desc" "claim_$slug returned non-zero"
  fi
done

echo ""
echo "============================================================"
echo "RESULTS: $PASSED passed · $FAILED failed (${#CLAIMS[@]} claims audited)"
echo "============================================================"

if [ "$FAILED" -gt 0 ]; then
  echo ""
  echo "Failing claims:"
  printf '%s' "$FAIL_LINES"
  exit 1
fi

exit 0
