#!/usr/bin/env bash
# Migration into v0.7.1.
# - pre-commit-block hook now allows bootstrap commits (handled by normal hook copy).
# - CLAUDE.md gains bundling rule + multi-choice rule (handled by managed-block swap).
# - Rubric §2/§3/§11 get multi-choice scaffolding (handled by rubric copy).
# No structural file changes.
set -euo pipefail
cd "$1"
