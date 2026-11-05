#!/usr/bin/env bash
# install.sh - hm-setup B1: puts the harness files that are the same in every project into it,
# in one run. Run it from the project root:
#   bash <hm-setup skill folder>/scripts/install.sh
# It copies scripts/hm.sh and scripts/harness-state.sh (always, unchanged), and writes or appends
# everything else only where it is missing: AGENTS.md (or its harness section), the agent entry
# files from AGENT_FILES, docs/STANDARDS.md, docs/tasks/_template.md, .githooks/, .gitignore and
# .gitattributes lines, the commands section of .harness/config, .harness/guardrail-samples.
# It never overwrites a file that already exists. It prints one line per file.
set -u -o pipefail

SKILL=$(cd "$(dirname "$0")/.." && pwd)
T=$SKILL/templates

[ -f .harness/config ] || { echo "error: .harness/config not found; run this from the project root after hm-req" >&2; exit 1; }
[ -d "$T" ] || { echo "error: templates not found in $SKILL" >&2; exit 1; }

say() { printf '%-9s %s\n' "$1" "$2"; }

ends_with_newline() { [ ! -s "$1" ] || [ -z "$(tail -c 1 "$1")" ]; }

copy_new() { # copy_new <src> <dst>: copy unless dst exists
  if [ -e "$2" ]; then say kept "$2"; return; fi
  mkdir -p "$(dirname "$2")"
  cp "$1" "$2"
  say copied "$2"
}

append_missing() { # append_missing <file> <line>...: append each line the file does not hold yet
  local f=$1 l
  shift
  touch "$f"
  ends_with_newline "$f" || printf '\n' >> "$f"
  for l in "$@"; do
    if grep -qxF -- "$l" "$f"; then continue; fi
    printf '%s\n' "$l" >> "$f"
    say appended "$f: $l"
  done
}

mkdir -p scripts docs/tasks artifacts .run .githooks

# Scripts: always the skill's current version.
for s in hm.sh harness-state.sh; do
  cp "$SKILL/scripts/$s" "scripts/$s"
  chmod +x "scripts/$s"
  say copied "scripts/$s"
done

# AGENTS.md: a new file, or the harness section appended to an existing one.
if [ ! -e AGENTS.md ]; then
  cp "$T/AGENTS.template.md" AGENTS.md
  say copied AGENTS.md
elif grep -q '^Project profile: see .harness/config' AGENTS.md; then
  say kept "AGENTS.md (harness section already there)"
else
  ends_with_newline AGENTS.md || printf '\n' >> AGENTS.md
  { printf '\n'; sed '1s/^# AGENTS[[:space:]]*$/# Harness/' "$T/AGENTS.template.md"; } >> AGENTS.md
  say appended "AGENTS.md (# Harness section)"
fi

# Agent entry files: AGENT_FILES from .harness/config; CLAUDE.md when the key is missing.
if grep -q '^AGENT_FILES=' .harness/config; then
  agent_files=$(sed -n 's/^AGENT_FILES=//p' .harness/config | tr -d '\r' | tail -n 1)
else
  agent_files=CLAUDE.md
fi
for f in $agent_files; do
  if [ -e "$f" ] && grep -q 'AGENTS\.md' "$f"; then say kept "$f"; continue; fi
  mkdir -p "$(dirname "$f")"
  if [ -e "$f" ]; then ends_with_newline "$f" || printf '\n' >> "$f"; fi
  printf '%s\n' "Read AGENTS.md first: it holds this project's harness rules." "@AGENTS.md" >> "$f"
  say wrote "$f"
done

copy_new "$T/STANDARDS.template.md" docs/STANDARDS.md
copy_new "$T/task.template.md" docs/tasks/_template.md
copy_new "$T/guardrail-samples.template" .harness/guardrail-samples

# Git hooks.
if [ -e .githooks/pre-commit ]; then
  say kept .githooks/pre-commit
else
  printf '%s\n' '#!/bin/sh' 'exec bash scripts/hm.sh check --hook' > .githooks/pre-commit
  say wrote .githooks/pre-commit
fi
if [ -e .githooks/commit-msg ]; then
  say kept .githooks/commit-msg
else
  cat > .githooks/commit-msg <<'EOF'
#!/bin/sh
# Commit messages: <type>(<scope>): <summary> or <type>: <summary>. Merge and Revert pass.
first=$(head -n 1 "$1")
case $first in Merge*|Revert*) exit 0 ;; esac
if printf '%s\n' "$first" | grep -Eq '^(feat|fix|docs|test|refactor|perf|style|chore|wip|revert)(\([A-Za-z0-9._-]+\))?: .+'; then
  exit 0
fi
echo "commit message must look like: feat(task-3): summary" >&2
exit 1
EOF
  say wrote .githooks/commit-msg
fi
chmod +x .githooks/pre-commit .githooks/commit-msg

append_missing .gitignore 'artifacts/' '.run/' '.harness/local' '.env' '.env.*' '!.env.example'
append_missing .gitattributes '*.sh text eol=lf' '.githooks/* text eol=lf' '.harness/config text eol=lf' \
  '.harness/guardrail-samples text eol=lf' 'docs/tasks/*.md text eol=lf'

# Commands section of .harness/config, to be filled from SPEC 2.
if grep -q '^# Commands (hm-setup' .harness/config; then
  say kept ".harness/config commands section"
else
  ends_with_newline .harness/config || printf '\n' >> .harness/config
  { printf '\n'; cat "$T/config-commands.template"; } >> .harness/config
  say appended ".harness/config (commands section with placeholders)"
fi

if git rev-parse --git-dir >/dev/null 2>&1; then
  git config core.hooksPath .githooks
  say set "core.hooksPath=.githooks"
else
  say later "core.hooksPath (not a git repository yet; bash scripts/hm.sh setup sets it)"
fi

echo "install: ok"
echo "next: fill the commands section of .harness/config and .harness/guardrail-samples, write the task files, then run: bash scripts/hm.sh selftest"
