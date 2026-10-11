#!/usr/bin/env bash
# Installs the ship-task skill and the exact (pinned) versions of the skills it calls.
#
#   curl -fsSL https://raw.githubusercontent.com/Koushik890/ship-task/main/install.sh | bash
#   ./install.sh                      # from a clone
#
# Env overrides:
#   CLAUDE_SKILLS_DIR  install target (default: ~/.claude/skills)
#   SHIP_TASK_REF      branch/tag/sha of ship-task to install when run via curl (default: main)
set -euo pipefail

REPO_URL="https://github.com/Koushik890/ship-task"
SHIP_TASK_REF="${SHIP_TASK_REF:-main}"
SKILLS_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"

die()  { echo "error: $*" >&2; exit 1; }
warn() { echo "warning: $*" >&2; }

command -v git >/dev/null 2>&1 || die "git is required."

WORK="$(mktemp -d 2>/dev/null || mktemp -d -t ship-task)"
trap 'rm -rf "$WORK"' EXIT

# Source of ship-task itself: the clone this script sits in, or a fresh fetch.
SCRIPT_DIR=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/SKILL.md" ] && [ -f "$SCRIPT_DIR/deps.lock" ]; then
  SRC="$SCRIPT_DIR"
else
  SRC="$WORK/ship-task"
  git clone -q --depth 1 --branch "$SHIP_TASK_REF" "$REPO_URL" "$SRC" 2>/dev/null \
    || { rm -rf "$SRC" && git clone -q "$REPO_URL" "$SRC" && git -C "$SRC" -c advice.detachedHead=false checkout -q "$SHIP_TASK_REF"; } \
    || die "could not fetch $REPO_URL at $SHIP_TASK_REF"
fi

mkdir -p "$SKILLS_DIR"

# Replace $SKILLS_DIR/<name> with the contents of <from>. Never touches a git checkout.
place() {
  local name="$1" from="$2" dest="$SKILLS_DIR/$1"
  [ -f "$from/SKILL.md" ] || die "$name: no SKILL.md in source"
  if [ -L "$dest" ]; then
    rm -f "$dest"                       # symlink from an earlier `npx skills` install
  elif [ -e "$dest/.git" ]; then
    warn "$name: $dest is a git checkout, leaving it alone (git pull it to update)"
    return
  elif [ -e "$dest" ]; then
    rm -rf "$dest"
  fi
  mkdir -p "$dest"
  (cd "$from" && tar cf - --exclude=.git .) | (cd "$dest" && tar xf -)
  echo "  $name"
}

# Fetch one commit of a repo (shallow) into a cache dir; later skills from the same commit reuse it.
fetch_commit() {
  local url="$1" sha="$2" dir="$WORK/repos/$2"
  if [ ! -d "$dir" ]; then
    mkdir -p "$dir"
    git -C "$dir" init -q
    git -C "$dir" fetch -q --depth 1 "$url" "$sha" || die "could not fetch $url @ $sha"
    git -C "$dir" -c advice.detachedHead=false checkout -q FETCH_HEAD
    [ "$(git -C "$dir" rev-parse HEAD)" = "$sha" ] || die "$url: got wrong commit"
  fi
  printf '%s' "$dir"
}

echo "Installing into $SKILLS_DIR"

# ship-task itself: only the files the skill needs at runtime.
STAGE="$WORK/stage-ship-task"
mkdir -p "$STAGE"
cp "$SRC/SKILL.md" "$SRC/LICENSE" "$SRC/deps.lock" "$STAGE/"
place ship-task "$STAGE"

while IFS='|' read -r name url sha path || [ -n "${name:-}" ]; do
  name="${name%$'\r'}"; path="${path%$'\r'}"
  case "$name" in ''|'#'*) continue ;; esac
  repo="$(fetch_commit "$url" "$sha")"
  place "$name" "$repo/$path"
done < "$SRC/deps.lock"

# Tool checks: warn only. Optional tools only disable the steps that need them.
echo
echo "Checking tools:"
have() { command -v "$1" >/dev/null 2>&1; }
check() { if have "$1"; then echo "  ok       $1"; else echo "  missing  $1  ($2)"; fi; }
if have gh; then
  read -r maj min < <(gh --version | head -1 | sed -E 's/[^0-9]*([0-9]+)\.([0-9]+).*/\1 \2/')
  if [ "$maj" -gt 2 ] || { [ "$maj" -eq 2 ] && [ "$min" -ge 100 ]; }; then
    echo "  ok       gh $maj.$min"
  else
    echo "  old      gh $maj.$min  (need 2.100+ for PR media uploads: upgrade gh)"
  fi
  gh auth status >/dev/null 2>&1 || echo "           gh is not logged in: run 'gh auth login'"
else
  echo "  missing  gh  (required: https://cli.github.com, then 'gh auth login')"
fi
check node "required by before-and-after: https://nodejs.org"
check jq "used by greploop: https://jqlang.github.io/jq/"
if have python3 || have python || have py; then echo "  ok       python"; else echo "  missing  python  (evidence recorder: https://python.org)"; fi
check ffmpeg "evidence screen recordings: https://ffmpeg.org"
check agent-browser "UI captures: npm i -g agent-browser"

echo
echo "Done. Restart Claude Code, then run: /ship-task <task description>"
