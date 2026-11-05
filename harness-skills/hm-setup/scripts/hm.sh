#!/usr/bin/env bash
# hm.sh - the project's harness commands. Skills, hooks and people call these names;
# the stack-specific commands live in .harness/config, so nothing here knows the stack.
#
# Usage: bash scripts/hm.sh <command>
#   setup    install dependencies (INSTALL_CMD, E2E_SETUP_CMD), migrate, set the git hooks path
#   migrate  apply database migrations to this worktree's database (MIGRATE_CMD)
#   dev      run the components in the foreground (Ctrl-C stops them); without components DEV_CMD
#   dev-bg   start the components in the background and wait until each one is healthy
#   stop     stop the components dev-bg started
#   health   show which components are healthy
#   status   task table across branches (harness-state.sh status)
#   test [args]  unit tests (TEST_CMD). Arguments go where TEST_CMD has "$@" (test files or a
#            name filter), so `test <file>` runs only those; no arguments runs the full suite
#   test --reuse, e2e --reuse, check --reuse  print the recorded pass of this exact tree
#            instead of running again, when there is one (see "Pass records" below)
#   e2e [args]   E2E tests (E2E_CMD, arguments as for test); reuses healthy components, stops
#            only the ones it started
#   load     load test (LOAD_CMD) on PORT_OFFSET+100 with production-like commands
#   bench    benchmarks (BENCH_CMD)
#   security security scans (SECURITY_CMD): dependency audit, static analysis, secret scan
#   fmt [files]  format files in place (FORMAT_CMD); no arguments formats the whole project
#   check    guardrails (protected paths, secrets, debug probes, skipped tests, E2E selectors,
#            task fields), then LINT_CMD on the whole project, then TYPECHECK_CMD.
#            `check --hook` (the pre-commit hook) first formats the staged code files and
#            re-stages them, then runs LINT_CMD on those files only (its "$@"; without "$@" on
#            everything), skips it when only Markdown is staged, and never runs TYPECHECK_CMD
#   selftest prove the guardrail patterns (.harness/guardrail-samples), then run check
#   doctor   check this machine and this worktree in one go: git, bash, curl, the config
#            (values, placeholders, "$@", worktree folder), components, hooks, line endings.
#            Prints ok / warn / FAIL per item; exits 1 on any FAIL
#   help     this text, plus which commands are active and which skip
# A command turned off by the config prints "skip: <reason>" and exits 0.
#
# .harness/config, then .harness/local (per worktree, PORT_OFFSET), one KEY=value per line.
# The value is the rest of the line, taken literally (no quotes needed, no inline comments).
# Lines starting with # are comments. Commands run with `bash -c` after every key is
# exported, so a command refers to other keys as $NAME at run time (e.g. $api_PORT).
#
# Per worktree: HM_SLOT = PORT_OFFSET / PORT_STEP (0 in the main worktree, 1, 2, ... in task
# worktrees). Derive anything parallel worktrees must not share from it: database or schema
# names, cache key prefixes, queue names, container project names (e.g. DB_NAME=app_$HM_SLOT).
#
# Components: COMPONENTS=api web (start order), and per component:
#   <c>_PORT     base port; hm.sh exports <c>_PORT = base + PORT_OFFSET
#   <c>_DEV      foreground command with reload      <c>_PROD  production-like command
#   <c>_HEALTH   exits 0 only when THIS project's component is up. Helper available inside:
#                http_has <url> <text>   the response body of <url> contains <text>
#   UP_CMD / DOWN_CMD (optional) one launcher that starts / stops all components instead;
#                it must return after starting them. Health checks still decide readiness.
# Env: HEALTH_TIMEOUT (default 60 seconds per component). Pid files and logs: .run/<set>-<c>.*
#
# Pass records: a full `test`, `e2e` or `check` (no arguments) that passes in a worktree with
# no uncommitted changes writes <git common dir>/hm-pass/<command>-<tree hash>: when it passed
# and the last lines of its output. Every worktree of the repository sees them. Only `--reuse`
# reads them; without it every command runs as always. With uncommitted changes nothing is
# recorded or reused. The key is the committed tree, so a merge commit whose tree equals the
# branch that already passed reuses that pass; ignored files (.env) are not part of the key.
set -u -o pipefail

cd "$(dirname "$0")/.." || exit 1
RUN=.run

die() { echo "error: $*" >&2; exit 1; }
skip() { echo "skip: $*"; exit 0; }

# ---------- config ----------

load_config() {
  local f line k n
  for f in .harness/config .harness/local; do
    [ -f "$f" ] || continue
    n=0
    while IFS= read -r line || [ -n "$line" ]; do
      n=$((n + 1))
      line=${line%$'\r'}
      case $line in ''|'#'*) continue ;; esac
      k=${line%%=*}
      case $line in *=*) ;; *) die "$f line $n: expected KEY=value: $line" ;; esac
      case $k in ''|[0-9]*|*[!A-Za-z0-9_]*) die "$f line $n: bad key '$k' (KEY=value, no spaces around =)" ;; esac
      export "$k=${line#*=}"
    done < "$f"
  done
  export PORT_OFFSET=${PORT_OFFSET:-0}
  local step=${PORT_STEP:-10}
  [ "$step" -gt 0 ] 2>/dev/null || die "PORT_STEP must be a positive number"
  export HM_SLOT=$((PORT_OFFSET / step))
  : "${HAS_SERVER:=0}" "${HAS_UI:=0}" "${HAS_LOAD:=0}" "${MODE:=FULL}"
  : "${COMPONENTS:=}" "${UP_CMD:=}" "${DOWN_CMD:=}" "${SERVICE:=}"
  export SERVICE UP_CMD DOWN_CMD
  local c b
  for c in $COMPONENTS; do
    check_name "$c"
    b=$(var "$c" PORT)
    [ -z "$b" ] || export "${c}_PORT_BASE=$b"
  done
  set_ports "$PORT_OFFSET"
}

# set_ports <offset>: <c>_PORT = <c>_PORT_BASE + offset, for every component with a port.
set_ports() {
  local c b
  export PORT_OFFSET=$1
  for c in $COMPONENTS; do
    b=$(var "$c" PORT_BASE)
    [ -z "$b" ] || export "${c}_PORT=$((b + $1))"
  done
}

var() { local n="$1_$2"; printf '%s' "${!n:-}"; }

check_name() { case $1 in ''|[0-9]*|*[!A-Za-z0-9_]*) die "bad component name '$1' (letters, digits, underscore)" ;; esac; }

# Helper for health commands; exported so `bash -c "$<c>_HEALTH"` can call it.
http_has() { curl -sf --max-time 5 "$1" 2>/dev/null | grep -qF -- "$2"; }
export -f http_has

run() { # run <KEY> [args]: run the command stored in KEY, or fail if it is empty.
  # The args are the command's "$@" ($1, $2, ...); a command that does not use them ignores them.
  local cmd=${!1:-}
  [ -n "$cmd" ] || die "$1 is empty in .harness/config"
  shift
  bash -c "$cmd" hm "$@"
}

# ---------- pass records ----------

# clean_tree: REPLY = the tree hash of HEAD when the worktree has no uncommitted or untracked
# changes; fails (REPLY empty) otherwise.
clean_tree() {
  REPLY=
  [ -z "$(git status --porcelain 2>/dev/null)" ] || return 1
  REPLY=$(git rev-parse 'HEAD^{tree}' 2>/dev/null) && [ -n "$REPLY" ]
}

recorded() { # recorded <name> <reuse 0|1> <function> [args]: run it, keeping a pass record
  local name=$1 reuse=$2 tree= dir f out rc
  shift 2
  clean_tree && tree=$REPLY
  if [ -z "$tree" ]; then
    [ "$reuse" = 1 ] && echo "$name: nothing reused (uncommitted changes); running"
    "$@"; return $?
  fi
  dir=$(git rev-parse --git-common-dir)/hm-pass
  f=$dir/$name-$tree
  if [ "$reuse" = 1 ]; then
    if [ -f "$f" ]; then
      echo "$name: ok (reused: the same tree passed before, nothing ran now)"
      cat "$f"
      return 0
    fi
    echo "$name: no recorded pass for this tree; running"
  fi
  mkdir -p "$RUN" "$dir"
  out=$RUN/$name.out
  ( "$@" ) 2>&1 | tee "$out"
  rc=${PIPESTATUS[0]}
  if [ "$rc" -eq 0 ]; then
    { echo "recorded: $(date '+%Y-%m-%d %H:%M:%S'), tree $tree; the run's last lines:"
      tail -n 20 "$out"; } > "$f"
  fi
  return "$rc"
}

# ---------- components ----------

healthy() {
  local h
  h=$(var "$1" HEALTH)
  [ -n "$h" ] || die "$1_HEALTH is not set in .harness/config"
  bash -c "$h" >/dev/null 2>&1
}

port_busy() { [ -n "$1" ] && (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null; }

alive() { [ -n "$1" ] && kill -0 "$1" 2>/dev/null; }

# Kill a started process with its children. On Git Bash, taskkill /T walks the Windows
# process tree (a dev server started through a wrapper survives a plain kill otherwise).
kill_tree() {
  local pid=$1 w i
  if [ -r "/proc/$pid/winpid" ] && command -v taskkill >/dev/null 2>&1; then
    w=$(cat "/proc/$pid/winpid")
    taskkill //F //T //PID "$w" >/dev/null 2>&1
  fi
  kill -TERM -- "-$pid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null
  for i in 1 2 3 4 5 6 7 8 9 10; do alive "$pid" || return 0; sleep 0.5; done
  kill -KILL -- "-$pid" 2>/dev/null || kill -KILL "$pid" 2>/dev/null
  return 0
}

stop_one() { # stop_one <set> <name>
  local pidf=$RUN/$1-$2.pid pid
  [ -f "$pidf" ] || return 0
  pid=$(cat "$pidf")
  if alive "$pid"; then kill_tree "$pid"; echo "$2: stopped"; fi
  rm -f "$pidf"
}

start_one() { # start_one <set> <name>; sets STARTED=1 if it started a process
  local set=$1 n=$2 key cmd port pidf log
  STARTED=0
  pidf=$RUN/$set-$n.pid
  log=$RUN/$set-$n.log
  key=$(printf '%s' "$set" | tr 'a-z' 'A-Z')
  cmd=$(var "$n" "$key")
  [ -n "$cmd" ] || die "${n}_$key is not set in .harness/config"
  if healthy "$n"; then echo "$n: already running"; return 0; fi
  port=$(var "$n" PORT)
  if port_busy "$port"; then
    echo "error: port $port for $n is taken by something that is not this project's $n" >&2
    return 1
  fi
  mkdir -p "$RUN"
  if [ -n "$USE_SETSID" ]; then
    setsid bash -c "$cmd" >"$log" 2>&1 </dev/null &
  else
    bash -c "$cmd" >"$log" 2>&1 </dev/null &
  fi
  echo $! > "$pidf"
  STARTED=1
  echo "$n: started (pid $!, port ${port:-none}, log $log)"
}

wait_one() { # wait_one <set> <name>
  local n=$2 log=$RUN/$1-$2.log pidf=$RUN/$1-$2.pid t=0
  until healthy "$n"; do
    if [ -f "$pidf" ] && ! alive "$(cat "$pidf")"; then
      echo "error: $n exited before it became healthy; last log lines:" >&2
      tail -n 50 "$log" >&2 2>/dev/null
      return 1
    fi
    if [ "$t" -ge "$TIMEOUT" ]; then
      echo "error: $n not healthy after ${TIMEOUT}s; last log lines:" >&2
      tail -n 50 "$log" >&2 2>/dev/null
      return 1
    fi
    sleep 1; t=$((t + 1))
  done
}

# up <dev|prod> [MARKFILE]: start what is not healthy, in order, waiting for each one.
# MARKFILE collects the names this call started (UP for UP_CMD), so `down` can stop only those.
up() {
  local set=$1 mark=${2:-} n s started= all_ok=1
  mkdir -p "$RUN"
  if [ -n "$UP_CMD" ]; then
    for n in $COMPONENTS; do healthy "$n" || all_ok=0; done
    if [ "$all_ok" = 1 ]; then echo "all components already running"; return 0; fi
    bash -c "$UP_CMD" || { echo "error: UP_CMD failed" >&2; return 1; }
    [ -n "$mark" ] && echo UP >> "$mark"
    for n in $COMPONENTS; do
      wait_one "$set" "$n" || { [ -n "$DOWN_CMD" ] && bash -c "$DOWN_CMD"; return 1; }
    done
    return 0
  fi
  for n in $COMPONENTS; do
    if ! start_one "$set" "$n"; then
      for s in $started; do stop_one "$set" "$s"; done
      return 1
    fi
    if [ "$STARTED" = 1 ]; then
      started="$started $n"
      [ -n "$mark" ] && echo "$n" >> "$mark"
    fi
    if ! wait_one "$set" "$n"; then
      for s in $started; do stop_one "$set" "$s"; done
      return 1
    fi
  done
}

# down <dev|prod> [MARKFILE]: stop every component, or only those listed in MARKFILE.
down() {
  local set=$1 only=${2:-} names n
  if [ -n "$only" ]; then
    [ -f "$only" ] || return 0
    names=$(tr -d '\r' < "$only")
    rm -f "$only"
  else
    names=$COMPONENTS
  fi
  if [ -n "$DOWN_CMD" ] && { [ -z "$only" ] || printf '%s\n' "$names" | grep -qx UP; }; then
    bash -c "$DOWN_CMD"
  fi
  for n in $names; do
    [ "$n" = UP ] && continue
    check_name "$n"
    stop_one "$set" "$n"
  done
  return 0
}

need_components() {
  [ "$HAS_SERVER" = 1 ] || skip "HAS_SERVER=0"
  [ -n "$COMPONENTS" ] || die "HAS_SERVER=1 but COMPONENTS is empty in .harness/config"
}

# ---------- commands ----------

cmd_setup() {
  mkdir -p artifacts "$RUN"
  [ -n "${INSTALL_CMD:-}" ] && { run INSTALL_CMD || exit 1; }
  [ -n "${E2E_SETUP_CMD:-}" ] && { run E2E_SETUP_CMD || exit 1; }
  [ -n "${MIGRATE_CMD:-}" ] && { run MIGRATE_CMD || exit 1; }
  git config core.hooksPath .githooks
  echo "setup: ok"
}

cmd_dev() {
  if [ "$HAS_SERVER" != 1 ] || [ -z "$COMPONENTS" ]; then
    [ -n "${DEV_CMD:-}" ] || skip "no components and DEV_CMD empty"
    run DEV_CMD; exit $?
  fi
  trap 'echo; down dev; exit 0' INT TERM
  up dev || exit 1
  echo "dev: running (PORT_OFFSET=$PORT_OFFSET); Ctrl-C stops"
  if ls "$RUN"/dev-*.log >/dev/null 2>&1; then
    tail -n 0 -f "$RUN"/dev-*.log &
    wait $!
  else
    while :; do sleep 3600; done
  fi
}

cmd_health() {
  local n rc=0
  need_components
  for n in $COMPONENTS; do
    if healthy "$n"; then echo "$n: healthy (port $(var "$n" PORT))"; else echo "$n: down"; rc=1; fi
  done
  return $rc
}

cmd_e2e() { # cmd_e2e [args]
  local rc
  mkdir -p artifacts/e2e "$RUN"
  if [ "$HAS_SERVER" = 1 ] && [ -n "$COMPONENTS" ]; then
    rm -f "$RUN/e2e.started"
    up dev "$RUN/e2e.started" || { down dev "$RUN/e2e.started"; exit 1; }
    run E2E_CMD "$@"; rc=$?
    down dev "$RUN/e2e.started"
    exit $rc
  fi
  run E2E_CMD "$@"
}

cmd_load() {
  local lv rc=0 target
  [ "$HAS_LOAD" = 1 ] || skip "HAS_LOAD=0"
  [ -n "${LOAD_CMD:-}" ] || skip "LOAD_CMD empty"
  need_components
  target=${LOAD_TARGET_USERS:-}
  [ -n "$target" ] || die "LOAD_TARGET_USERS is empty in .harness/config"
  # Never reuse the dev servers: production-like commands on separate ports.
  set_ports $((PORT_OFFSET + 100))
  trap 'down prod' EXIT
  up prod || exit 1
  for lv in ${LOAD_LEVELS:-$target}; do
    mkdir -p "artifacts/load/u$lv"
    echo "load: $lv users for ${LOAD_DURATION:-2m}"
    if [ "$lv" = "$target" ]; then
      USERS=$lv DURATION=${LOAD_DURATION:-2m} OUT_DIR=artifacts/load/u$lv TARGET_CHECK=1 bash -c "$LOAD_CMD"
      rc=$?
    else
      USERS=$lv DURATION=${LOAD_DURATION:-2m} OUT_DIR=artifacts/load/u$lv bash -c "$LOAD_CMD"
    fi
  done
  exit $rc
}

cmd_bench() {
  [ -n "${BENCH_CMD:-}" ] || skip "BENCH_CMD empty (SPEC 10b N/A)"
  mkdir -p artifacts/bench
  run BENCH_CMD
}

cmd_security() {
  [ -n "${SECURITY_CMD:-}" ] || skip "SECURITY_CMD empty"
  mkdir -p artifacts/security
  run SECURITY_CMD
}

# ---------- staged files ----------
# The pre-commit hook checks only what the commit changes: unchanged files passed when they were
# committed. A direct `check` (the gates) still checks the whole tree.
# STAGED: staged paths (added, copied, modified, renamed), one per line. PARTIAL: the ones that
# also have unstaged changes. Read once per run, with one git call: each "XY path" entry of
# `git status -z` gives the staged (X) and the unstaged (Y) state.
STAGED= PARTIAL= STAGED_READ=
read_staged() {
  local e x y f old
  [ -n "$STAGED_READ" ] && return 0
  STAGED_READ=1
  while IFS= read -r -d '' e; do
    x=${e:0:1}; y=${e:1:1}; f=${e:3}
    case $x in R|C) IFS= read -r -d '' old ;; esac
    case $x in A|C|M|R) ;; *) continue ;; esac
    STAGED="$STAGED$f"$'\n'
    case $y in ' ') ;; *) PARTIAL="$PARTIAL$f"$'\n' ;; esac
  done < <(git status --porcelain -z --untracked-files=no 2>/dev/null)
}

is_partial() { case $'\n'$PARTIAL in *$'\n'"$1"$'\n'*) return 0 ;; esac; return 1; }

under() { # under <path> <paths>: the path is one of the space-separated paths, or inside one
  local p
  for p in $2; do p=${p%/}; case $1 in "$p"|"$p"/*) return 0 ;; esac; done
  return 1
}

hits() { # hits <git grep -n output> [skip]: print file:line per hit; with skip, ignore lines holding harness:allow-secret
  local line f rest n=0
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    if [ -n "${2:-}" ]; then case $line in *harness:allow-secret*) continue ;; esac; fi
    f=${line%%:*}; rest=${line#*:}
    printf '%s:%s\n' "$f" "${rest%%:*}"; n=$((n + 1))
  done <<EOF
$1
EOF
  [ "$n" -gt 0 ]
}

literal() { # literal <path>...: LIT = the paths as literal pathspecs
  local f
  LIT=()
  for f in "$@"; do LIT+=(":(literal)$f"); done
}

# no_secret [file...]: fail if SECRET_PATTERN (ERE, case-insensitive) matches the staged content
# of the files given, or of every tracked file. Prints file:line only, never the matched text.
# A line containing harness:allow-secret (a test fake, a documented example) is ignored.
# .harness/config holds the pattern itself.
no_secret() {
  local out rc
  [ -n "${SECRET_PATTERN:-}" ] || return 0
  if [ $# -gt 0 ]; then literal "$@"; else LIT=(.); fi
  out=$(git grep --cached -nIiE -e "$SECRET_PATTERN" -- "${LIT[@]}" ':(exclude).harness/config' ':(exclude).harness/guardrail-samples'); rc=$?
  if [ $rc -gt 1 ]; then echo "FAIL: guardrail pattern error: SECRET_PATTERN"; return 1; fi
  if [ -n "$out" ] && hits "$out" skip; then
    echo "FAIL: possible secret in a staged or tracked file. Read it from the environment or a secret store instead; mark a test fake with harness:allow-secret"
    return 1
  fi
  return 0
}

# no_debug [file...]: fail if the staged content of the files given, or of every tracked file,
# still holds a temporary probe tagged with the debug probe tag (HM-DEBU[G]). Markdown is
# skipped: docs and AGENTS.md mention the tag. The tag is never spelled out in this file, so the
# file does not match itself.
no_debug() {
  local out rc tag=HM-DEBU
  tag=${tag}G
  if [ $# -gt 0 ]; then literal "$@"; else LIT=(.); fi
  out=$(git grep --cached -nI -e 'HM-DEBU[G]' -- "${LIT[@]}" ':(exclude)*.md'); rc=$?
  if [ $rc -gt 1 ]; then echo "FAIL: guardrail error: debug probe search"; return 1; fi
  if [ -n "$out" ]; then
    hits "$out"
    echo "FAIL: temporary debug probes ($tag) left in staged or tracked files; remove them before committing"
    return 1
  fi
  return 0
}

# no_match <regex> <message> <dir or file>...: fail if the regex matches in them.
# A broken regex (grep exit 2) fails loudly instead of passing silently.
no_match() {
  local re=$1 msg=$2 out rc
  shift 2
  [ $# -gt 0 ] || return 0
  out=$(grep -rnE -- "$re" "$@"); rc=$?
  if [ $rc -eq 0 ]; then echo "$out"; echo "FAIL: $msg"; return 1; fi
  if [ $rc -ne 1 ]; then echo "FAIL: guardrail pattern error: $re"; return 1; fi
  return 0
}

dirs_present() { # dirs_present <dirs>: DIRS = the ones that exist; warns about the others
  local d
  DIRS=()
  for d in $1; do
    if [ -d "$d" ]; then DIRS+=("$d"); else echo "warn: $d not found (check TEST_DIRS/E2E_DIRS)"; fi
  done
}

cmd_fmt() { # cmd_fmt [files]
  [ -n "${FORMAT_CMD:-}" ] || skip "FORMAT_CMD empty"
  run FORMAT_CMD "$@"
}

# format_staged: the pre-commit hook's auto-format. Formats the staged files that are not
# Markdown, not under PROTECTED and not harness files (scripts/hm.sh, scripts/harness-state.sh,
# .githooks/, .harness/: copies that must stay as the skill ships them), then stages the result.
# A file that also has unstaged changes is left alone (staging it again would commit those
# changes too); LINT_CMD still checks it. FORMAT_CMD must take the files as "$@", or it would
# format files nobody staged.
format_staged() {
  local f partial=
  local files=()
  [ -n "${FORMAT_CMD:-}" ] || return 0
  case $FORMAT_CMD in
    *'"$@"'*) ;;
    *) echo "fmt: skipped (FORMAT_CMD has no \"\$@\")"; return 0 ;;
  esac
  read_staged
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    case $f in *.md|scripts/hm.sh|scripts/harness-state.sh|.githooks/*|.harness/*) continue ;; esac
    under "$f" "${PROTECTED:-}" && continue
    if is_partial "$f"; then partial="$partial $f"; continue; fi
    files+=("$f")
  done <<EOF
$STAGED
EOF
  [ -n "$partial" ] && echo "fmt: skipped, also has unstaged changes:$partial"
  [ ${#files[@]} -gt 0 ] || return 0
  run FORMAT_CMD "${files[@]}" || { echo "FAIL: FORMAT_CMD"; return 1; }
  git add -- "${files[@]}" || return 1
  echo "fmt: formatted and re-staged ${#files[@]} file(s)"
}

is_task_file() { # docs/tasks/<id>.md, not the template and not in a subfolder
  case $1 in docs/tasks/[A-Za-z0-9]*.md) ;; *) return 1 ;; esac
  case ${1#docs/tasks/} in */*) return 1 ;; esac
  return 0
}

check_hook() { # the pre-commit hook: the guardrails on the staged files only
  local f
  local files=() tests=() e2e=()
  read_staged
  [ -n "$STAGED" ] || return 0
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    files+=("$f")
    if [ -n "${PROTECTED:-}" ] && under "$f" "$PROTECTED" && git rev-parse -q --verify harness-init >/dev/null; then
      echo "FAIL: protected path changed (staged): $f"; return 1
    fi
    under "$f" "${TEST_DIRS:-}" && tests+=("$f")
    under "$f" "${E2E_DIRS:-}" && e2e+=("$f")
    if is_task_file "$f"; then
      if is_partial "$f"; then task_values_ok "$f" index || return 1; else task_values_ok "$f" || return 1; fi
    fi
  done <<EOF
$STAGED
EOF
  no_secret "${files[@]}" || return 1
  no_debug "${files[@]}" || return 1
  if [ -n "${SKIP_PATTERN:-}" ] && [ ${#tests[@]} -gt 0 ]; then
    no_match "$SKIP_PATTERN" "skipped tests are not allowed" "${tests[@]}" || return 1
  fi
  if [ "$HAS_UI" = 1 ] && [ -n "${SELECTOR_PATTERN:-}" ] && [ ${#e2e[@]} -gt 0 ]; then
    no_match "$SELECTOR_PATTERN" "E2E must select by the test-id attribute" "${e2e[@]}" || return 1
  fi
  return 0
}

check_all() { # a direct `check`: the guardrails on the whole tree
  local f out
  if [ -n "${PROTECTED:-}" ] && git rev-parse -q --verify harness-init >/dev/null; then
    out=$(git diff --name-only harness-init HEAD -- $PROTECTED; git status --porcelain -- $PROTECTED)
    if [ -n "$out" ]; then
      printf '%s\n' "$out"
      echo "FAIL: protected path changed (committed, staged, modified, or new file) in: $PROTECTED"; return 1
    fi
  fi
  no_secret || return 1
  no_debug || return 1
  if [ -n "${SKIP_PATTERN:-}" ]; then
    dirs_present "${TEST_DIRS:-}"
    if [ ${#DIRS[@]} -gt 0 ]; then no_match "$SKIP_PATTERN" "skipped tests are not allowed" "${DIRS[@]}" || return 1; fi
  fi
  if [ "$HAS_UI" = 1 ] && [ -n "${SELECTOR_PATTERN:-}" ]; then
    dirs_present "${E2E_DIRS:-}"
    if [ ${#DIRS[@]} -gt 0 ]; then no_match "$SELECTOR_PATTERN" "E2E must select by the test-id attribute" "${DIRS[@]}" || return 1; fi
  fi
  for f in docs/tasks/[A-Za-z0-9]*.md; do
    [ -e "$f" ] || continue
    task_values_ok "$f" || return 1
  done
  return 0
}

# staged_code_files: CODE_FILES = the staged files that are not Markdown (what the hook lints).
staged_code_files() {
  local f
  CODE_FILES=()
  read_staged
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    case $f in *.md) continue ;; esac
    CODE_FILES+=("$f")
  done <<EOF
$STAGED
EOF
}

cmd_check() { # cmd_check [--hook]
  local hook=${1:-}
  if [ "$hook" = --hook ]; then
    format_staged || exit 1
    check_hook || exit 1
  else
    check_all || exit 1
  fi
  if [ -n "${LINT_CMD:-}" ]; then
    if [ "$hook" = --hook ]; then
      staged_code_files
      if [ ${#CODE_FILES[@]} -eq 0 ]; then
        echo "lint: skipped (no code files staged)"
      else
        case $LINT_CMD in
          *'"$@"'*) run LINT_CMD "${CODE_FILES[@]}" || { echo "FAIL: LINT_CMD"; exit 1; } ;;
          *) run LINT_CMD || { echo "FAIL: LINT_CMD"; exit 1; } ;;
        esac
      fi
    else
      run LINT_CMD || { echo "FAIL: LINT_CMD"; exit 1; }
    fi
  fi
  # The type checker reads the whole project, so it runs only at the gates, never per commit.
  if [ "$hook" != --hook ] && [ -n "${TYPECHECK_CMD:-}" ]; then
    run TYPECHECK_CMD || { echo "FAIL: TYPECHECK_CMD"; exit 1; }
  fi
  echo "check: ok"
}

# task_fields (stdin): TF_STATUS, TF_REVIEW, TF_TYPE = the first "- Key: value" of each, trimmed.
# Shell builtins only: a sed per field made `check` slow on Windows as tasks piled up.
task_fields() {
  local line v gs= gr= gt=
  TF_STATUS= TF_REVIEW= TF_TYPE=
  while IFS= read -r line || [ -n "$line" ]; do
    line=${line%$'\r'}
    case $line in
      "- Status:"*) [ -n "$gs" ] && continue; gs=1; v=${line#- Status:} ;;
      "- Review:"*) [ -n "$gr" ] && continue; gr=1; v=${line#- Review:} ;;
      "- Type:"*) [ -n "$gt" ] && continue; gt=1; v=${line#- Type:} ;;
      *) continue ;;
    esac
    v=${v#"${v%%[![:space:]]*}"}; v=${v%"${v##*[![:space:]]}"}
    case $line in
      "- Status:"*) TF_STATUS=$v ;;
      "- Review:"*) TF_REVIEW=$v ;;
      *) TF_TYPE=$v ;;
    esac
  done
}

task_values_ok() { # task_values_ok <file> [index]: Status, Review and Type hold allowed values
  if [ "${2:-}" = index ]; then task_fields < <(git show ":$1" 2>/dev/null); else task_fields < "$1"; fi
  case $TF_STATUS in Todo|"In Progress"|"In Review"|Done|Dropped) ;; *) echo "FAIL: bad Status in $1: '$TF_STATUS'"; return 1 ;; esac
  case $TF_REVIEW in ''|each|batch) ;; *) echo "FAIL: bad Review in $1: '$TF_REVIEW' (each or batch)"; return 1 ;; esac
  case $TF_TYPE in ''|feature|bug|chore|spike|docs) ;; *) echo "FAIL: bad Type in $1: '$TF_TYPE' (feature, bug, chore, spike or docs)"; return 1 ;; esac
  return 0
}

# ---------- selftest ----------
# Proves the guardrail patterns in one run, without throwaway files in the project or a scratch
# repository: built-in samples for the secret and debug checks, the project's own samples from
# .harness/guardrail-samples for the stack-specific patterns, a bad task file under .run/, then
# `check` on the real tree. Secret-looking samples are assembled at run time, so this file never
# matches SECRET_PATTERN itself.

SAMPLES=.harness/guardrail-samples
ST_FAIL=0

st_expect() { # st_expect <hit|miss> <label> <grep flags or -> <regex> <text>
  local flags=$3 rc
  [ "$flags" = - ] && flags=
  printf '%s\n' "$5" | grep -q $flags -E -- "$4"; rc=$?
  if [ $rc -gt 1 ]; then echo "FAIL $2: pattern error in $4"; ST_FAIL=1; return; fi
  if [ "$1" = hit ] && [ $rc -ne 0 ]; then echo "FAIL $2: not caught: $5"; ST_FAIL=1; return; fi
  if [ "$1" = miss ] && [ $rc -eq 0 ]; then echo "FAIL $2: caught but must pass: $5"; ST_FAIL=1; return; fi
  echo "ok   $2: $5"
}

samples_of() { # samples_of <kind>: the texts of "<kind>: <text>" lines in the samples file
  [ -f "$SAMPLES" ] || return 0
  sed -n "s/^$1:[[:space:]]*//p" "$SAMPLES" | tr -d '\r'
}

st_samples() { # st_samples <hit|miss> <kind> <grep flags or -> <regex> <required: 1|0>
  local line n=0
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    n=$((n + 1))
    st_expect "$1" "$2" "$3" "$4" "$line"
  done <<EOF
$(samples_of "$2")
EOF
  if [ "$5" = 1 ] && [ $n -eq 0 ]; then echo "FAIL $2: no '$2:' sample in $SAMPLES"; ST_FAIL=1; fi
}

cmd_selftest() {
  local p k t rc bad=$RUN/selftest-task.md
  mkdir -p "$RUN"
  [ -f "$SAMPLES" ] || echo "warn: $SAMPLES not found; only the built-in samples run"
  if [ -n "${SECRET_PATTERN:-}" ]; then
    k="-----BEGIN RSA PRIV"; k="$k""ATE KEY-----"
    t="AKI"; t="${t}AABCDEFGHIJKLMNOP"
    st_expect hit secret -i "$SECRET_PATTERN" "$k"
    st_expect hit secret -i "$SECRET_PATTERN" "$t"
    st_expect hit secret -i "$SECRET_PATTERN" "pass""word = \"Wq7-vT9kLm2x\""
    st_expect miss secret-allow -i "$SECRET_PATTERN" 'password = os.environ["APP_PASSWORD"]'
    st_samples hit secret -i "$SECRET_PATTERN" 0
    st_samples miss secret-allow -i "$SECRET_PATTERN" 0
  else
    echo "skip secret: SECRET_PATTERN empty"
  fi
  t="HM-DEBU"; t="${t}G"
  st_expect hit debug - 'HM-DEBU[G]' "print('$t value')"
  if [ -n "${SKIP_PATTERN:-}" ]; then
    st_samples hit skip - "$SKIP_PATTERN" 1
  else
    echo "skip skip: SKIP_PATTERN empty"
  fi
  if [ "$HAS_UI" = 1 ] && [ -n "${SELECTOR_PATTERN:-}" ]; then
    st_samples hit selector-deny - "$SELECTOR_PATTERN" 1
    st_samples miss selector-allow - "$SELECTOR_PATTERN" 1
  else
    echo "skip selector: HAS_UI=$HAS_UI or SELECTOR_PATTERN empty"
  fi
  printf '%s\n' '# Task x' '- Status: Doing' > "$bad"
  if task_values_ok "$bad" >/dev/null; then echo "FAIL task fields: a bad Status passed"; ST_FAIL=1; else echo "ok   task fields: a bad Status fails"; fi
  rm -f "$bad"
  for p in ${PROTECTED:-}; do
    if [ -e "$p" ]; then echo "ok   protected: $p exists"; else echo "FAIL protected: $p not found"; ST_FAIL=1; fi
  done
  echo "-- check on the current tree"
  ( cmd_check ); rc=$?
  [ $rc -eq 0 ] || ST_FAIL=1
  if [ "$ST_FAIL" = 0 ]; then echo "selftest: ok"; else echo "selftest: FAIL"; exit 1; fi
}

# ---------- doctor ----------
# Everything that makes a harness command fail for a reason outside the code, in one report, so
# a new machine or a teammate's checkout is diagnosed without reading the scripts.

DR_FAIL=0
dr() { printf '%-5s %s\n' "$1" "$2"; [ "$1" = FAIL ] && DR_FAIL=$((DR_FAIL + 1)); return 0; }

ver_ge() { # ver_ge <have> <want>: dotted numeric versions, have >= want
  local a=$1 b=$2 x y
  while [ -n "$a$b" ]; do
    x=${a%%.*}; y=${b%%.*}
    x=${x%%[!0-9]*}; y=${y%%[!0-9]*}
    [ "${x:-0}" -gt "${y:-0}" ] && return 0
    [ "${x:-0}" -lt "${y:-0}" ] && return 1
    case $a in *.*) a=${a#*.} ;; *) a= ;; esac
    case $b in *.*) b=${b#*.} ;; *) b= ;; esac
  done
  return 0
}

cmd_doctor() {
  local v k line c p h d parent abs hp f uses_http=0
  # Tools
  v=$(git --version 2>/dev/null); v=${v#git version }; v=${v%% *}
  if [ -z "$v" ]; then dr FAIL "git not found"
  elif ver_ge "$v" 2.31; then dr ok "git $v"
  else dr FAIL "git $v is older than 2.31 (worktrees and path output need it)"; fi
  v=${BASH_VERSION%%(*}
  if ver_ge "$v" 3.2; then dr ok "bash $v"; else dr FAIL "bash $v is older than 3.2"; fi
  case ${OSTYPE:-} in
    msys*|cygwin*) dr ok "Git Bash ($OSTYPE)" ;;
    linux*)
      if grep -qi microsoft /proc/version 2>/dev/null; then
        case $(pwd) in /mnt/*) dr warn "WSL bash on a Windows folder: use Git Bash (put Git's bin folder before C:\\Windows\\System32 in PATH)" ;; esac
      fi ;;
  esac
  for c in $COMPONENTS; do case $(var "$c" HEALTH) in *http_has*) uses_http=1 ;; esac; done
  if [ "$uses_http" = 1 ]; then
    if command -v curl >/dev/null 2>&1; then dr ok "curl (for http_has)"; else dr FAIL "curl not found; the http_has health checks need it"; fi
  fi
  # Config values
  case $MODE in FULL|HACKATHON) dr ok "MODE=$MODE" ;; *) dr FAIL "MODE must be FULL or HACKATHON, got '$MODE'" ;; esac
  if [ -n "${INTEGRATION:-}" ]; then
    if git rev-parse -q --verify "refs/heads/$INTEGRATION" >/dev/null || git rev-parse -q --verify "refs/remotes/${REMOTE:-origin}/$INTEGRATION" >/dev/null; then
      dr ok "INTEGRATION=$INTEGRATION exists"
    else
      dr warn "INTEGRATION=$INTEGRATION is not a branch here yet"
    fi
  fi
  if [ "${PARALLEL:-1}" -gt 1 ] 2>/dev/null && [ "${WORKTREES:-0}" != 1 ]; then dr FAIL "PARALLEL=$PARALLEL needs WORKTREES=1"; fi
  if [ "${WORKTREES:-0}" = 1 ]; then
    d=${WORKTREE_DIR:-../${PWD##*/}-wt}
    case $d in
      *' '*) dr FAIL "WORKTREE_DIR '$d' has a space" ;;
      *)
        parent=$(dirname "$d")
        if abs=$(cd "$parent" 2>/dev/null && pwd -P); then
          abs=$abs/${d##*/}
          case "$abs/" in "$(pwd -P)/"*) dr FAIL "WORKTREE_DIR '$d' is inside the repository (test runners would scan other worktrees)" ;; *) dr ok "WORKTREE_DIR=$d" ;; esac
        else
          dr warn "WORKTREE_DIR '$d': its parent folder does not exist"
        fi ;;
    esac
  fi
  if [ -f .harness/local ]; then
    case ${PORT_OFFSET:-0} in ''|*[!0-9]*) dr FAIL ".harness/local: PORT_OFFSET must be a number, got '$PORT_OFFSET'" ;; esac
  fi
  for k in TYPECHECK_CMD FORMAT_CMD SECRET_PATTERN; do
    grep -q "^$k=" .harness/config || dr warn "$k missing from .harness/config (set up by an older harness; hm-setup refresh adds it)"
  done
  # Commands
  while IFS= read -r line || [ -n "$line" ]; do
    line=${line%$'\r'}
    case $line in ''|'#'*) continue ;; esac
    k=${line%%=*}; v=${line#*=}
    case $k in *_CMD|*_DEV|*_PROD|*_HEALTH) ;; *) continue ;; esac
    case $v in
      '...'|'... '*|*' ...'|*'<'[a-z]*'>'*) dr warn "$k looks like a placeholder: $v" ;;
    esac
  done < .harness/config
  [ -n "${TEST_CMD:-}" ] || dr FAIL "TEST_CMD is empty (bash scripts/hm.sh test cannot run)"
  for k in TEST_CMD E2E_CMD LINT_CMD FORMAT_CMD; do
    v=${!k:-}
    [ -n "$v" ] || continue
    case $v in *'"$@"'*) ;; *) dr warn "$k has no \"\$@\": it cannot be limited to the files given" ;; esac
  done
  [ -n "${LINT_CMD:-}" ] || dr warn "LINT_CMD is empty: the pre-commit hook checks the guardrails only"
  # Components
  if [ "$HAS_SERVER" = 1 ]; then
    [ -n "$COMPONENTS" ] || dr FAIL "HAS_SERVER=1 but COMPONENTS is empty"
    for c in $COMPONENTS; do
      [ -n "$(var "$c" DEV)" ] || dr FAIL "${c}_DEV is not set"
      h=$(var "$c" HEALTH)
      if [ -z "$h" ]; then dr FAIL "${c}_HEALTH is not set"; continue; fi
      [ "$HAS_LOAD" = 1 ] && [ -z "$(var "$c" PROD)" ] && dr FAIL "${c}_PROD is not set (HAS_LOAD=1)"
      p=$(var "$c" PORT)
      if healthy "$c"; then dr ok "$c: running (port ${p:-none})"
      elif [ -n "$p" ] && port_busy "$p"; then dr warn "$c: port $p is taken by something that is not this project's $c (dev-bg will refuse)"
      else dr ok "$c: port ${p:-none} free"; fi
    done
  fi
  # Hooks and line endings
  hp=$(git config core.hooksPath 2>/dev/null)
  if [ "$hp" = .githooks ] && [ -f .githooks/pre-commit ]; then dr ok "git hooks (.githooks)"
  else dr FAIL "git hooks are not active: run bash scripts/hm.sh setup"; fi
  # The first line is enough (a converted file has CR on every line), and bash's own read keeps
  # the CR: grep on Git for Windows treats CRLF as a line end and would not see it.
  for f in scripts/hm.sh scripts/harness-state.sh .githooks/pre-commit .githooks/commit-msg .harness/config; do
    [ -f "$f" ] || continue
    line=; IFS= read -r line < "$f" || :
    case $line in *$'\r') dr FAIL "$f has CRLF line endings (bash breaks on them; .gitattributes must pin LF, then re-checkout)" ;; esac
  done
  if [ -n "${PROTECTED:-}" ] && ! git rev-parse -q --verify harness-init >/dev/null; then
    dr warn "no harness-init tag: the PROTECTED check is off until hm-setup tags it"
  fi
  if [ "$DR_FAIL" -eq 0 ]; then echo "doctor: ok"; else echo "doctor: $DR_FAIL problem(s)"; exit 1; fi
}

cmd_help() {
  sed -n '2,/^# A command turned off/p' "$0" | sed 's/^# \{0,1\}//'
  echo
  echo "This worktree (PORT_OFFSET=$PORT_OFFSET, HM_SLOT=$HM_SLOT):"
  local c
  if [ "$HAS_SERVER" = 1 ]; then
    for c in $COMPONENTS; do echo "  component $c: port $(var "$c" PORT)"; done
  else
    echo "  dev-bg, stop, health, load: skip (HAS_SERVER=0)"
  fi
  [ "$HAS_LOAD" = 1 ] && [ -n "${LOAD_CMD:-}" ] || echo "  load: skip"
  [ -n "${BENCH_CMD:-}" ] || echo "  bench: skip"
  [ -n "${SECURITY_CMD:-}" ] || echo "  security: skip"
  [ -n "${MIGRATE_CMD:-}" ] || echo "  migrate: skip"
  [ -n "${SECRET_PATTERN:-}" ] || echo "  check: no SECRET_PATTERN (secret guardrail off)"
  case ${LINT_CMD:-} in
    '') echo "  check: no LINT_CMD (guardrails only)" ;;
    *'"$@"'*) ;;
    *) echo "  check: LINT_CMD has no \"\$@\" (the pre-commit hook lints the whole project on every commit)" ;;
  esac
  [ -n "${TYPECHECK_CMD:-}" ] || echo "  check: no TYPECHECK_CMD (no type check at the gates)"
  case ${FORMAT_CMD:-} in
    '') echo "  fmt: skip (no FORMAT_CMD; the pre-commit hook formats nothing)" ;;
    *'"$@"'*) ;;
    *) echo "  fmt: FORMAT_CMD has no \"\$@\" (the pre-commit hook cannot format only the staged files)" ;;
  esac
  case ${TEST_CMD:-} in *'"$@"'*) ;; *) echo "  test: TEST_CMD has no \"\$@\" (arguments ignored; always the full suite)" ;; esac
  case ${E2E_CMD:-} in *'"$@"'*) ;; *) echo "  e2e: E2E_CMD has no \"\$@\" (arguments ignored; always the full suite)" ;; esac
}

TIMEOUT=${HEALTH_TIMEOUT:-60}
USE_SETSID=
case ${OSTYPE:-} in msys*|cygwin*) ;; *) command -v setsid >/dev/null 2>&1 && USE_SETSID=1 ;; esac

[ -f .harness/config ] || die ".harness/config not found in $(pwd)"
load_config

case ${1:-help} in
  setup)  cmd_setup ;;
  dev)    cmd_dev ;;
  dev-bg) need_components; up dev ;;
  stop)   need_components; down dev ;;
  health) cmd_health ;;
  status) bash scripts/harness-state.sh status ;;
  test|e2e|check)
    c=$1; shift; reuse=0
    [ "${1:-}" = --reuse ] && { reuse=1; shift; }
    case $c in test) f="run TEST_CMD" ;; e2e) f=cmd_e2e ;; check) f=cmd_check ;; esac
    if [ $# -eq 0 ]; then recorded "$c" "$reuse" $f; else $f "$@"; fi
    exit $? ;;
  load)   cmd_load ;;
  bench)  cmd_bench ;;
  security) cmd_security ;;
  migrate) [ -n "${MIGRATE_CMD:-}" ] || skip "MIGRATE_CMD empty"; run MIGRATE_CMD ;;
  fmt)    shift; cmd_fmt "$@" ;;
  selftest) cmd_selftest ;;
  doctor) cmd_doctor ;;
  help|-h|--help) cmd_help ;;
  *) echo "unknown command '$1'" >&2; cmd_help >&2; exit 1 ;;
esac
