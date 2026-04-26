#!/usr/bin/env bash
# Migration into v0.6.
# - No structural file changes; v0.6 was a fix for runtime-script install
#   (handled by update.sh's normal copy step) and a CLAUDE.md content update
#   (handled by update.sh's MANAGED block swap).
#
# Kept as a placeholder so the migration ladder is contiguous.

set -euo pipefail
cd "$1"  # target project root
# No-op
