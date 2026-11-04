#!/usr/bin/env bash
# harness-state.sh - deterministic state helper for the harness (hm-auto, hm-dev, hm-review).
#
# It never calls an agent and never changes branches or files of the project. It only writes
# its own run files under .run/hm-auto/ in the main worktree (and fetches REMOTE when MERGE=pr).
# It reads .harness/config, docs/tasks/*.md on the integration branch and on task branches,
# review files and git refs; hands out the next harness steps (several at once when
# PARALLEL > 1) and checks each step's result.
#
# Usage: scripts/harness-state.sh <command> [args]
#   status               Task table: status, review policy, where it lives, next action
#   plan <target>        Next step per task from the current state. Changes nothing.
#   worktree <name>      Where Task <name> (or a helper worktree such as review-3) is worked on:
#                        dir, branch, base, port offset, blocking dependency
#   start-check <id>     Every precondition of "Start Task <id>." that files and git can answer:
#                        result=ok with dir, offset, base, branch_exists, or result=stop (exit 3)
#                        with the reason (status, a branch someone else may own, an unmerged
#                        dependency, PARALLEL tasks In Progress, a dirty worktree)
#   notes               Codebase notes for dev sub-agents: fresh | stale | missing | skip
#   run-begin <target>   Validate, take the lock, reset per-run counters (an old --no-demo
#                        flag is accepted and ignored: a demo never holds a task now)
#   next [--all]         Hand out one step (key=value lines), or all that can start ("--" between)
#   check <step> [--next] Verify a step that next handed out; --next: then "--" and next --all.
#                        Appends the step's timing and result to artifacts/runs/<run>/summary.tsv
#   hold <id> [reason]   Hand out nothing for Task <id> until release (e.g. while its demo runs)
#   release <id>         End a hold
#   run-end              Release the lock and forget pending steps and holds
#   report [run]         Where the time went in a run (default: the active or latest run):
#                        steps and minutes per step kind and per task, the slowest step, and the
#                        cost drivers (continues, re-reviews, questions). Reads summary.tsv only.
#
# Targets: <id> | <id>,<id>,... | N-M (numeric ids) | all | review-all
# Env:     MAX_CONTINUE (default 2), MAX_REREVIEW (default 1),
#          REVIEW_ALL_TASKS (default 3), REVIEW_ALL_LINES (default 600): in MODE=FULL, status and
#          a batch merge's check add "(suggest: Review all.)" to the review backlog line once
#          that many tasks were merged without their own review, or that many lines changed
#          since the last review all. A suggestion only; nothing runs by itself.
# Exit:    0 ok, 1 usage or precondition error, 3 needs a human
#
# Conventions it relies on (FLOW.md "Rules the script depends on"):
#   .harness/config     MODE, INTEGRATION, MERGE (local|pr), REMOTE, PARALLEL, WORKTREES,
#                       WORKTREE_DIR, PORT_STEP, STACK (1: a task may start on the unmerged branch
#                       of its one dependency once that one's development is done; one level
#                       only; its review and merge wait for that dependency's merge)
#   docs/tasks/<id>.md  "- Status: Todo|In Progress|In Review|Done|Dropped", "- Review: each|batch",
#                       "- Type: feature|bug|chore|spike|docs" (missing = feature; only feature
#                       and bug have a demo), "- Depends on: <id>, <id> | none";
#                       ids match [A-Za-z0-9][A-Za-z0-9._-]*
#   branches            task/<id> per task; review-all fixes on fix/review-all-<k>
#   reviews             artifacts/review/task-<id>-review-<k>.md and review-all-<k>.md in the main
#                       worktree; applied copies committed to docs/reviews/; lines
#                       "Verdict: APPROVE|CHANGES REQUESTED", "Commit: <sha>", rows "| RV-n | Blocker |"
#   commits             "wip(task-<id>): ..." only when context ran out; review fixes "fix(...)"
#   worktrees           <WORKTREE_DIR>/<name>, with PORT_OFFSET in <worktree>/.harness/local
#   notes               artifacts/notes/codebase.md in the main worktree, line "Commit: <sha>"
set -u -o pipefail

CONFIG=.harness/config
TASK_DIR=docs/tasks
APPLIED_DIR=docs/reviews
REVIEW_DIR=artifacts/review
STATE_DIR=.run/hm-auto
LOCK=$STATE_DIR/lock
RUN_ENV=$STATE_DIR/run.env
STEPS_DIR=$STATE_DIR/steps
HOLD_DIR=$STATE_DIR/hold
NOTES=artifacts/notes/codebase.md
MAX_CONTINUE=${MAX_CONTINUE:-2}
MAX_REREVIEW=${MAX_REREVIEW:-1}
SUBAGENT_NOTE="You are a sub-agent started by hm-auto in a fresh context. You cannot talk to the user. If you need a decision, stop and make the question your final message; the orchestrator will relay the answer."
OUT_KEY=result
FETCH_WARN=

say() { printf '%s=%s\n' "$1" "$2"; }
fail() { say "$OUT_KEY" error; say reason "$*"; exit 1; }
needs_human() { log_step "$1"; say "$OUT_KEY" "$1"; say reason "$2"; exit 3; }

# Timing of each checked step goes to artifacts/runs/<run>/summary.tsv (step, action, task,
# started, seconds, result), so a run can be tuned (PARALLEL, where the time goes). cmd_check
# sets STEP_NO and the others from the step file; log_step writes once and clears STEP_NO.
STEP_NO= STEP_ACTION= STEP_TASK= STEP_STARTED= STEP_STARTED_AT=
log_step() { # log_step <result>
  local f now
  [ -n "$STEP_NO" ] && [ -n "$STEP_STARTED" ] || { STEP_NO=; return 0; }
  f=artifacts/runs/$RUN_ID/summary.tsv
  mkdir -p "artifacts/runs/$RUN_ID"
  [ -f "$f" ] || printf 'step\taction\ttask\tstarted\tseconds\tresult\n' > "$f"
  now=$(date +%s)
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$STEP_NO" "$STEP_ACTION" "$STEP_TASK" "$STEP_STARTED_AT" "$((now - STEP_STARTED))" "$1" >> "$f"
  STEP_NO=
}

usage() { sed -n '2,32p' "$0" | sed 's/^# \{0,1\}//'; }

is_num() { case $1 in ''|*[!0-9]*) return 1 ;; esac; }

# Helpers return values in REPLY instead of printing them: on Windows every $(...) starts a
# process, and a status over a few tasks would otherwise start dozens.

# Absolute path usable from Git Bash and from PowerShell (C:/... on Windows).
abspath() { (cd "$1" 2>/dev/null && { pwd -W 2>/dev/null || pwd -P; }); }

# ---------- config and refs ----------

# read_config: every KEY=value line of .harness/config into CFG_<KEY> (the last line wins).
read_config() {
  local line k
  while IFS= read -r line || [ -n "$line" ]; do
    line=${line%$'\r'}
    case $line in *=*) ;; *) continue ;; esac
    k=${line%%=*}
    case $k in ''|[0-9]*|*[!A-Za-z0-9_]*) continue ;; esac
    printf -v "CFG_$k" '%s' "${line#*=}"
  done < "$CONFIG"
}

cfg() { local n=CFG_$1; REPLY=${!n:-${2:-}}; } # cfg <key> [default]

# wt_abs <dir>: WORKTREE_DIR made absolute against ROOT, without starting a process.
wt_abs() {
  local d=${1%/} base=$ROOT
  case $d in /*|[A-Za-z]:*) WT_ABS=$d; return ;; esac
  while :; do
    case $d in
      ./*) d=${d#./} ;;
      ../*) d=${d#../}; base=${base%/*} ;;
      *) break ;;
    esac
  done
  WT_ABS=$base/$d
}

ref_ok() { git rev-parse -q --verify "$1^{commit}" >/dev/null 2>&1; }

sha_of() { git rev-parse -q --verify "$1^{commit}" 2>/dev/null; }

load_project() { # load_project [nofetch]
  local common
  common=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || fail "not inside a git repository"
  case $common in
    */.git) ROOT=${common%/.git} ;;
    *) ROOT=$(abspath "$common/..") || fail "cannot find the main worktree" ;;
  esac
  cd "$ROOT" || fail "cannot cd to $ROOT"
  [ -f "$CONFIG" ] || fail "missing $CONFIG (run hm-req first)"
  read_config
  cfg MODE; MODE=$REPLY
  case $MODE in FULL|HACKATHON) ;; *) fail "MODE in $CONFIG must be FULL or HACKATHON, got '$MODE'" ;; esac
  cfg INTEGRATION main; INTEGRATION=$REPLY
  cfg MERGE local; MERGE=$REPLY
  case $MERGE in local|pr) ;; *) fail "MERGE in $CONFIG must be local or pr, got '$MERGE'" ;; esac
  cfg REMOTE origin; REMOTE=$REPLY
  cfg PARALLEL 1; PARALLEL=$REPLY
  is_num "$PARALLEL" && [ "$PARALLEL" -ge 1 ] || fail "PARALLEL in $CONFIG must be a number >= 1"
  cfg WORKTREES 0; WORKTREES=$REPLY
  [ "$PARALLEL" -gt 1 ] && [ "$WORKTREES" != 1 ] && fail "PARALLEL=$PARALLEL needs WORKTREES=1 in $CONFIG"
  cfg STACK 0; STACK=$REPLY
  [ "$STACK" = 1 ] && [ "$WORKTREES" != 1 ] && fail "STACK=1 needs WORKTREES=1 in $CONFIG"
  cfg PORT_STEP 10; PORT_STEP=$REPLY
  cfg WORKTREE_DIR "../${ROOT##*/}-wt"; wt_abs "$REPLY"
  # The integration branch is checked by load_tasks: its first git call fails without it.
  INT_REF=refs/heads/$INTEGRATION
  if [ "$MERGE" = pr ]; then
    if [ "${1:-}" != nofetch ]; then
      GIT_TERMINAL_PROMPT=0 git fetch -q "$REMOTE" 2>/dev/null || FETCH_WARN="could not fetch $REMOTE; using the last fetched refs"
    fi
    ref_ok "refs/remotes/$REMOTE/$INTEGRATION" && INT_REF=refs/remotes/$REMOTE/$INTEGRATION
  fi
  load_tasks
}

# Read every task file field, every applied review and every unmerged task branch with three git
# calls, into newline-separated tables (plain strings, so bash 3.2 works too). Starting git costs
# up to a second or more per call on some Windows machines, so later lookups use these tables.
#   FDB  "<ref>|<id>|<key>=<value>"   for "- Key: value" lines of docs/tasks/<id>.md on <ref>
#   BDB  "<id>=<ref> <local|remote>"  unmerged task/<id> branch (local wins over REMOTE)
#   SDB  "<ref>=<sha>"                head of each of those branches
#   RDB  "<ref>|<file>" and "<ref>|<file>|B"  applied reviews in docs/reviews/ (a file always
#        has its Verdict line), the |B lines for each Blocker row
#   RREFS " <ref> <ref> "             the refs RDB covers; other refs are asked from git
#   TASK_IDS                          ids of the task files on the integration branch (those with
#                                     a "- Status:" line, which `hm.sh check` requires), sorted
load_tasks() {
  local r s id refs=$INT_REF remotes= line ref rest path text key val k out ids=
  FDB=$'\n'; BDB=$'\n'; SDB=$'\n'; RDB=$'\n'
  [ "$MERGE" = pr ] && remotes=refs/remotes/$REMOTE/task/
  out=$(git for-each-ref --no-merged "$INT_REF" --format='%(refname) %(objectname)' refs/heads/task/ $remotes 2>/dev/null) \
    || fail "integration branch '$INTEGRATION' does not exist (INTEGRATION in $CONFIG)"
  while read -r r s; do
    [ -n "$r" ] || continue
    case $r in
      refs/heads/task/*) id=${r#refs/heads/task/}; BDB="$BDB$id=$r local"$'\n' ;;
      *) id=${r#refs/remotes/$REMOTE/task/}
         case $BDB in *$'\n'"$id="*) continue ;; esac
         BDB="$BDB$id=$r remote"$'\n' ;;
    esac
    SDB="$SDB$r=$s"$'\n'
    refs="$refs $r"
  done <<EOF
$out
EOF
  RREFS=" $refs "
  while IFS= read -r line; do
    line=${line%$'\r'}
    ref=${line%%:*}; rest=${line#*:}
    path=${rest%%:*}; text=${rest#*:}
    case $path in
      "$APPLIED_DIR"/*)
        case $text in
          Verdict:*) RDB="$RDB$ref|${path#"$APPLIED_DIR"/}"$'\n' ;;
          *) RDB="$RDB$ref|${path#"$APPLIED_DIR"/}|B"$'\n' ;;
        esac
        continue ;;
    esac
    id=${path#"$TASK_DIR"/}; id=${id%.md}
    key=${text#- }; key=${key%%:*}
    val=${text#*:}; val=${val#"${val%%[![:space:]]*}"}; val=${val%"${val##*[![:space:]]}"}
    k=$'\n'"$ref|$id|$key="
    case $FDB in *"$k"*) continue ;; esac
    FDB="$FDB$ref|$id|$key=$val"$'\n'
    if [ "$ref" = "$INT_REF" ] && [ "$key" = Status ]; then
      case $path in "$TASK_DIR"/[A-Za-z0-9]*.md) ;; *) continue ;; esac
      case $id in *[!A-Za-z0-9._-]*) continue ;; esac
      ids="$ids$id"$'\n'
    fi
  done < <(git grep --no-color -I -E -e '^- (Status|Review|Type|Core|Depends on):' \
    -e '^Verdict:' -e '^\|[[:space:]]*RV-[0-9]+[[:space:]]*\|[[:space:]]*Blocker[[:space:]]*\|' \
    $refs -- "$TASK_DIR/" "$APPLIED_DIR/" 2>/dev/null)
  TASK_IDS=
  [ -n "$ids" ] && TASK_IDS=$(printf '%s' "$ids" | sort -V)
}

ref_sha() { # ref_sha <ref>: REPLY = its sha, from SDB when load_tasks saw it
  local r=${SDB#*$'\n'"$1="}
  if [ "$r" != "$SDB" ]; then REPLY=${r%%$'\n'*}; return 0; fi
  REPLY=$(sha_of "$1")
}

need_tasks() { [ -n "$TASK_IDS" ] || fail "no task files in $TASK_DIR/ on ${INT_REF#refs/*/} (run hm-setup or hm-change)"; }

has_task() { case $'\n'"$TASK_IDS"$'\n' in *$'\n'"$1"$'\n'*) return 0 ;; esac; return 1; }

# ---------- reading task state ----------

field() { # field <ref> <id> <key>: REPLY = the value, empty if missing
  local k=$'\n'"$1|$2|$3=" r
  REPLY=
  r=${FDB#*"$k"}
  [ "$r" = "$FDB" ] && return 0
  REPLY=${r%%$'\n'*}
}

# task_ref <id>: sets TREF (ref holding the current task file) and TWHERE:
#   local  = unmerged local branch task/<id>
#   remote = unmerged branch only on REMOTE (MERGE=pr): someone else's, or pushed from elsewhere
#   int    = no unmerged branch; the integration branch is current
task_ref() {
  local k=$'\n'"$1=" r
  r=${BDB#*"$k"}
  if [ "$r" = "$BDB" ]; then TREF=$INT_REF; TWHERE=int; return; fi
  r=${r%%$'\n'*}
  TREF=${r% *}; TWHERE=${r##* }
}

int_status() { field "$INT_REF" "$1" Status; } # REPLY

review_policy() { field "$INT_REF" "$1" Review; [ "$REPLY" = batch ] || REPLY=each; } # REPLY

task_type() { field "$INT_REF" "$1" Type; REPLY=${REPLY:-feature}; } # REPLY

has_demo() { task_type "$1"; case $REPLY in feature|bug) return 0 ;; esac; return 1; }

# deps_of <id>: DEPS = the task IDs in "Depends on" ("1, 2", "Task 1, Task 2", "none").
deps_of() {
  local d
  DEPS=
  field "$INT_REF" "$1" "Depends on"
  set -f
  for d in ${REPLY//,/ }; do
    case $d in [Tt]ask) continue ;; [Tt]ask*) d=${d#[Tt]ask} ;; esac
    case $d in ''|[!A-Za-z0-9]*|*[!A-Za-z0-9._-]*|[Nn][Oo][Nn][Ee]) continue ;; esac
    DEPS="$DEPS $d"
  done
  set +f
}

# deps_block <id>: REPLY = the first dependency not merged into the integration branch yet.
deps_block() {
  local d
  deps_of "$1"
  for d in $DEPS; do
    int_status "$d"
    case $REPLY in "In Review"|Done) ;; *) REPLY=$d; return ;; esac
  done
  REPLY=
}

# stack_on <id>: REPLY = the dependency whose unmerged branch Task <id> may be built on (STACK=1),
# or empty. One level only: exactly one dependency is not merged, its development is finished
# (In Review or Done on its own local branch), and it has no unmerged dependency itself.
# Keeps TREF and TWHERE as they were (callers read them after task_action).
stack_on() {
  local d cand= n=0 tref=${TREF:-} twhere=${TWHERE:-}
  REPLY=
  [ "$STACK" = 1 ] || return 0
  deps_of "$1"
  for d in $DEPS; do
    int_status "$d"
    case $REPLY in "In Review"|Done) ;; *) n=$((n + 1)); cand=$d ;; esac
  done
  REPLY=
  [ "$n" = 1 ] || return 0
  task_ref "$cand"
  if [ "$TWHERE" = local ]; then
    field "$TREF" "$cand" Status
    case $REPLY in
      "In Review"|Done) deps_block "$cand"; if [ -z "$REPLY" ]; then REPLY=$cand; else REPLY=; fi ;;
      *) REPLY= ;;
    esac
  fi
  TREF=$tref; TWHERE=$twhere
}

count_int_status() { # count_int_status <status>: REPLY = tasks with that status on the integration branch
  local id n=0
  for id in $TASK_IDS; do int_status "$id"; [ "$REPLY" = "$1" ] && n=$((n + 1)); done
  REPLY=$n
}

pushed() { # pushed <branch>: REMOTE has exactly the local head of <branch>
  local l r
  l=$(sha_of "refs/heads/$1") || return 1
  r=$(sha_of "refs/remotes/$REMOTE/$1") || return 1
  [ "$l" = "$r" ]
}

dirty_in() { [ -d "$1" ] && [ -n "$(git -C "$1" status --porcelain 2>/dev/null)" ]; }

# ---------- worktrees and ports ----------

task_dir() { if [ "$WORKTREES" = 1 ]; then REPLY=$WT_ABS/$1; else REPLY=$ROOT; fi; } # REPLY

used_offsets() {
  local f
  for f in "$WT_ABS"/*/.harness/local; do
    [ -f "$f" ] && sed -n 's/^PORT_OFFSET=//p' "$f" | tr -d '\r'
  done
  if [ -d "$STEPS_DIR" ]; then cat "$STEPS_DIR"/*.env 2>/dev/null | sed -n 's/^OFFSET=//p'; fi
}

offset_for() { # existing offset of the worktree, else the lowest free slot (main worktree = 0)
  local f=$WT_ABS/$1/.harness/local k used
  if [ "$WORKTREES" != 1 ]; then echo 0; return; fi
  if [ -f "$f" ]; then sed -n 's/^PORT_OFFSET=//p' "$f" | tr -d '\r' | tail -n 1; return; fi
  used=$(used_offsets)
  k=1
  while printf '%s\n' "$used" | grep -qx "$((k * PORT_STEP))"; do k=$((k + 1)); done
  echo $((k * PORT_STEP))
}

# ---------- reviews ----------

# Review files are found with shell builtins only: every extra process (sed, sort, a pipeline)
# costs a noticeable fraction of a second on Windows. A sparse indexed array keyed by k lists
# its keys in ascending order, which sorts the files without `sort`.
list_reviews() { # artifacts/review/<prefix>-<k>.md, sorted by k, one per line
  local f k
  local byk=()
  for f in "$REVIEW_DIR/$1"-*.md; do
    [ -e "$f" ] || continue
    k=${f##*-}; k=${k%.md}
    is_num "$k" || continue
    byk[10#$k]=$f
  done
  for k in ${byk[@]+"${!byk[@]}"}; do printf '%s\n' "${byk[$k]}"; done
}

latest_review() { # latest_review <prefix>: REPLY = the review file with the highest k, or empty
  local f k best=-1
  REPLY=
  for f in "$REVIEW_DIR/$1"-*.md; do
    [ -e "$f" ] || continue
    k=${f##*-}; k=${k%.md}
    is_num "$k" || continue
    if [ $((10#$k)) -gt "$best" ]; then best=$((10#$k)); REPLY=$f; fi
  done
}

applied_on() { # applied_on <ref> <basename>
  case $RREFS in
    *" $1 "*) case $RDB in *$'\n'"$1|$2"$'\n'*) return 0 ;; esac; return 1 ;;
  esac
  git cat-file -e "$1:$APPLIED_DIR/$2" 2>/dev/null
}

applied_blocker() { # applied_blocker <ref> <basename>: the applied review has a Blocker row
  case $RREFS in
    *" $1 "*) case $RDB in *$'\n'"$1|$2|B"$'\n'*) return 0 ;; esac; return 1 ;;
  esac
  git show "$1:$APPLIED_DIR/$2" | has_blocker
}

latest_applied() { # latest_applied <ref> <prefix>: REPLY = basename of the newest applied review
  local f k best=-1 out line
  REPLY=
  case $RREFS in
    *" $1 "*)
      out=
      while IFS= read -r line; do
        case $line in "$1|"*) ;; *) continue ;; esac
        line=${line#"$1|"}
        case $line in *'|B') continue ;; esac
        out="$out$APPLIED_DIR/$line"$'\n'
      done <<EOF
$RDB
EOF
      ;;
    *) out=$(git ls-tree --name-only "$1" "$APPLIED_DIR/" 2>/dev/null) || return 0 ;;
  esac
  while IFS= read -r f; do
    f=${f%$'\r'}; f=${f#"$APPLIED_DIR"/}
    case $f in "$2"-*.md) ;; *) continue ;; esac
    k=${f##*-}; k=${k%.md}
    is_num "$k" || continue
    if [ $((10#$k)) -gt "$best" ]; then best=$((10#$k)); REPLY=$f; fi
  done <<EOF
$out
EOF
}

file_commit() { # file_commit <file>: REPLY = the sha on the first "Commit:" line that has one
  local line
  REPLY=
  while IFS= read -r line || [ -n "$line" ]; do
    line=${line%$'\r'}
    case $line in Commit:*) ;; *) continue ;; esac
    line=${line#Commit:}; line=${line#"${line%%[![:space:]]*}"}; line=${line%%[!0-9a-fA-F]*}
    if [ ${#line} -ge 7 ]; then REPLY=${line:0:40}; return 0; fi
  done < "$1"
}

has_blocker() { tr -d '\r' | grep -Eq '^\|[[:space:]]*RV-[0-9]+[[:space:]]*\|[[:space:]]*Blocker[[:space:]]*\|'; }

verdict_of() { tr -d '\r' | grep -Eo '^Verdict:[[:space:]]*(APPROVE|CHANGES REQUESTED)' | head -n 1 | sed 's/^Verdict:[[:space:]]*//'; }

commit_of() { tr -d '\r' | sed -n 's/^Commit:[[:space:]]*\([0-9a-fA-F]\{7,40\}\).*/\1/p' | head -n 1; }

# Per-task review decision for Review: each. Needs TREF. REPLY: apply <file> | rereview | review
task_review_next() {
  local id=$1 latest applied c
  latest_review "task-$id-review"; latest=$REPLY
  if [ -n "$latest" ] && ! applied_on "$TREF" "${latest##*/}" && ! applied_on "$INT_REF" "${latest##*/}"; then
    # An unapplied review only counts if it covers the branch head; otherwise it is stale.
    file_commit "$latest"; c=$REPLY
    if [ -n "$c" ]; then
      ref_sha "$TREF"
      case $c in
        *[A-F]*) [ "$(sha_of "$c")" = "$REPLY" ] && { REPLY="apply $latest"; return; } ;;
        *) case $REPLY in "$c"*) REPLY="apply $latest"; return ;; esac ;;
      esac
    fi
    REPLY=review; return
  fi
  latest_applied "$TREF" "task-$id-review"; applied=$REPLY
  if [ -n "$applied" ] && applied_blocker "$TREF" "$applied"; then REPLY=rereview; return; fi
  REPLY=review
}

# ---------- deciding actions ----------

# task_action <id>: sets A_ACTION, A_FILE, A_NOTE, and A_BASE (a start on an unmerged branch).
#   runnable: start continue review rereview apply merge
#   settled:  done (Done/Dropped on the integration branch), batch (merged, waits for review all)
#   waiting:  blocked (dependency not merged), wait-merge (MERGE=pr, a human merges),
#             other (branch only on REMOTE), error
task_action() {
  local id=$1 st d
  A_ACTION= A_FILE= A_NOTE= A_BASE=
  # The integration branch only gets In Review / Done through a merge, so trust it first
  # (this also covers squash merges, which leave the task branch unmerged in git's eyes).
  int_status "$id"
  case $REPLY in
    Done|Dropped) A_ACTION=done; return ;;
    "In Review") A_ACTION=batch; return ;;
  esac
  task_ref "$id"
  if [ "$TWHERE" = remote ]; then
    A_ACTION=other; A_NOTE="branch task/$id exists only on $REMOTE (someone else's work)"; return
  fi
  field "$TREF" "$id" Status; st=$REPLY
  case $st in
    Todo)
      deps_block "$id"; d=$REPLY
      if [ -n "$d" ]; then
        stack_on "$id"
        if [ -z "$REPLY" ]; then A_ACTION=blocked; A_NOTE="Task $id waits for Task $d to be merged into $INTEGRATION"; return; fi
        A_BASE=task/$REPLY
      fi
      A_ACTION=start ;;
    "In Progress")
      if [ "$TWHERE" = int ]; then A_ACTION=error; A_NOTE="Task $id is In Progress on $INTEGRATION but has no task/$id branch"; return; fi
      A_ACTION=continue ;;
    "In Review"|Done)
      # A task built on an unmerged dependency (STACK=1) is reviewed and merged only after that
      # dependency is merged, so its review diff holds only its own changes.
      deps_block "$id"; d=$REPLY
      if [ -n "$d" ]; then A_ACTION=blocked; A_NOTE="Task $id waits for Task $d to be merged into $INTEGRATION before its review and merge"; return; fi
      ;;
  esac
  case $st in
    Todo|"In Progress") ;;
    "In Review")
      review_policy "$id"
      if [ "$REPLY" = batch ]; then
        A_ACTION=merge
      else
        task_review_next "$id"; d=$REPLY
        case $d in apply\ *) A_ACTION=apply; A_FILE=${d#apply } ;; *) A_ACTION=$d ;; esac
        return
      fi ;;
    Done) A_ACTION=merge ;;
    Dropped) A_ACTION=done; return ;;
    *) A_ACTION=error; A_NOTE="Task $id has unknown status '$st'"; return ;;
  esac
  if [ "$A_ACTION" = merge ] && [ "$MERGE" = pr ] && pushed "task/$id"; then
    A_ACTION=wait-merge; A_NOTE="Task $id is pushed; waiting for task/$id to be merged into $INTEGRATION"
  fi
}

# review_all_action: sets A_ACTION (review-all rereview-all apply-all merge-all wait-merge done),
# A_FILE, and A_REF (the head the next review must cover).
#   Review-all fixes live on fix/review-all-<k> (from the review's Commit). Like a task branch,
#   it is re-reviewed while unmerged if the review had a Blocker, and merged once it is clean.
#   explicit=1 (target review-all): review whatever was merged since the last applied review all
review_all_action() {
  local explicit=$1 latest name fb applied last
  A_ACTION= A_FILE= A_NOTE= A_REF=$INT_REF
  latest_review review-all; latest=$REPLY
  if [ -n "$latest" ]; then
    name=${latest##*/}; fb=fix/${name%.md}
    if ! applied_on "$INT_REF" "$name"; then
      if ref_ok "refs/heads/$fb" && applied_on "refs/heads/$fb" "$name"; then
        if has_blocker < "$latest"; then
          A_ACTION=rereview-all; A_REF=refs/heads/$fb
        elif [ "$MERGE" = pr ] && pushed "$fb"; then
          A_ACTION=wait-merge; A_NOTE="$fb is pushed; waiting for it to be merged into $INTEGRATION"
        else
          A_ACTION=merge-all; A_FILE=$latest
        fi
        return
      fi
      A_ACTION=apply-all; A_FILE=$latest; return
    fi
  fi
  latest_applied "$INT_REF" review-all; applied=$REPLY
  count_int_status "In Review"
  if [ "$REPLY" -gt 0 ]; then A_ACTION=review-all; return; fi
  if [ "$explicit" = 1 ]; then
    last=
    [ -n "$applied" ] && last=$(git show "$INT_REF:$APPLIED_DIR/$applied" | commit_of)
    # Only docs changed since the last review all (e.g. its own review copy): nothing to review.
    if [ -z "$last" ] || ! git diff --quiet "$last" "$INT_REF" -- . ":(exclude)docs" 2>/dev/null; then
      A_ACTION=review-all; return
    fi
  fi
  A_ACTION=done
}

# review_backlog: REPLY = "" when nothing waits for a review all, else "N task(s) merged without
# review, M lines changed" (code only, since the last applied review all or harness-init), with
# " (suggest: Review all.)" when MODE=FULL and a threshold is reached. Costs one or two git calls,
# and only when the count is above zero.
review_backlog() {
  local n applied base lines=0
  REPLY=
  count_int_status "In Review"; n=$REPLY
  [ "$n" -gt 0 ] || return 0
  latest_applied "$INT_REF" review-all; applied=$REPLY
  base=
  [ -n "$applied" ] && base=$(git show "$INT_REF:$APPLIED_DIR/$applied" 2>/dev/null | commit_of)
  if [ -z "$base" ] && ref_ok harness-init; then base=harness-init; fi
  if [ -n "$base" ]; then
    lines=$(git diff --numstat "$base" "$INT_REF" -- . ':(exclude)docs' 2>/dev/null | awk '{ if ($1 != "-") a += $1 + $2 } END { print a + 0 }')
  fi
  REPLY="$n task(s) merged without review, $lines lines changed"
  if [ "$MODE" = FULL ] && { [ "$n" -ge "${REVIEW_ALL_TASKS:-3}" ] || [ "$lines" -ge "${REVIEW_ALL_LINES:-600}" ]; }; then
    REPLY="$REPLY (suggest: Review all.)"
  fi
}

skill_for() { # REPLY
  case $1 in
    start|continue) REPLY=hm-dev ;;
    review|rereview|review-all|rereview-all) REPLY=hm-review ;;
    apply|merge|apply-all|merge-all) REPLY=hm-dev ;;
  esac
}

trigger_for() { # trigger_for <action> <task> <abs file>: REPLY
  local b
  case $1 in
    start) REPLY="Start Task $2." ;;
    continue) REPLY="Continue Task $2." ;;
    review) REPLY="Review Task $2." ;;
    rereview) REPLY="Re-review Task $2." ;;
    review-all) REPLY="Review all." ;;
    rereview-all) REPLY="Re-review all." ;;
    apply|apply-all) REPLY="Apply these review comments: $3" ;;
    merge) REPLY="Merge Task $2." ;;
    merge-all) b=${3##*/}; REPLY="Merge branch fix/${b%.md}." ;;
  esac
}

is_merge_kind() { case $1 in apply|merge|apply-all|merge-all) return 0 ;; esac; return 1; }

# ---------- target ----------

parse_target() {
  local t=${1:-} from to id ids=
  case $t in
    all) T_KIND=all; ids=$TASK_IDS ;;
    review-all) T_KIND=review-all ;;
    *,*)
      T_KIND=list
      for id in ${t//,/ }; do has_task "$id" || fail "unknown task $id (no $TASK_DIR/$id.md on $INTEGRATION)"; ids="$ids $id"; done ;;
    '') fail "missing target (use <id>, <id>,<id>, N-M, all, review-all)" ;;
    *)
      from=${t%%-*}; to=${t#*-}
      if [ "$from" != "$t" ] && is_num "$from" && is_num "$to"; then
        [ "$from" -le "$to" ] || fail "bad range '$t'"
        T_KIND=range
        for id in $TASK_IDS; do is_num "$id" && [ "$id" -ge "$from" ] && [ "$id" -le "$to" ] && ids="$ids $id"; done
        [ -n "$ids" ] || fail "no task in range $t"
      else
        has_task "$t" || fail "unknown task $t (no $TASK_DIR/$t.md on $INTEGRATION)"
        T_KIND=one; ids=$t
      fi ;;
  esac
  TARGET_IDS=$ids
  TARGET=$t
}

wants_review_all() {
  [ "$T_KIND" = review-all ] && return 0
  [ "$T_KIND" = all ] || return 1
  count_int_status "In Review"
  [ "$REPLY" -gt 0 ]
}

# ---------- run bookkeeping ----------

kv_get() { # kv_get <file> <key> [default]: REPLY = the value of the last "<key>=" line
  local line
  REPLY=
  if [ -f "$1" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
      case $line in "$2="*) REPLY=${line#"$2="} ;; esac
    done < "$1"
  fi
  REPLY=${REPLY%$'\r'}
  REPLY=${REPLY:-${3:-}}
}

run_get() { kv_get "$RUN_ENV" "$1" "${2:-}"; } # REPLY
run_set() { printf '%s=%s\n' "$1" "$2" >> "$RUN_ENV"; }

load_run() {
  [ -d "$LOCK" ] && [ -f "$RUN_ENV" ] || fail "no active run: call run-begin <target> first"
  run_get TARGET; parse_target "$REPLY"
  run_get RUN_ID; RUN_ID=$REPLY
  run_get STEPS 0; STEPS=$REPLY
}

pending_get() { kv_get "$1" "$2"; } # pending_get <file> <key>: REPLY = the raw %q value

# PENDING = the step files of the running steps; HELD = " <id> <id>" of the held tasks.
pending_list() { local f; PENDING=; for f in "$STEPS_DIR"/*.env; do [ -f "$f" ] && PENDING="$PENDING $f"; done; }
held_list() { local f; HELD=; for f in "$HOLD_DIR"/*; do [ -f "$f" ] && HELD="$HELD ${f##*/}"; done; }

# notes_state: fresh (notes describe the integration head), stale, missing, or skip (a greenfield
# project with nothing but docs since harness-init: no code to map yet).
notes_state() {
  local c
  if [ -f "$NOTES" ]; then
    file_commit "$NOTES"; c=$REPLY
    if [ -n "$c" ] && [ "$(sha_of "$c")" = "$(sha_of "$INT_REF")" ]; then echo fresh; return; fi
    echo stale; return
  fi
  cfg GREENFIELD 1
  if [ "$REPLY" = 1 ] && ref_ok harness-init \
    && git diff --quiet harness-init "$INT_REF" -- . ':(exclude)docs' 2>/dev/null; then
    echo skip; return
  fi
  echo missing
}

# ---------- commands ----------

task_label() { # REPLY
  task_action "$1"
  case $A_ACTION in
    apply) REPLY="apply ${A_FILE##*/}" ;;
    blocked|wait-merge|other|error) REPLY="$A_ACTION: $A_NOTE" ;;
    batch) REPLY="merged, waits for review all" ;;
    *) REPLY=$A_ACTION ;;
  esac
}

cmd_status() {
  local id f s label running= st ty rv info reviews_all=no t a
  need_tasks
  pending_list
  for f in $PENDING; do
    s=${f##*/}; s=${s%.env}
    pending_get "$f" TASK; t=$REPLY
    pending_get "$f" ACTION; a=$REPLY
    running="$running $t=$a#$s"
  done
  printf '%-10s %-12s %-8s %-6s %-7s %s\n' Task Status Type Review Where "Next action"
  for id in $TASK_IDS; do
    task_ref "$id"
    case " $running " in
      *" $id="*) label=${running#*" $id="}; label=${label%% *}; label="running: ${label%#*} (step ${label#*#})" ;;
      *)
        if [ -f "$HOLD_DIR/$id" ]; then
          IFS= read -r info < "$HOLD_DIR/$id" || :
          label="held: ${info%$'\r'} (waits for the user)"
        else
          task_label "$id"; label=$REPLY
        fi ;;
    esac
    field "$TREF" "$id" Status; st=$REPLY
    task_type "$id"; ty=$REPLY
    review_policy "$id"; rv=$REPLY
    printf '%-10s %-12s %-8s %-6s %-7s %s\n' "$id" "$st" "$ty" "$rv" "$TWHERE" "$label"
  done
  for f in "$REVIEW_DIR"/review-all-*.md; do
    [ -e "$f" ] || continue
    s=${f##*-}; s=${s%.md}
    is_num "$s" && { reviews_all=yes; break; }
  done
  count_int_status "In Review"
  if [ "$REPLY" -gt 0 ] || [ "$reviews_all" = yes ]; then
    review_all_action 0
    printf '%-10s %-12s %-8s %-6s %-7s %s\n' all - - - - "$A_ACTION"
  fi
  review_backlog; [ -n "$REPLY" ] && echo "review backlog: $REPLY"
  echo "config: MODE=$MODE MERGE=$MERGE INTEGRATION=$INTEGRATION PARALLEL=$PARALLEL WORKTREES=$WORKTREES"
  if [ -d "$LOCK" ]; then info=; IFS= read -r info < "$LOCK/info" 2>/dev/null || :; echo "run: active ($info)"; fi
  for f in $PENDING; do
    s=${f##*/}
    pending_get "$f" ACTION; a=$REPLY
    pending_get "$f" TASK; t=$REPLY
    echo "pending step ${s%.env}: $a $t (not checked yet)"
  done
  dirty_in "$ROOT" && echo "main worktree: dirty"
  [ -n "$FETCH_WARN" ] && echo "warning: $FETCH_WARN"
  return 0
}

cmd_plan() {
  local id ty rv batch_left=
  need_tasks
  parse_target "${1:-}"
  echo "Next step per task (mode $MODE, PARALLEL=$PARALLEL, MERGE=$MERGE; from the current state):"
  for id in $TARGET_IDS; do
    task_action "$id"
    case $A_ACTION in
      start|continue)
        task_type "$id"; ty=$REPLY
        review_policy "$id"; rv=$REPLY
        if [ "$rv" = each ]; then
          echo "  Task $id ($ty): $A_ACTION (hm-dev), review, apply review, merge"
        else
          echo "  Task $id ($ty): $A_ACTION (hm-dev), merge without review (review all later)"
        fi ;;
      review|rereview) echo "  Task $id: $A_ACTION, apply review, merge" ;;
      apply) echo "  Task $id: apply ${A_FILE##*/}, merge" ;;
      merge) echo "  Task $id: merge" ;;
      done) echo "  Task $id: done, skip" ;;
      batch) echo "  Task $id: merged, waits for review all" ;;
      *) echo "  Task $id: $A_ACTION: $A_NOTE" ;;
    esac
  done
  if [ "$T_KIND" = all ]; then
    for id in $TARGET_IDS; do
      review_policy "$id"; [ "$REPLY" = batch ] || continue
      int_status "$id"; [ "$REPLY" != Done ] && { batch_left=y; break; }
    done
  fi
  if [ "$T_KIND" = review-all ]; then
    echo "  All: review all, apply, merge"
  elif [ -n "$batch_left" ]; then
    echo "  All: review all, apply, merge (for tasks merged without their own review)"
  fi
  echo "Tasks with no unmerged dependency run in parallel up to PARALLEL=$PARALLEL; merges run one at a time."
  [ "$STACK" = 1 ] && echo "STACK=1: a task whose one unmerged dependency has finished development starts on that branch while it is reviewed; its own review and merge wait for that merge."
  echo "A Blocker adds re-review + apply (up to MAX_REREVIEW=$MAX_REREVIEW per task). A wip commit adds a continue (up to MAX_CONTINUE=$MAX_CONTINUE)."
  [ -n "$FETCH_WARN" ] && echo "warning: $FETCH_WARN"
  return 0
}

cmd_worktree() {
  local name=${1:-} dir
  [ -n "$name" ] || fail "usage: worktree <task id or helper name>"
  case $name in *[!A-Za-z0-9._-]*) fail "bad name '$name'" ;; esac
  OUT_KEY=result
  task_dir "$name"; dir=$REPLY
  say result ok
  say dir "$dir"
  if [ -d "$dir" ]; then say exists yes; else say exists no; fi
  say offset "$(offset_for "$name")"
  dir=${INT_REF#refs/heads/}; dir=${dir#refs/remotes/}
  if has_task "$name"; then
    # A task built on an unmerged dependency (STACK=1) has that branch as its base until the
    # dependency is merged, so "git diff <base>...HEAD" shows only its own work.
    deps_block "$name"
    if [ -n "$REPLY" ]; then stack_on "$name"; [ -n "$REPLY" ] && dir=task/$REPLY; fi
    say base "$dir"
    task_ref "$name"
    say branch "task/$name"
    field "$TREF" "$name" Status; say status "$REPLY"
    say where "$TWHERE"
    deps_block "$name"; say blocked_by "$REPLY"
  else
    say base "$dir"
  fi
}

# start-check <id>: the "Start Task" preconditions that files and git can answer, in one call,
# so hm-dev reads one result instead of running them itself. What only the session knows
# (SESSION_PER_TASK) and `hm.sh check` stay with the skill.
cmd_start_check() {
  local id=${1:-} st d n t dir
  OUT_KEY=result
  [ -n "$id" ] || fail "usage: start-check <task id>"
  need_tasks
  has_task "$id" || needs_human stop "no docs/tasks/$id.md on $INTEGRATION (run hm-setup, or hm-change for a new task)"
  task_ref "$id"
  [ "$TWHERE" = remote ] && needs_human stop "branch task/$id exists only on $REMOTE: someone else owns this task"
  field "$TREF" "$id" Status; st=$REPLY
  case $st in
    Todo) ;;
    "In Progress") needs_human stop "Task $id is In Progress on task/$id: use \"Continue Task $id.\"" ;;
    *) needs_human stop "Task $id is $st, not Todo" ;;
  esac
  [ "$TWHERE" = local ] && needs_human stop "task/$id already has commits beyond $INTEGRATION while the task is Todo: an earlier session may own it; ask the user before reusing it"
  local base=${INT_REF#refs/heads/}; base=${base#refs/remotes/}
  deps_block "$id"; d=$REPLY
  if [ -n "$d" ]; then
    stack_on "$id"
    [ -n "$REPLY" ] || needs_human stop "Task $id waits for Task $d to be merged into $INTEGRATION"
    base=task/$REPLY
  fi
  n=0
  for t in $TASK_IDS; do
    task_ref "$t"; field "$TREF" "$t" Status
    [ "$REPLY" = "In Progress" ] && n=$((n + 1))
  done
  [ "$n" -ge "$PARALLEL" ] && needs_human stop "$n task(s) already In Progress (PARALLEL=$PARALLEL): finish or merge one first"
  task_dir "$id"; dir=$REPLY
  dirty_in "$dir" && needs_human stop "$dir has uncommitted changes: commit or discard them before starting Task $id"
  say result ok
  say dir "$dir"
  say offset "$(offset_for "$id")"
  say base "$base"
  if ref_ok "refs/heads/task/$id"; then say branch_exists yes; else say branch_exists no; fi
  [ -n "$FETCH_WARN" ] && say warning "$FETCH_WARN"
  return 0
}

cmd_run_begin() {
  OUT_KEY=result
  need_tasks
  parse_target "${1:-}"
  mkdir -p "$STATE_DIR"
  if ! mkdir "$LOCK" 2>/dev/null; then
    fail "lock held: another hm-auto run is active ($(cat "$LOCK/info" 2>/dev/null)). If no other session is running it, call run-end."
  fi
  # Two runs can start in the same second (fast machines, scripted runs): never share a folder,
  # or the second run overwrites the first one's step logs and mixes its summary.tsv rows.
  local base n=1
  base=$(date +%Y%m%d-%H%M%S); RUN_ID=$base
  while [ -e "artifacts/runs/$RUN_ID" ]; do n=$((n + 1)); printf -v RUN_ID '%s-%02d' "$base" "$n"; done
  echo "started $(date '+%Y-%m-%d %H:%M:%S'), target $TARGET, run $RUN_ID" > "$LOCK/info"
  rm -rf "$STEPS_DIR" "$HOLD_DIR"; mkdir -p "$STEPS_DIR"
  { echo "TARGET=$TARGET"; echo "RUN_ID=$RUN_ID"; echo "STEPS=0"; } > "$RUN_ENV"
  mkdir -p "artifacts/runs/$RUN_ID"
  say result ok
  say run "$RUN_ID"
  say target "$TARGET"
  say mode "$MODE"
  say parallel "$PARALLEL"
  say logs "artifacts/runs/$RUN_ID"
  [ -n "$FETCH_WARN" ] && say warning "$FETCH_WARN"
  return 0
}

# hand_out <action> <task> <file>: counters, dirty checks, step file, key=value output
hand_out() {
  local act=$1 task=$2 file=$3 dir offset key count log skill prompt where head0 absfile=
  if [ "$task" = all ]; then dir=$ROOT; offset=0; else task_dir "$task"; dir=$REPLY; offset=$(offset_for "$task"); fi
  case $act in
    start)
      dirty_in "$dir" && needs_human stop "$dir has uncommitted changes before starting Task $task" ;;
    continue) ;;
    *)
      dirty_in "$dir" && needs_human stop "uncommitted changes in $dir before '$act $task': the last session left work behind" ;;
  esac
  if is_merge_kind "$act" && [ "$MERGE" = local ] && [ "$dir" != "$ROOT" ] && dirty_in "$ROOT"; then
    needs_human stop "the main worktree has uncommitted changes; '$act $task' needs it clean to merge into $INTEGRATION"
  fi
  case $act in
    continue) key=cont_$task; run_get "$key" 0; count=$REPLY
      [ "$count" -ge "$MAX_CONTINUE" ] && needs_human stop "Task $task still unfinished after $count automatic continue(s) (MAX_CONTINUE=$MAX_CONTINUE); read its Notes for Next Session"
      run_set "$key" $((count + 1)) ;;
    rereview|rereview-all) key=rr_$task; run_get "$key" 0; count=$REPLY
      [ "$count" -ge "$MAX_REREVIEW" ] && needs_human stop "Blocker still found for $task after $count re-review(s) (MAX_REREVIEW=$MAX_REREVIEW); the next run resumes with a re-review"
      run_set "$key" $((count + 1)) ;;
  esac
  STEPS=$((STEPS + 1)); run_set STEPS "$STEPS"
  printf -v log 'artifacts/runs/%s/%02d-%s-%s.md' "$RUN_ID" "$STEPS" "$act" "$task"
  skill_for "$act"; skill=$REPLY
  [ -n "$file" ] && absfile=$ROOT/$file
  case $act in
    start|continue)
      if [ "$WORKTREES" = 1 ]; then where="Worktree: $dir (PORT_OFFSET=$offset)."; else where="Work in the main worktree: $ROOT."; fi
      if [ "$act" = start ] && [ -n "${A_BASE:-}" ]; then
        where="$where Base: $A_BASE (Task ${A_BASE#task/} is still in review and not merged; start-check gives the same base)."
      fi ;;
    review|rereview|apply|merge) where="Task worktree: $dir. Main worktree: $ROOT." ;;
    *) where="Work in the main worktree: $ROOT." ;;
  esac
  trigger_for "$act" "$task" "$absfile"
  prompt="Use the $skill skill. $REPLY $where"
  case $act in
    start|continue)
      [ -f "$NOTES" ] && prompt="$prompt Codebase notes: $ROOT/$NOTES (read them before exploring the code; they describe the commit on their Commit line, so check git log since then)." ;;
  esac
  prompt="$prompt $SUBAGENT_NOTE"
  head0=
  [ "$task" != all ] && head0=$(sha_of "refs/heads/task/$task")
  {
    printf 'ACTION=%q\n' "$act"
    printf 'TASK=%q\n' "$task"
    printf 'FILE=%q\n' "$file"
    printf 'DIR=%q\n' "$dir"
    printf 'OFFSET=%s\n' "$offset"
    printf 'STARTED=%s\n' "$(date +%s)"
    printf 'STARTED_AT=%s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
    printf 'HEAD0=%q\n' "$head0"
    if [ "$task" = all ]; then
      printf 'EXP_REF=%q\n' "${EXP_REF:-$INT_REF}"
      printf 'REVIEWS0=%q\n' "$(list_reviews review-all)"
    else
      printf 'REVIEWS0=%q\n' "$(list_reviews "task-$task-review")"
    fi
  } > "$STEPS_DIR/$STEPS.env"
  say action "$act"
  say step "$STEPS"
  say task "$task"
  [ -n "$file" ] && say file "$absfile"
  say dir "$dir"
  say skill "$skill"
  say prompt "$prompt"
  say log "$log"
}

# cmd_next [--all]: hand out one step, or with --all every step that can start now, each block
# followed by a "--" line, then a last block (action=wait, done, stop or error). The state is
# read once for the whole batch: the step files hand_out writes keep the later rounds right.
cmd_next() {
  OUT_KEY=action
  load_run
  while next_one; do
    [ "${1:-}" = --all ] || return 0
    echo "--"
  done
  return 0
}

# next_one: hand out one step (return 0), or print the last block (return 1).
next_one() {
  local f npend=0 busy= merge_busy=0 id waits= others= a held heldwait=
  held_list; held=$HELD
  pending_list
  for f in $PENDING; do
    npend=$((npend + 1))
    pending_get "$f" TASK; busy="$busy $REPLY"
    pending_get "$f" ACTION; is_merge_kind "$REPLY" && merge_busy=1
  done
  if [ "$npend" -ge "$PARALLEL" ]; then say action wait; say reason "all $PARALLEL slot(s) busy"; return 1; fi
  for id in $TARGET_IDS; do
    case " $busy " in *" $id "*) continue ;; esac
    case " $held " in *" $id "*) heldwait="$heldwait $id"; continue ;; esac
    task_action "$id"
    a=$A_ACTION
    case $a in
      done|batch) ;;
      start|continue|review|rereview) hand_out "$a" "$id" "$A_FILE"; return 0 ;;
      apply|merge)
        if [ "$merge_busy" = 1 ]; then continue; fi
        hand_out "$a" "$id" "$A_FILE"; return 0 ;;
      blocked|wait-merge) waits="$waits; $A_NOTE" ;;
      other) others="$others; $A_NOTE" ;;
      error) fail "$A_NOTE" ;;
    esac
  done
  if [ "$npend" -gt 0 ]; then say action wait; say reason "waiting for $npend running step(s)"; return 1; fi
  if [ -n "$heldwait" ]; then
    say action wait; say reason "nothing else can run; waiting for the user on held task(s):$heldwait"; say held "${heldwait# }"; return 1
  fi
  if [ -n "$waits" ]; then needs_human stop "nothing can run now${waits}"; fi
  if wants_review_all; then
    if [ "$T_KIND" = review-all ]; then review_all_action 1; else review_all_action 0; fi
    case $A_ACTION in
      review-all|rereview-all|apply-all|merge-all) EXP_REF=$A_REF; hand_out "$A_ACTION" all "$A_FILE"; return 0 ;;
      wait-merge) needs_human stop "$A_NOTE" ;;
    esac
  fi
  say action done
  [ -n "$others" ] && say note "skipped${others}"
  return 1
}

step_ok() { rm -f "$STEP_FILE"; log_step ok; say result ok; }

cmd_check() {
  local st subj new f v blocker exp got c name fb ist n
  OUT_KEY=result
  load_run
  STEP_FILE=$STEPS_DIR/${1:-none}.env
  [ -n "${1:-}" ] && [ -f "$STEP_FILE" ] || fail "no pending step '${1:-}' (call next first; see status)"
  STARTED= STARTED_AT=
  # shellcheck disable=SC1090
  . "$STEP_FILE"
  STEP_NO=$1 STEP_ACTION=$ACTION STEP_TASK=$TASK STEP_STARTED=$STARTED STEP_STARTED_AT=$STARTED_AT
  case $ACTION in
    start|continue)
      task_ref "$TASK"
      [ "$TWHERE" = local ] || needs_human needs_user "Task $TASK has no task/$TASK branch with commits: a start precondition failed or the agent asked a question before starting"
      field "$TREF" "$TASK" Status; st=$REPLY
      case $st in
        "In Review")
          dirty_in "$DIR" && needs_human needs_user "Task $TASK is In Review but $DIR has uncommitted changes"
          step_ok; say status "In Review"
          # demo=1: the task can be demoed when the user asks; it never holds the task.
          if has_demo "$TASK"; then say demo 1; else say demo 0; fi
          return 0 ;;
        Done) needs_human needs_user "the dev step set Task $TASK to Done; only the apply-review step may do that" ;;
        "In Progress")
          subj=$(git log -1 --format=%s "$TREF" | tr -d '\r')
          if [ "$(sha_of "$TREF")" != "$HEAD0" ] && [ "${subj#wip(task-$TASK)}" != "$subj" ]; then
            rm -f "$STEP_FILE"; log_step continue; say result continue; say reason "wip commit: context ran out, continue in a fresh sub-agent"; return 0
          fi
          needs_human needs_user "Task $TASK is In Progress without a new wip commit: the agent stopped to ask a question" ;;
        *) needs_human needs_user "Task $TASK has unexpected status '$st' after the dev step" ;;
      esac ;;
    review|rereview|review-all|rereview-all)
      dirty_in "$DIR" && needs_human needs_user "the review session changed files in $DIR (reviews are read-only)"
      if [ "$TASK" = all ]; then f=review-all; exp=$(sha_of "$EXP_REF"); else f=task-$TASK-review; exp=$(sha_of "refs/heads/task/$TASK"); fi
      new=
      while IFS= read -r v; do
        [ -n "$v" ] || continue
        printf '%s\n' "$REVIEWS0" | grep -qxF "$v" || new=$v
      done <<EOF
$(list_reviews "$f")
EOF
      [ -n "$new" ] || needs_human needs_user "no new review file was written ($REVIEW_DIR/$f-<k>.md)"
      v=$(verdict_of < "$new")
      [ -n "$v" ] || needs_human needs_user "cannot read the Verdict line in $new"
      file_commit "$new"; c=$REPLY
      [ -n "$c" ] || needs_human needs_user "no 'Commit: <sha>' line in $new"
      got=$(sha_of "$c")
      [ "$got" = "$exp" ] || needs_human needs_user "$new reviews commit $c, but the head to review is $exp"
      blocker=no; has_blocker < "$new" && blocker=yes
      step_ok; say file "$new"; say verdict "$v"; say blocker "$blocker"; return 0 ;;
    apply|merge)
      task_ref "$TASK"
      if [ "$ACTION" = apply ]; then
        name=${FILE##*/}
        applied_on "$TREF" "$name" || applied_on "$INT_REF" "$name" \
          || needs_human needs_user "review not applied yet ($APPLIED_DIR/$name is not committed): the agent probably asked a question"
      fi
      dirty_in "$DIR" && needs_human needs_user "uncommitted changes left in $DIR"
      [ "$MERGE" = local ] && dirty_in "$ROOT" && needs_human needs_user "uncommitted changes left in the main worktree"
      int_status "$TASK"; ist=$REPLY
      case $ist in
        Done) step_ok; say status "done, merged"; return 0 ;;
        "In Review") [ "$ACTION" = merge ] && { step_ok; say status "merged, waits for review all"; review_backlog; [ -n "$REPLY" ] && say backlog "$REPLY"; return 0; } ;;
      esac
      field "$TREF" "$TASK" Status; st=$REPLY
      if [ "$st" = Done ] || [ "$ACTION" = merge ]; then
        if [ "$MERGE" = pr ] && pushed "task/$TASK"; then step_ok; say status "pushed, waiting for merge into $INTEGRATION"; return 0; fi
        needs_human needs_user "Task $TASK is '$st' but task/$TASK is not merged into $INTEGRATION$( [ "$MERGE" = pr ] && echo ' or pushed'): a merge conflict or a question"
      fi
      has_blocker < "$FILE" || needs_human needs_user "no Blocker in $name, but Task $TASK is '$st' instead of Done"
      file_commit "$FILE"; c=$REPLY
      [ -n "$c" ] && git log --first-parent --no-merges --format=%s "$c..$TREF" 2>/dev/null | grep -q '^fix(' \
        || needs_human needs_user "Blocker in $name but no fix(...) commit after the reviewed commit"
      step_ok; say status "in review, re-review next"; return 0 ;;
    apply-all|merge-all)
      name=${FILE##*/}; fb=fix/${name%.md}
      dirty_in "$ROOT" && needs_human needs_user "uncommitted changes left in the main worktree"
      if applied_on "$INT_REF" "$name"; then step_ok; say status "done, merged"; return 0; fi
      if ref_ok "refs/heads/$fb" && applied_on "refs/heads/$fb" "$name"; then
        if has_blocker < "$FILE"; then
          file_commit "$FILE"; c=$REPLY
          [ -n "$c" ] && git log --first-parent --no-merges --format=%s "$c..refs/heads/$fb" 2>/dev/null | grep -q '^fix(' \
            || needs_human needs_user "Blocker in $name but no fix(...) commit on $fb"
          step_ok; say status "fixes on $fb, re-review all next"; return 0
        fi
        if [ "$MERGE" = pr ] && pushed "$fb"; then step_ok; say status "pushed $fb, waiting for merge"; return 0; fi
        needs_human needs_user "$name is applied on $fb but not merged into $INTEGRATION: a merge conflict or a question"
      fi
      needs_human needs_user "review not applied yet ($APPLIED_DIR/$name is on neither $INTEGRATION nor $fb)" ;;
    *) fail "unknown pending action '$ACTION'" ;;
  esac
}

cmd_notes() {
  OUT_KEY=result
  say result ok
  say notes "$(notes_state)"
  say file "$ROOT/$NOTES"
  say commit "$(sha_of "$INT_REF")"
}

cmd_hold() { # hold <id> [reason...]
  local id=${1:-}
  OUT_KEY=result
  load_run
  [ -n "$id" ] && has_task "$id" || fail "usage: hold <task id> [reason]"
  shift
  mkdir -p "$HOLD_DIR"
  echo "${*:-demo}" > "$HOLD_DIR/$id"
  say result ok
  say held "$id"
}

cmd_release() {
  local id=${1:-}
  OUT_KEY=result
  [ -n "$id" ] || fail "usage: release <task id>"
  rm -f "$HOLD_DIR/$id"
  say result ok
  say released "$id"
}

cmd_run_end() {
  rm -rf "$LOCK" "$RUN_ENV" "$STEPS_DIR" "$HOLD_DIR"
  say result ok
}

# report [run]: aggregate summary.tsv. A step checked twice (a question, then its follow-up)
# has two rows; the last one wins for its time and result, so a step counts as one sub-agent.
cmd_report() {
  local run=${1:-} d f
  if [ -z "$run" ] && [ -f "$RUN_ENV" ]; then run_get RUN_ID; run=$REPLY; fi
  if [ -z "$run" ]; then
    for d in artifacts/runs/*/; do
      if [ -f "${d}summary.tsv" ]; then run=${d%/}; run=${run##*/}; fi
    done
  fi
  f=artifacts/runs/$run/summary.tsv
  [ -n "$run" ] && [ -f "$f" ] || fail "no summary.tsv found under artifacts/runs/ (no automatic run has been checked yet)"
  echo "run: $run ($f)"
  awk -F'\t' '
    NR == 1 { next }
    {
      s = $1
      if (!(s in sact)) sorder[++ns] = s
      sact[s] = $2; stask[s] = $3; ssec[s] = $5 + 0; sres[s] = $6
      if ($6 == "needs_user") q[$3]++
    }
    END {
      for (i = 1; i <= ns; i++) {
        s = sorder[i]; act = sact[s]; task = stask[s]; sec = ssec[s]
        if (act == "start" || act == "continue") kind = "dev"
        else if (act ~ /review/) kind = "review"
        else if (act ~ /^apply/) kind = "apply"
        else if (act ~ /^merge/) kind = "merge"
        else kind = act
        ksec[kind] += sec; kn[kind]++
        tsec[task] += sec; tn[task]++
        if (!(task in seen)) { seen[task] = 1; torder[++nt] = task }
        if (act == "continue") cont[task]++
        if (act ~ /^rereview/) rr[task]++
        if (sec > maxs) { maxs = sec; maxl = "step " s " " act " " task }
        tot += sec; n++
      }
      printf "%-8s %5s %8s\n", "kind", "steps", "minutes"
      split("dev review apply merge", ks, " ")
      for (i = 1; i <= 4; i++) { k = ks[i]; if (k in kn) printf "%-8s %5d %8.1f\n", k, kn[k], ksec[k] / 60 }
      printf "%-8s %5d %8.1f\n", "total", n, tot / 60
      print ""
      printf "%-6s %5s %8s %9s %10s %9s\n", "task", "steps", "minutes", "continues", "re-reviews", "questions"
      for (i = 1; i <= nt; i++) {
        t = torder[i]
        printf "%-6s %5d %8.1f %9d %10d %9d\n", t, tn[t], tsec[t] / 60, cont[t] + 0, rr[t] + 0, q[t] + 0
      }
      print ""
      if (n) printf "slowest: %s, %.1f min\n", maxl, maxs / 60
      drv = ""
      for (i = 1; i <= nt; i++) {
        t = torder[i]
        if (cont[t] > 0) drv = drv sprintf("Task %s: %d continue(s), context ran out (split it with hm-change if it repeats); ", t, cont[t])
        if (rr[t] > 0) drv = drv sprintf("Task %s: %d re-review(s) after a Blocker; ", t, rr[t])
        if (q[t] > 0) drv = drv sprintf("Task %s: %d question(s), a decision REQUIRE or the task file did not settle; ", t, q[t])
      }
      sub(/; $/, "", drv)
      if (drv == "") print "cost drivers: none (every step ran once)"
      else print "cost drivers: " drv
    }' "$f"
}

case ${1:-} in
  status)    load_project; cmd_status ;;
  plan)      load_project; cmd_plan "${2:-}" ;;
  worktree)  load_project nofetch; cmd_worktree "${2:-}" ;;
  start-check) load_project; cmd_start_check "${2:-}" ;;
  run-begin) load_project; cmd_run_begin "${2:-}" "${3:-}" ;;
  next)      load_project; cmd_next "${2:-}" ;;
  check)     if [ "${3:-}" = --next ]; then CHECK_NEXT=1; load_project; else load_project nofetch; fi
             cmd_check "${2:-}"
             if [ "${3:-}" = --next ]; then echo "--"; cmd_next --all; fi ;;
  notes)     load_project nofetch; cmd_notes ;;
  hold)      load_project nofetch; shift; cmd_hold "$@" ;;
  release)   load_project nofetch; cmd_release "${2:-}" ;;
  run-end)   load_project nofetch; cmd_run_end ;;
  report)    load_project nofetch; cmd_report "${2:-}" ;;
  -h|--help|help) usage ;;
  *) usage; exit 1 ;;
esac
