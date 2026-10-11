#!/usr/bin/env bash
# Installs the ship-task skill and the skills it calls, globally for Claude Code.
set -euo pipefail

if ! command -v npx >/dev/null 2>&1; then
  echo "npx not found. Install Node.js first: https://nodejs.org" >&2
  exit 1
fi

add() { npx -y skills add "$@" -g -a claude-code -y; }

add Koushik890/ship-task
add michaelshimeles/skills \
  -s new-feature -s code-structure -s evidence-driven-testing \
  -s unslop -s greploop -s greploop-apps
add vercel-labs/before-and-after

command -v gh >/dev/null 2>&1 || echo "Note: GitHub CLI (gh) not found. Install it and run 'gh auth login'."
command -v agent-browser >/dev/null 2>&1 || echo "Note: agent-browser not found. For UI captures: npm i -g agent-browser"

echo "Done. Restart Claude Code, then run: /ship-task <task description>"
