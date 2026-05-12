#!/usr/bin/env bash
# verify-stack.sh — post-wizard reality check.
#
# `/sdd-setup` records the user's stack answers but does not probe whether
# the named tools actually exist on this machine (the CodeRabbit-App-not-
# installed gap Sam lived on PipeLogic V2). This script runs the six
# checks from issue #165 against the declared answers and reports each
# pass/fail with a plain-English fix path.
#
# T500 walking-skeleton (this commit): script exists, manifest-pinned,
# empty-params path returns the canonical no-op line. T501-T506 layer
# one check each on top of this shell.
#
# Usage: bash .sdd/scripts/verify-stack.sh
#        (run from project root; honours $CLAUDE_PROJECT_DIR if set)

set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$PROJECT_DIR" || { echo "[verify-stack] cannot cd to $PROJECT_DIR" >&2; exit 1; }

[ -d ".sdd" ] || { echo "not an SDD project — run /sdd-setup first" >&2; exit 1; }

# T501-T506 will append per-check function calls here. With no checks
# wired in yet, every project reports the empty-params line.
echo "no declared tools to verify"
exit 0
