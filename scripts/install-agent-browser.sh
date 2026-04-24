#!/usr/bin/env bash
# Install agent-browser globally if not already present.
# Idempotent. Exits 0 if already installed or install succeeds.

set -euo pipefail

if command -v agent-browser >/dev/null 2>&1; then
  echo "  agent-browser already installed: $(agent-browser --version 2>/dev/null || echo 'unknown version')"
  exit 0
fi

if ! command -v npm >/dev/null 2>&1; then
  echo "ERROR: npm not found. Install Node.js (https://nodejs.org) first, then re-run this script." >&2
  exit 1
fi

echo "Installing agent-browser globally via npm…"
if npm install -g agent-browser 2>&1; then
  echo "  agent-browser installed."
else
  echo "  npm install -g failed (permissions?). Try:"
  echo "    sudo npm install -g agent-browser"
  echo "  or use a node version manager (nvm/fnm) so global installs don't need sudo."
  exit 1
fi
