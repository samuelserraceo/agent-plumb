#!/usr/bin/env bash
# Migration into v0.6.2.
# - schema-sync hook fix (now skips bootstrap commits) — handled by the normal hook copy.
# - Bumps version. No structural file changes.
set -euo pipefail
cd "$1"
