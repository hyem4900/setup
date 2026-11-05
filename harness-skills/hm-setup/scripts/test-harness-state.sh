#!/usr/bin/env bash
# test-harness-state.sh - proves harness-state.sh on a throwaway git repository.
#
# Run it from anywhere: bash harness-skills/hm-setup/scripts/test-harness-state.sh
# It builds a temporary repository with task files, walks the harness flow by hand (task
# branches, status lines, review files, merges) and asserts what the script hands out and
# checks at each step. It is for this skill repository, not for projects: nothing copies it.
# Needs git and bash (3.2 or newer). ASCII only, as the scripts it tests.
set -u -o pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
SCRIPT=$HERE/harness-state.sh
PASS=0; FAIL=0
TMP=$(mktemp -d 2>/dev/null || mktemp -d -t hmtest)
trap 'cd /; rm -rf "$TMP"' EXIT

ok() { PASS=$((PASS + 1)); echo "ok   $1"; }
bad() { FAIL=$((FAIL + 1)); echo "FAIL $1"; echo "$2" | sed 's/^/     | /'; }

# run <args...>: OUT = stdout, RC = exit code, of the script in the current repo. It runs with
# the same bash as this test ($BASH), so a run under /bin/bash on macOS really tests bash 3.2.
run() { OUT=$("$BASH" "$SCRIPT" "$@" 2>&1); RC=$?; }

has() { # has <label> <needle> [needle...]: every needle appears in OUT
  local n
  for n in "${@:2}"; do
    case $OUT in *"$n"*) ;; *) bad "$1: missing '$n'" "$OUT"; return 1 ;; esac
  done
  ok "$1"
}
lacks() { case $OUT in *"$2"*) bad "$1: unexpected '$2'" "$OUT" ;; *) ok "$1" ;; esac; }
rc_is() { if [ "$RC" -eq "$2" ]; then ok "$1 (exit $2)"; else bad "$1: exit $RC, wanted $2" "$OUT"; fi; }

# ---------- fixture helpers ----------

task_file() { # task_file <id> <title> <review> <deps> [type]
  printf '%s\n' "# Task $1: $2" "- Status: Todo" "- Type: ${5:-feature}" "- Review: $3" \
    "- Core: no" "- Depends on: $4" "- Requirements: R-01" "- Source: test" "" "## Scope" "x" > "docs/tasks/$1.md"
}

set_status() { # set_status <id> <status>: in the current worktree
  local f=docs/tasks/$1.md tmp=$TMP/t.md
  sed "s/^- Status: .*/- Status: $2/" "$f" > "$tmp" && mv "$tmp" "$f"
}

commit() { git add -A >/dev/null && git commit -q -m "$1"; }

review_file() { # review_file <name> <sha> <verdict> [blocker]
  mkdir -p artifacts/review
  {
    echo "# Review"
    echo "Verdict: $3"
    echo "Commit: $2"
    echo ""
    echo "## Findings"
    echo "### Spec"
    echo "| ID | Severity | File:line | Problem | Suggested fix | Ref |"
    [ "${4:-}" = blocker ] && echo "| RV-1 | Blocker | a.py:1 | wrong | fix | R-01 |"
    echo "### Standards"
  } > "artifacts/review/$1.md"
}

apply_review() { # apply_review <name>: copy to docs/reviews on the current branch and commit
  mkdir -p docs/reviews && cp "artifacts/review/$1.md" docs/reviews/ && commit "docs: review applied"
}

new_repo() { # new_repo <config lines...>
  local d=$TMP/repo$RANDOM
  mkdir -p "$d" && cd "$d" || exit 1
  git init -q -b main . 2>/dev/null || { git init -q . && git checkout -q -b main; }
  git config user.name t; git config user.email t@t; git config core.autocrlf false
  mkdir -p .harness docs/tasks scripts
  printf '%s\n' "$@" > .harness/config
  cp "$SCRIPT" scripts/harness-state.sh
  printf 'artifacts/\n.run/\n' > .gitignore
}

# ====================================================================================
echo "== scenario A: solo, PARALLEL=1, WORKTREES=0, MERGE=local"
new_repo MODE=FULL INTEGRATION=main MERGE=local PARALLEL=1 WORKTREES=0
task_file 0 "Skeleton" each none chore
task_file 1 "Search" each 0
task_file 2 "Export" batch 1
task_file 9 "Old" each none; set_status 9 Dropped
commit "chore: harness"; git tag harness-init

run status; rc_is "status runs" 0
has "status lists tasks" "0          Todo" "1          Todo" "2          Todo" "9          Dropped"
has "status: 0 can start, 1 blocked, 9 done" "start" "waits for Task 0" "done"

run plan all; rc_is "plan all" 0
has "plan: chore has no demo, each -> review" "Task 0 (chore): start (hm-dev), review, apply review, merge"
has "plan: blocked tasks and the final review all" "Task 2: blocked: Task 2 waits for Task 1" "Task 9: done, skip" "All: review all, apply, merge"

run worktree 1; has "worktree 1: base and blocker" "base=main" "offset=0" "blocked_by=0" "status=Todo" "where=int"
run start-check 0; rc_is "start-check 0 passes" 0; has "start-check 0 output" "result=ok" "dir=" "offset=0" "base=main" "branch_exists=no"
run start-check 1; rc_is "start-check 1 blocked" 3; has "start-check blocked reason" "result=stop" "waits for Task 0"
run start-check 7; rc_is "start-check unknown task" 3; has "start-check unknown reason" "no docs/tasks/7.md"

run next; rc_is "next without run-begin fails" 1

run run-begin all; rc_is "run-begin" 0; has "run-begin output" "result=ok" "target=all"
run run-begin all; rc_is "second run-begin refused (lock)" 1; has "lock reason" "lock held"

run next --all; rc_is "next --all" 0
has "next hands out start 0 only" "action=start" "task=0" "skill=hm-dev" "prompt=Use the hm-dev skill. Start Task 0." "action=wait" "all 1 slot(s) busy"
lacks "next does not start blocked task 1" "task=1"

# dev session: branch, status In Review (chore: no demo)
git checkout -q -b task/0 main; echo a > a.py; set_status 0 "In Review"; commit "feat(task-0): work"
HEAD0=$(git rev-parse HEAD); git checkout -q main
run start-check 0; rc_is "start-check: task no longer Todo" 3; has "start-check In Review reason" "Task 0 is In Review, not Todo"
run check 1 --next; rc_is "check dev step (chore)" 0
has "chore: ok, no demo, next is review" "result=ok" "status=In Review" "demo=0" "action=review" "task=0" "step=2" "Review Task 0."
lacks "chore not held" "held="

# reviewer writes a review that covers the branch head
review_file task-0-review-1 "$HEAD0" APPROVE
run check 2 --next; has "review ok -> apply" "result=ok" "verdict=APPROVE" "blocker=no" "action=apply" "Apply these review comments:" "task-0-review-1.md"

# apply: copy review, Done, merge
git checkout -q task/0; set_status 0 Done; apply_review task-0-review-1; git checkout -q main
git merge -q --no-ff --no-edit task/0
run check 3 --next; has "apply ok -> merged, task 1 unblocked" "result=ok" "status=done, merged" "action=start" "task=1" "step=4"

# task 1: feature with demo, review finds a Blocker
git checkout -q -b task/1 main; echo b > b.py; set_status 1 "In Review"; commit "feat(task-1): work"
HEAD1=$(git rev-parse HEAD); git checkout -q main
run check 4 --next; has "feature: demo offered, never held" "result=ok" "demo=1" "action=review" "task=1" "step=5"
lacks "feature: no held=" "held="
# a demo the user asked for holds the task: the running review is checked, but nothing more
# is handed out for it until release
run hold 1 demo; has "hold" "held=1"
review_file task-1-review-1 "$HEAD1" "CHANGES REQUESTED" blocker
run check 5 --next; has "held: review checked, nothing handed out" "verdict=CHANGES REQUESTED" "blocker=yes" "action=wait" "held=1"
run status; has "status shows hold" "held: demo"
run release 1; has "release" "released=1"
run next; has "after release: blocker -> apply" "action=apply" "step=6"
# apply with a Blocker: fix commit, stays In Review
git checkout -q task/1; echo b2 > b.py; commit "fix(task-1): address review RV-1"; apply_review task-1-review-1; git checkout -q main
run check 6 --next; has "blocker fixed -> re-review" "status=in review, re-review next" "action=rereview" "Re-review Task 1." "step=7"
HEAD1=$(git rev-parse task/1)
review_file task-1-review-2 "$HEAD1" APPROVE
run check 7 --next; has "re-review approved -> apply" "verdict=APPROVE" "blocker=no" "action=apply" "task-1-review-2.md"
git checkout -q task/1; set_status 1 Done; apply_review task-1-review-2; git checkout -q main; git merge -q --no-ff --no-edit task/1
run check 8 --next; has "task 1 merged -> task 2 starts" "status=done, merged" "action=start" "task=2" "step=9"

# task 2: batch, merged without review, then review all. PARALLEL=1 and MERGE=local, so its dev
# step asks for the merge too; this dev session does not merge, so a plain merge step follows.
has "batch dev step also asks for the merge" "Start Task 2. Then merge it in this same session" "Merge Task 2."
git checkout -q -b task/2 main; echo c > c.py; set_status 2 "In Review"; commit "feat(task-2): work"; git checkout -q main
run check 9 --next; has "batch dev did not merge -> merge step, no demo hold" "demo=1" "action=merge" "Merge Task 2." "step=10"
lacks "batch: no held=" "held="
git merge -q --no-ff --no-edit task/2
run check 10 --next; has "batch merged -> review all" "status=merged, waits for review all" "backlog=1 task(s) merged without review" "action=review-all" "task=all" "Review all." "step=11"
lacks "backlog below threshold: no suggestion" "suggest: Review all."
run status; has "status shows the backlog" "review backlog: 1 task(s) merged without review"
OUT=$(REVIEW_ALL_TASKS=1 "$BASH" "$SCRIPT" status 2>&1); has "threshold reached -> suggestion" "(suggest: Review all.)"
MAIN=$(git rev-parse main)
review_file review-all-1 "$MAIN" APPROVE
run check 11 --next; has "review all ok -> apply all" "verdict=APPROVE" "action=apply-all" "review-all-1.md" "step=12"
set_status 2 Done; apply_review review-all-1
run check 12 --next; has "apply all done -> run complete" "status=done, merged" "action=done"
run run-end; has "run-end" "result=ok"
run status; has "final status" "0          Done" "1          Done" "2          Done"
OUT=$(cat artifacts/runs/*/summary.tsv 2>/dev/null)
has "summary.tsv records every checked step" "step	action	task	started	seconds	result" "1	start	0	" "6	apply	1	" "11	review-all	all	" "	ok"
n=$(printf '%s\n' "$OUT" | grep -c "	ok$"); if [ "$n" -eq 12 ]; then ok "summary.tsv: 12 ok rows"; else bad "summary.tsv: $n ok rows, wanted 12" "$OUT"; fi
run report; rc_is "report after run-end picks the latest run" 0
has "report: kind and task tables" "kind     steps  minutes" "dev " "review " "apply " "merge " "total " "task   steps  minutes continues re-reviews questions" "slowest: step " "cost drivers:"

# ====================================================================================
echo "== scenario B: wip continue, dirty tree, MAX_CONTINUE"
new_repo MODE=HACKATHON INTEGRATION=main MERGE=local PARALLEL=1 WORKTREES=0
task_file 0 "A" batch none
task_file 1 "B" batch none
commit "chore: harness"; git tag harness-init
run run-begin 0 --no-demo; has "run-begin --no-demo" "result=ok"
run next; has "start 0" "action=start"
git checkout -q -b task/0 main; set_status 0 "In Progress"; commit "chore(task-0): start"
echo x > x.py; commit "wip(task-0): half done"; git checkout -q main
run start-check 0; rc_is "start-check: In Progress" 3; has "start-check says continue" "Continue Task 0."
run start-check 1; rc_is "start-check: PARALLEL full" 3; has "start-check PARALLEL reason" "1 task(s) already In Progress (PARALLEL=1)"
run check 1 --next; has "wip -> continue" "result=continue" "action=continue" "Continue Task 0."
git checkout -q task/0; echo y > y.py; commit "wip(task-0): more"; git checkout -q main
run check 2 --next; has "second wip -> continue" "result=continue" "action=continue"
git checkout -q task/0; echo z > z.py; commit "wip(task-0): again"; git checkout -q main
run check 3 --next; rc_is "third wip hits MAX_CONTINUE=2" 3; has "MAX_CONTINUE reason" "MAX_CONTINUE" "action=stop"
run run-end
# question: In Progress with no new commit
run run-begin 0 --no-demo; run next; has "continue handed out" "action=continue"
run check 1; rc_is "no commit after continue = question" 3; has "question reason" "result=needs_user" "stopped to ask a question"
OUT=$(cat artifacts/runs/*/summary.tsv 2>/dev/null); has "summary.tsv also records continue and needs_user" "	continue" "	needs_user"
run report; has "report during a run: the active run, with its cost drivers" "Task 0: 1 continue(s)" "Task 0: 1 question(s)"
run report no-such-run; rc_is "report on an unknown run fails" 1
run run-end
# a run that starts in a second whose folder already exists gets its own folder
taken=$(date +%Y%m%d-%H%M%S); mkdir -p "artifacts/runs/$taken"
run run-begin 0 --no-demo; got=$(printf '%s
' "$OUT" | sed -n 's/^run=//p')
if [ -n "$got" ] && [ "$got" != "$taken" ] && [ -d "artifacts/runs/$got" ]; then ok "run-begin never reuses a run folder ($got)"; else bad "run-begin reused or lost the run folder (taken=$taken got=$got)" "$OUT"; fi
run run-end
# a continue is handed out even with a dirty tree (a question leaves work uncommitted)
git checkout -q main; echo dirty > dirty.txt
run run-begin 0 --no-demo; run next; rc_is "dirty tree still allows continue" 0; has "continue despite dirty" "action=continue"
rm dirty.txt; run run-end
# an old --no-demo flag is accepted and changes nothing
run run-begin 0 --no-demo; run next; has "continue (In Progress on branch)" "action=continue"
git checkout -q task/0; set_status 0 "In Review"; commit "feat(task-0): done"; git checkout -q main
run check 1 --next; has "old flag: not held, merge next" "demo=1" "action=merge"
lacks "old flag: no held=" "held="
run run-end
# a batch task whose dev session merged it too: one step, then the next task
git merge -q --no-ff --no-edit task/0
run run-begin 1; run next; has "dev step asks for the merge" "action=start" "task=1" "Then merge it in this same session"
run plan 1; has "plan: start and merge in one session" "Task 1 (feature): start and merge in one session (hm-dev)"
git checkout -q -b task/1 main; echo w > w.py; set_status 1 "In Review"; commit "feat(task-1): done"; git checkout -q main
git merge -q --no-ff --no-edit task/1
run check 1 --next; has "dev step that merged: no merge step" "result=ok" "status=merged, waits for review all" "demo=1" "backlog=2 task(s) merged without review"
lacks "no separate merge step" "action=merge"
run run-end

# ====================================================================================
echo "== scenario C: PARALLEL=2, WORKTREES=1 slot and port allocation"
new_repo MODE=FULL INTEGRATION=main MERGE=local PARALLEL=2 WORKTREES=1 WORKTREE_DIR=../wt PORT_STEP=10
task_file 0 "A" batch none
task_file 1 "B" batch none
task_file 2 "C" batch "0, 1"
commit "chore: harness"; git tag harness-init
run worktree 0; has "worktree dir outside repo" "dir=" "/wt/0" "offset=10" "exists=no"
run start-check 0; has "start-check with worktrees" "result=ok" "/wt/0" "offset=10" "branch_exists=no"
run run-begin all; run next --all
has "two starts with different offsets" "task=0" "PORT_OFFSET=10" "task=1" "PORT_OFFSET=20" "action=wait" "all 2 slot(s) busy"
lacks "PARALLEL=2: the dev step does not merge" "Then merge it"
lacks "task 2 waits for its dependencies" "task=2"
run run-end
run status; has "status after run-end: blocked note" "waits for Task 0"

# PARALLEL>1 without worktrees is refused
new_repo MODE=FULL INTEGRATION=main MERGE=local PARALLEL=2 WORKTREES=0
task_file 0 "A" each none; commit "c"
run status; rc_is "PARALLEL=2 needs WORKTREES=1" 1; has "config error" "needs WORKTREES=1"

# ====================================================================================
echo "== scenario D: review file mismatches"
new_repo MODE=FULL INTEGRATION=main MERGE=local PARALLEL=1 WORKTREES=0
task_file 0 "A" each none; commit "chore: harness"; git tag harness-init
# a dirty main worktree refuses a start (the task is still Todo here)
echo dirty > dirty.txt
run start-check 0; rc_is "start-check: dirty tree" 3; has "start-check dirty reason" "uncommitted changes"
run run-begin 0 --no-demo; run next; rc_is "dirty tree refuses start" 3; has "dirty reason" "uncommitted changes"
rm dirty.txt; run run-end
run run-begin 0 --no-demo; run next
git checkout -q -b task/0 main; echo a > a.py; set_status 0 "In Review"; commit "feat(task-0): work"; git checkout -q main
run check 1 --next; has "review step handed out" "action=review"
run check 2; rc_is "no review file written" 3; has "missing review reason" "no new review file"
review_file task-0-review-1 "$(git rev-parse harness-init)" APPROVE
run check 2; rc_is "review of the wrong commit" 3; has "wrong commit reason" "but the head to review is"
review_file task-0-review-2 "$(git rev-parse task/0)" APPROVE
run check 2; rc_is "right commit passes" 0; has "picks the newest file" "task-0-review-2.md"
run run-end

# ====================================================================================
echo "== scenario E: STACK=1, the next task starts on its dependency's unmerged branch"
new_repo MODE=HACKATHON INTEGRATION=main MERGE=local PARALLEL=2 WORKTREES=1 WORKTREE_DIR=../wt PORT_STEP=10 STACK=1
task_file 0 "A" each none
task_file 1 "B" each 0
task_file 2 "C" each 1
commit "chore: harness"; git tag harness-init
run start-check 1; rc_is "start-check 1: dependency not developed yet" 3; has "not stacked on a Todo task" "waits for Task 0"
git checkout -q -b task/0 main; echo a > a.py; set_status 0 "In Review"; commit "feat(task-0): work"
HEAD0=$(git rev-parse HEAD); git checkout -q main
run start-check 1; rc_is "start-check 1 stacked" 0; has "start-check base is the dependency's branch" "result=ok" "base=task/0"
run plan all; has "plan explains stacking" "STACK=1"
run run-begin all; run next --all
has "review 0 and stacked start 1 together" "action=review" "task=0" "action=start" "task=1" "Base: task/0" "all 2 slot(s) busy"
lacks "no stack on a stack: 2 waits" "task=2"
# Task 1 developed on top of task/0
git checkout -q -b task/1 task/0; echo b > b.py; set_status 1 "In Review"; commit "feat(task-1): work"; git checkout -q main
run worktree 1; has "worktree base of a stacked task" "base=task/0" "blocked_by=0"
run check 2 --next; has "stacked dev ok; its review waits for 0's merge" "result=ok" "status=In Review" "action=wait"
run status; has "status: 1 waits for 0 before its review" "Task 1 waits for Task 0 to be merged into main before its review and merge" "waits for Task 1"
review_file task-0-review-1 "$HEAD0" APPROVE
run check 1 --next; has "review 0 ok -> apply 0" "verdict=APPROVE" "action=apply" "task=0"
git checkout -q task/0; set_status 0 Done; apply_review task-0-review-1; git checkout -q main
git merge -q --no-ff --no-edit task/0
run check 3 --next; has "0 merged -> review 1 and stacked start 2" "status=done, merged" "action=review" "task=1" "action=start" "task=2" "Base: task/1"
run worktree 1; has "after the merge the base is main again" "base=main"
run run-end

# STACK=1 without worktrees is refused
new_repo MODE=HACKATHON INTEGRATION=main MERGE=local PARALLEL=1 WORKTREES=0 STACK=1
task_file 0 "A" each none; commit "c"
run status; rc_is "STACK=1 needs WORKTREES=1" 1; has "stack config error" "STACK=1 needs WORKTREES=1"

# ====================================================================================
echo
echo "passed $PASS, failed $FAIL"
[ "$FAIL" -eq 0 ]
