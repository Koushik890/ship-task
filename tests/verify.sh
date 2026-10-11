#!/usr/bin/env bash
# Usage: tests/verify.sh <skills dir>...
# For every skill in deps.lock (plus ship-task): installed as a real directory, frontmatter
# name matches, no .git copied, and every file is identical to the pinned upstream commit.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d 2>/dev/null || mktemp -d -t verify)"
trap 'rm -rf "$WORK"' EXIT

# Pinned sources, fetched once per commit.
src_of() {
  local url="$1" sha="$2" path="$3" dir="$WORK/$2"
  if [ ! -d "$dir" ]; then
    git init -q "$dir"
    git -C "$dir" fetch -q --depth 1 "$url" "$sha"
    git -C "$dir" -c advice.detachedHead=false checkout -q FETCH_HEAD
  fi
  printf '%s' "$dir/$path"
}

fail=0
check_dir() {
  local n="$1" d="$2" expected="$3"
  if [ -L "$d" ] || [ ! -f "$d/SKILL.md" ]; then echo "FAIL $n: missing or symlink"; fail=1; return; fi
  local got; got="$(sed -n 's/^name:[[:space:]]*//p' "$d/SKILL.md" | head -1 | tr -d '\r')"
  [ "$got" = "$n" ] || { echo "FAIL $n: frontmatter name is '$got'"; fail=1; return; }
  [ ! -e "$d/.git" ] || { echo "FAIL $n: .git copied"; fail=1; return; }
  if ! diff -r --strip-trailing-cr -x .git "$expected" "$d" >/dev/null; then
    echo "FAIL $n: files differ from pinned source"; diff -rq --strip-trailing-cr -x .git "$expected" "$d" || true
    fail=1; return
  fi
  echo "ok   $n"
}

# Expected ship-task install: exactly these files from the repo.
mkdir -p "$WORK/ship-task"
cp "$ROOT/SKILL.md" "$ROOT/LICENSE" "$ROOT/deps.lock" "$WORK/ship-task/"

for dir in "$@"; do
  echo "== $dir"
  check_dir ship-task "$dir/ship-task" "$WORK/ship-task"
  while IFS='|' read -r name url sha path || [ -n "${name:-}" ]; do
    name="${name%$'\r'}"; path="${path%$'\r'}"
    case "$name" in ''|'#'*) continue ;; esac
    check_dir "$name" "$dir/$name" "$(src_of "$url" "$sha" "$path")"
  done < "$ROOT/deps.lock"
done
exit $fail
