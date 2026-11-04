#!/usr/bin/env bash
# sync-shared.sh - copies harness-skills/_shared/*.md into the references/ folder of every skill
# that uses them, so each skill folder stays self-contained while the source is one file.
#   bash harness-skills/sync-shared.sh          copy
#   bash harness-skills/sync-shared.sh --check  only report copies that differ (exit 1 if any)
# Which skill gets which file is the table below. Run it before copying the skills to the
# agents' skill folders (CLAUDE.md). ASCII only.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
check=${1:-}
rc=0

# <file> <skills...>
sync() {
  local f=$1 s src dst
  shift
  src=$HERE/_shared/$f
  [ -f "$src" ] || { echo "missing $src"; rc=1; return; }
  for s in "$@"; do
    dst=$HERE/$s/references/$f
    if [ "$check" = --check ]; then
      if [ -f "$dst" ] && cmp -s "$src" "$dst"; then echo "same     $s/references/$f"; else echo "DIFFERS  $s/references/$f"; rc=1; fi
    else
      mkdir -p "$HERE/$s/references"
      cp "$src" "$dst"
      echo "copied   $s/references/$f"
    fi
  done
}

sync question-format.md hm-req hm-setup hm-change hm-dev hm-review hm-audit hm-security hm-load-test hm-explain
sync no-harness.md hm-dev hm-review hm-change hm-audit hm-security hm-load-test hm-explain
sync review-guide.md hm-review hm-dev

exit $rc
