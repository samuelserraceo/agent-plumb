#!/usr/bin/env bash
# corpus-signature-lock.sh — mkdir-as-lockdir helper for Tier 3
# synthesise() corpus-signature reads.
#
# Closes #113 (the v1.1 Tier 3 SPEC §15 edge-case race): a user editing
# .sdd/ markdown while a synthesise() call reads the corpus fingerprint
# can produce an inconsistent cache key. This helper bounds that race —
# callers `acquire` before reading the signature, `release` after caching.
#
# Tier-3-gated: only fires when parameters.mcp.tier3.enabled: true and a
# synthesise() integration point calls it. The helper ships defensively
# so it's already in place when Tier 3 enables on a downstream project.
#
# Usage:
#   corpus-signature-lock.sh acquire <lockdir-path>
#       Try to mkdir the lockdir atomically. Retries 50 × 0.1s on
#       contention (~5s ceiling). Exit 0 on success, exit 1 on timeout.
#
#   corpus-signature-lock.sh release <lockdir-path>
#       rmdir the lockdir. Idempotent — exit 0 even if already absent.
#
# Pattern: mkdir is POSIX-atomic, so two concurrent calls on the same
# path serialise — exactly one wins, the other gets EEXIST. Same shape
# background-while-waiting.sh (F009) uses; bash 3.2 / macOS compatible
# without Homebrew util-linux (flock isn't in base macOS).
#
# Exits:
#   0 — success (lock acquired, or released, or already released)
#   1 — acquire timed out after 50 × 0.1s retries
#   2 — usage error

set -uo pipefail

cmd="${1:-}"
lockdir="${2:-}"

if [ -z "$cmd" ] || [ -z "$lockdir" ]; then
  echo "usage: $0 acquire|release <lockdir-path>" >&2
  exit 2
fi

case "$cmd" in
  acquire)
    i=0
    while ! mkdir "$lockdir" 2>/dev/null; do
      i=$((i + 1))
      if [ "$i" -gt 50 ]; then
        echo "corpus-signature-lock: acquire timeout (50 retries × 0.1s) on $lockdir" >&2
        exit 1
      fi
      sleep 0.1
    done
    exit 0
    ;;
  release)
    rmdir "$lockdir" 2>/dev/null
    # Idempotent — already-absent is fine (concurrent release, crash recovery).
    exit 0
    ;;
  *)
    echo "usage: $0 acquire|release <lockdir-path>" >&2
    exit 2
    ;;
esac
