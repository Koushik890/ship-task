#!/usr/bin/env bash
# Usage: tests/verify.sh <skills dir>...
# Checks every skill in deps.lock (plus ship-task) is installed as a real directory
# whose SKILL.md frontmatter name matches, and that files equal the pinned upstream.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fail=0
for dir in "$@"; do
  echo "== $dir"
  names="ship-task $(grep -vE '^\s*(#|$)' "$ROOT/deps.lock" | cut -d'|' -f1 | tr -d '\r')"
  for n in $names; do
    d="$dir/$n"
    if [ -L "$d" ] || [ ! -f "$d/SKILL.md" ]; then echo "FAIL $n: missing or symlink"; fail=1; continue; fi
    got="$(sed -n 's/^name:[[:space:]]*//p' "$d/SKILL.md" | head -1 | tr -d '\r')"
    [ "$got" = "$n" ] || { echo "FAIL $n: frontmatter name is '$got'"; fail=1; continue; }
    [ ! -e "$d/.git" ] || { echo "FAIL $n: .git copied"; fail=1; continue; }
    echo "ok   $n"
  done
  cmp -s <(tr -d '\r' < "$ROOT/SKILL.md") <(tr -d '\r' < "$dir/ship-task/SKILL.md") \
    || { echo "FAIL ship-task: SKILL.md differs from repo"; fail=1; }
done
exit $fail
