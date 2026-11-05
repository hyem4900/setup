#!/usr/bin/env bash
# test-hm.sh - proves hm.sh and install.sh on throwaway git repositories.
#
# Run it from anywhere: bash harness-skills/hm-setup/scripts/test-hm.sh
# Each scenario builds a temporary repository with a .harness/config, runs hm.sh commands in it
# (config parsing, skips, the pre-commit hook's format / lint / type check split, every guardrail,
# selftest, starting and stopping components, load ports, doctor) and asserts the output and the
# exit codes. The last scenario runs install.sh twice. For this skill repository only: nothing
# copies it into projects. Needs git and bash (3.2 or newer). ASCII only, as the scripts it tests.
set -u -o pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
HM=$HERE/hm.sh
INSTALL=$HERE/install.sh
PASS=0; FAIL=0
TMP=$(mktemp -d 2>/dev/null || mktemp -d -t hmtest)
cleanup() {
  local d
  cd / || return
  for d in "$TMP"/repo*; do
    [ -f "$d/scripts/hm.sh" ] && (cd "$d" && "$BASH" scripts/hm.sh stop >/dev/null 2>&1)
  done
  rm -rf "$TMP"
}
trap cleanup EXIT

ok() { PASS=$((PASS + 1)); echo "ok   $1"; }
bad() { FAIL=$((FAIL + 1)); echo "FAIL $1"; echo "$2" | sed 's/^/     | /'; }

# run <args...>: OUT = output, RC = exit code of hm.sh in the current repo (same bash as this test)
run() { OUT=$(HEALTH_TIMEOUT=15 "$BASH" scripts/hm.sh "$@" 2>&1); RC=$?; }

has() {
  local n
  for n in "${@:2}"; do
    case $OUT in *"$n"*) ;; *) bad "$1: missing '$n'" "$OUT"; return 1 ;; esac
  done
  ok "$1"
}
lacks() { case $OUT in *"$2"*) bad "$1: unexpected '$2'" "$OUT" ;; *) ok "$1" ;; esac; }
rc_is() { if [ "$RC" -eq "$2" ]; then ok "$1 (exit $2)"; else bad "$1: exit $RC, wanted $2" "$OUT"; fi; }
same() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1: got '$2', wanted '$3'" ""; fi; }

new_repo() { # new_repo <config lines...>
  local d=$TMP/repo$RANDOM$RANDOM
  mkdir -p "$d" && cd "$d" || exit 1
  git init -q . && git checkout -q -b main 2>/dev/null
  git config user.name t; git config user.email t@t; git config core.autocrlf false
  mkdir -p .harness scripts docs/tasks
  printf '%s\n' "$@" > .harness/config
  cp "$HM" scripts/hm.sh
  printf '%s\n' artifacts/ .run/ .harness/local > .gitignore
  git add -A && git commit -q -m "chore: init"
}

task_ok() { printf '%s\n' "# Task $1: x" "- Status: Todo" "- Type: feature" "- Review: each" "- Depends on: none" > "docs/tasks/$1.md"; }

# The shipped default secret pattern, so the test proves what projects get.
SECRET=$(sed -n 's/^SECRET_PATTERN=//p' "$HERE/../templates/config-commands.template")
# Fake secrets, assembled at run time so this file never holds one literally.
FAKE_PW="pass""word = \"Wq7vT9kLm2xQ\""
FAKE_KEY="AKI""AABCDEFGHIJKLMNOP"
DEBUG_TAG="HM-DEBU""G"

# ====================================================================================
echo "== scenario 1: config, arguments, skips, help"
new_repo MODE=FULL HAS_SERVER=0 'TEST_CMD=echo TEST "$@"' '# a comment line' PORT_STEP=10
run test a.py -k b; rc_is "test runs" 0; has "test passes its arguments to \"\$@\"" "TEST a.py -k b"
for c in dev-bg stop health; do run "$c"; has "$c skips without a server" "skip: HAS_SERVER=0"; done
run load; has "load skips without a load target" "skip: HAS_LOAD=0"
run bench; has "bench skips" "skip: BENCH_CMD empty"
run security; has "security skips" "skip: SECURITY_CMD empty"
run migrate; has "migrate skips" "skip: MIGRATE_CMD empty"
run fmt; has "fmt skips" "skip: FORMAT_CMD empty"
run help; has "help: slot and warnings" "PORT_OFFSET=0, HM_SLOT=0" "E2E_CMD has no" "no LINT_CMD"
printf 'PORT_OFFSET=20\n' > .harness/local
run help; has "help: HM_SLOT from .harness/local" "PORT_OFFSET=20, HM_SLOT=2"
rm .harness/local
cp .harness/config "$TMP/cfg"
echo 'BROKEN LINE' >> .harness/config; n=$(wc -l < .harness/config | tr -d ' ')
run help; rc_is "a line without = fails" 1; has "error names the line" "line $n: expected KEY=value"
cp "$TMP/cfg" .harness/config; echo 'A B=1' >> .harness/config
run help; rc_is "a key with a space fails" 1; has "bad key reported" "bad key 'A B'"
cp "$TMP/cfg" .harness/config
run nosuch; rc_is "unknown command" 1; has "unknown command message" "unknown command 'nosuch'"

echo "-- doctor"
run doctor; rc_is "doctor: hooks not set up yet" 1
has "doctor reports tools and the missing hooks" "ok    git" "ok    bash" "FAIL  git hooks are not active" "warn  TYPECHECK_CMD missing" "warn  LINT_CMD is empty" "doctor: 1 problem(s)"
mkdir -p .githooks; printf '#!/bin/sh\nexec bash scripts/hm.sh check --hook\n' > .githooks/pre-commit
git config core.hooksPath .githooks
printf '%s\n' 'TYPECHECK_CMD=' 'FORMAT_CMD=' 'SECRET_PATTERN=' 'INSTALL_CMD=...' >> .harness/config
run doctor; rc_is "doctor: ok once hooks are active" 0; has "doctor ok, placeholder warned" "ok    git hooks" "warn  INSTALL_CMD looks like a placeholder" "doctor: ok"
printf '#!/bin/sh\r\nexit 0\r\n' > .githooks/pre-commit
run doctor; rc_is "doctor: CRLF hook" 1; has "CRLF reported" "FAIL  .githooks/pre-commit has CRLF"
printf '#!/bin/sh\nexit 0\n' > .githooks/pre-commit
printf '%s\n' PARALLEL=2 WORKTREES=0 >> .harness/config
run doctor; rc_is "doctor: PARALLEL without worktrees" 1; has "parallel reported" "FAIL  PARALLEL=2 needs WORKTREES=1"
printf '%s\n' PARALLEL=1 WORKTREES=1 WORKTREE_DIR=wt >> .harness/config
run doctor; rc_is "doctor: worktree folder inside the repo" 1; has "inside reported" "FAIL  WORKTREE_DIR 'wt' is inside the repository"
echo 'WORKTREE_DIR=../outside-wt' >> .harness/config
run doctor; rc_is "doctor: worktree folder outside" 0; has "outside ok" "ok    WORKTREE_DIR=../outside-wt"

# ====================================================================================
echo "== scenario 1b: pass records and --reuse"
new_repo MODE=FULL HAS_SERVER=0 'TEST_CMD=echo x >> .run/count; echo "3 passed"; exit $(cat .run/rc 2>/dev/null || echo 0)'
count() { wc -l < .run/count 2>/dev/null | tr -d ' '; }
run test; rc_is "full test on a clean tree" 0; same "it ran" "$(count)" 1
run test --reuse; rc_is "test --reuse" 0; has "reuse prints the record" "test: ok (reused" "3 passed"; same "reuse ran nothing" "$(count)" 1
run test; same "without --reuse it always runs" "$(count)" 2
run test a.py; same "a partial run runs" "$(count)" 3
echo b > b.txt; run test --reuse; has "untracked file: nothing reused" "nothing reused (uncommitted changes)"; same "it ran" "$(count)" 4
git add b.txt && git commit -q -m "feat: b"
run test --reuse; has "new tree: no record" "no recorded pass for this tree"; same "it ran" "$(count)" 5
run test --reuse; has "the run above recorded the new tree" "test: ok (reused"
echo c > c.txt && git add c.txt && git commit -q -m "feat: c"
echo 1 > .run/rc; run test; rc_is "failing run" 1
rm .run/rc; run test --reuse; has "a failure is not recorded" "no recorded pass for this tree"
git checkout -q -b task/9 && echo d > d.txt && git add d.txt && git commit -q -m "feat: d"
run test; rc_is "task branch passes" 0
git checkout -q main && git merge -q --no-ff -m "merge task/9" task/9
run test --reuse; has "a merge commit with the branch's tree reuses its pass" "test: ok (reused"

# ====================================================================================
echo "== scenario 2: pre-commit hook: format, lint only staged files, type check only at gates"
new_repo MODE=FULL HAS_SERVER=0 'TEST_CMD=true "$@"' 'LINT_CMD=echo LINT "$@"' 'TYPECHECK_CMD=echo TYPECHECK' \
  'FORMAT_CMD=for f in "$@"; do tr -s " " < "$f" > "$f.tmp" && mv "$f.tmp" "$f"; done'
echo 'y = 2' > b.py; git add b.py; git commit -q -m "feat: b"
echo 'x  =    1' > a.py; echo '# doc' > r.md; git add a.py r.md
run check --hook; rc_is "hook passes" 0
has "hook formats and lints only staged code" "fmt: formatted and re-staged 1 file(s)" "LINT a.py" "check: ok"
lacks "hook never runs the type check" "TYPECHECK"
lacks "hook does not lint the unstaged file" "b.py"
lacks "hook does not lint Markdown" "r.md"
same "staged content is formatted" "$(git show :a.py)" "x = 1"
git commit -q -m "feat: a"
echo 'more' >> r.md; git add r.md
run check --hook; has "Markdown-only commit skips lint" "lint: skipped (no code files staged)"
git commit -q -m "docs: r"
echo 'p  =  1' > a.py; git add a.py; echo 'q = 2' >> a.py
run check --hook; has "partly staged file is not reformatted" "fmt: skipped, also has unstaged changes: a.py" "LINT a.py"
same "partly staged content left alone" "$(git show :a.py)" "p  =  1"
git reset -q; git checkout -q -- a.py
run check; rc_is "direct check" 0; has "direct check lints all and type checks" "LINT" "TYPECHECK" "check: ok"
run fmt a.py; rc_is "fmt <file>" 0
echo 'TYPECHECK_CMD=false' >> .harness/config
run check; rc_is "a failing type check fails a direct check" 1; has "type check failure named" "FAIL: TYPECHECK_CMD"
echo 'x = 9' > c.py; git add c.py
run check --hook; rc_is "the hook ignores a failing type check" 0
git reset -q; rm -f c.py
echo 'LINT_CMD=false "$@"' >> .harness/config
echo 'x = 9' > c.py; git add c.py
run check --hook; rc_is "a failing lint blocks the commit" 1; has "lint failure named" "FAIL: LINT_CMD"
git reset -q; rm -f c.py

# ====================================================================================
echo "== scenario 3: guardrails"
new_repo MODE=FULL HAS_SERVER=0 HAS_UI=1 'TEST_CMD=true' "SECRET_PATTERN=$SECRET" 'SKIP_PATTERN=@skip|\.skip\(' \
  'TEST_DIRS=tests missing_dir' 'SELECTOR_PATTERN=getByText' 'E2E_DIRS=e2e' 'PROTECTED=data/'
mkdir -p tests e2e data
echo 'def test_a(): pass' > tests/t.py
echo 'page.getByTestId("save")' > e2e/e.js
echo 'a,b' > data/d.csv
task_ok 1; printf '%s\n' '# Task <id>' '- Status: <one of>' > docs/tasks/_template.md
git add -A && git commit -q -m "chore: harness"; git tag harness-init
run check; rc_is "clean tree passes" 0; has "missing test dir warned, template ignored" "warn: missing_dir not found" "check: ok"

printf '%s\n' "$FAKE_PW" > s.py; git add s.py
run check --hook; rc_is "quoted password blocked" 1; has "secret reported by file:line" "s.py:1" "possible secret"
lacks "the secret value is never printed" "Wq7vT9kLm2xQ"
printf '%s  # harness:allow-secret\n' "$FAKE_PW" > s.py; git add s.py
run check --hook; rc_is "harness:allow-secret passes" 0
printf 'key = %s\n' "$FAKE_KEY" > s.py; git add s.py
run check --hook; rc_is "cloud key format blocked" 1
git reset -q; rm -f s.py

printf 'print(1)  # %s\n' "$DEBUG_TAG" > dbg.py; git add dbg.py
run check --hook; rc_is "debug probe blocked" 1; has "debug probe named" "dbg.py:1" "temporary debug probes"
git reset -q; rm -f dbg.py
printf 'Remove %s probes before committing.\n' "$DEBUG_TAG" > notes.md; git add notes.md
run check --hook; rc_is "debug tag in Markdown is fine" 0
git reset -q; rm -f notes.md

echo '@skip' >> tests/t.py
run check; rc_is "skipped test blocked (whole tree)" 1; has "skip reported" "skipped tests are not allowed"
git add tests/t.py; run check --hook; rc_is "skipped test blocked (hook)" 1
git reset -q; git checkout -q -- tests/t.py

echo 'page.getByText("Save")' >> e2e/e.js
run check; rc_is "denied selector blocked" 1; has "selector reported" "E2E must select by the test-id attribute"
git checkout -q -- e2e/e.js

sed 's/^- Status: .*/- Status: Doing/' docs/tasks/1.md > "$TMP/t" && mv "$TMP/t" docs/tasks/1.md
run check; rc_is "bad task Status blocked" 1; has "bad Status named" "bad Status in docs/tasks/1.md: 'Doing'"
git add docs/tasks/1.md; run check --hook; rc_is "bad task Status blocked (hook)" 1
git reset -q; git checkout -q -- docs/tasks/1.md
sed 's/^- Type: .*/- Type: feature-ish/' docs/tasks/1.md > "$TMP/t" && mv "$TMP/t" docs/tasks/1.md
run check; rc_is "bad task Type blocked" 1; has "bad Type named" "bad Type in docs/tasks/1.md"
git checkout -q -- docs/tasks/1.md

echo 'c,d' >> data/d.csv
run check; rc_is "changed PROTECTED path blocked" 1; has "protected reported" "protected path changed"
git add data/d.csv; run check --hook; rc_is "staged PROTECTED path blocked" 1; has "protected staged named" "protected path changed (staged): data/d.csv"
git reset -q; git checkout -q -- data/d.csv

cp .harness/config "$TMP/cfg"; echo 'SKIP_PATTERN=(' >> .harness/config
run check; rc_is "broken regex fails loudly" 1; has "pattern error reported" "pattern error"
cp "$TMP/cfg" .harness/config

# ====================================================================================
echo "== scenario 4: selftest"
new_repo MODE=FULL HAS_SERVER=0 'TEST_CMD=true' "SECRET_PATTERN=$SECRET" 'SKIP_PATTERN=@skip' 'PROTECTED=README.md'
echo hi > README.md
printf '%s\n' 'skip: @skip' 'secret-allow: token = os.environ["APP_TOKEN"]' > .harness/guardrail-samples
git add -A && git commit -q -m "chore: harness"
run selftest; rc_is "selftest passes" 0
has "selftest covers the built-in samples" "ok   secret:" "ok   debug:" "ok   skip: @skip" "ok   task fields: a bad Status fails" "ok   protected: README.md exists" "selftest: ok"
echo 'skip: pytest.mark.xfail' >> .harness/guardrail-samples
echo 'PROTECTED=README.md nope.md' >> .harness/config
run selftest; rc_is "selftest catches a pattern gap and a missing path" 1
has "selftest failures named" "FAIL skip: not caught: pytest.mark.xfail" "FAIL protected: nope.md not found" "selftest: FAIL"

# ====================================================================================
echo "== scenario 5: components: start, reuse, stop, failure cleanup, load ports"
new_repo MODE=FULL HAS_SERVER=1 SERVICE=t COMPONENTS=a a_PORT=47110 \
  'a_DEV=while :; do sleep 1; done' 'a_PROD=while :; do sleep 1; done' \
  'a_HEALTH=for f in .run/dev-a.pid .run/prod-a.pid; do [ -f "$f" ] && kill -0 "$(cat "$f")" 2>/dev/null && exit 0; done; exit 1' \
  'TEST_CMD=true' 'E2E_CMD=echo E2E port=$a_PORT "$@"' \
  HAS_LOAD=1 LOAD_TARGET_USERS=5 'LOAD_LEVELS=1 5' 'LOAD_CMD=echo LOAD users=$USERS check=${TARGET_CHECK:-0} port=$a_PORT'
run health; rc_is "health before start" 1; has "down before start" "a: down"
run e2e t1; rc_is "e2e starts what is missing" 0; has "e2e starts, runs, stops its own" "a: started" "E2E port=47110 t1" "a: stopped"
run health; has "e2e left nothing running" "a: down"
run dev-bg; rc_is "dev-bg" 0; has "dev-bg starts" "a: started"
run health; rc_is "health after dev-bg" 0; has "healthy with its port" "a: healthy (port 47110)"
run dev-bg; has "dev-bg reuses a healthy component" "a: already running"
run e2e; has "e2e reuses the running demo" "E2E port=47110"; lacks "e2e does not stop the demo" "a: stopped"
run health; has "demo still running after e2e" "a: healthy"
run doctor; has "doctor sees the running component" "ok    a: running (port 47110)"
run stop; has "stop" "a: stopped"
run health; has "down after stop" "a: down"
printf 'PORT_OFFSET=10\n' > .harness/local
run e2e; has "ports move with PORT_OFFSET" "E2E port=47120"
rm .harness/local
run load; rc_is "load" 0
has "load runs each level on production ports, target check only at the target" "load: 1 users" "LOAD users=1 check=0 port=47210" "LOAD users=5 check=1 port=47210"
run health; has "load stopped its production processes" "a: down"
printf '%s\n' 'COMPONENTS=a b' 'b_DEV=exit 1' 'b_HEALTH=exit 1' >> .harness/config
run dev-bg; rc_is "a component that dies fails dev-bg" 1; has "failure named, earlier one stopped" "b exited before it became healthy" "a: stopped"
run health; has "nothing left running after the failure" "a: down"

# ====================================================================================
echo "== scenario 6: install.sh"
d=$TMP/repo-install; mkdir -p "$d" && cd "$d" || exit 1
git init -q . && git config user.name t && git config user.email t@t && git config core.autocrlf false
mkdir -p .harness; printf '%s\n' MODE=FULL AGENT_FILES=CLAUDE.md > .harness/config
printf '%s\n' '# Mine' 'keep me' > AGENTS.md
OUT=$("$BASH" "$INSTALL" 2>&1 | tr -s ' '); RC=$?
rc_is "install runs" 0
has "install writes the fixed files" "copied scripts/hm.sh" "copied scripts/harness-state.sh" "appended AGENTS.md (# Harness section)" \
  "wrote CLAUDE.md" "copied docs/STANDARDS.md" "copied docs/tasks/_template.md" "wrote .githooks/pre-commit" "install: ok"
OUT=$(cat AGENTS.md); has "existing AGENTS.md kept and extended" "keep me" "# Harness" "## Ask the user when"
OUT=$(cat CLAUDE.md); has "agent entry file points to AGENTS.md" "@AGENTS.md"
OUT=$(cat .harness/config); has "commands section appended" "# Commands (hm-setup" "TYPECHECK_CMD=" "MODE=FULL"
same "hooks path set" "$(git config core.hooksPath)" ".githooks"
[ -f scripts/test-harness-state.sh ] && bad "the tests are not installed into projects" "" || ok "the tests are not installed into projects"
[ -f docs/REVIEW.md ] && bad "the review guide stays in the skills" "" || ok "the review guide stays in the skills"
OUT=$("$BASH" "$INSTALL" 2>&1 | tr -s ' ')
has "second run keeps everything" "kept docs/STANDARDS.md" "kept AGENTS.md (harness section already there)" "kept CLAUDE.md" "kept .harness/config commands section"
same "no duplicate .gitignore lines" "$(grep -cx 'artifacts/' .gitignore)" "1"
same "one commands section" "$(grep -c '^# Commands (hm-setup' .harness/config)" "1"
for m in 'feat(task-3): add search' 'fix: typo' 'Merge branch task/3' 'chore(cr-2): x' 'revert(task-3): drop export'; do
  printf '%s\n' "$m" > "$TMP/msg"; sh .githooks/commit-msg "$TMP/msg" >/dev/null 2>&1 && ok "commit-msg accepts '$m'" || bad "commit-msg rejected '$m'" ""
done
for m in 'added search' 'feat:no space' 'Feat(x): y'; do
  printf '%s\n' "$m" > "$TMP/msg"; sh .githooks/commit-msg "$TMP/msg" >/dev/null 2>&1 && bad "commit-msg accepted '$m'" "" || ok "commit-msg rejects '$m'"
done
OUT=$(cat .githooks/pre-commit); has "pre-commit runs the hook check" "bash scripts/hm.sh check --hook"

# ====================================================================================
echo
echo "passed $PASS, failed $FAIL"
[ "$FAIL" -eq 0 ]
