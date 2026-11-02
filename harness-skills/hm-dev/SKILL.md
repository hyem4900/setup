---
name: hm-dev
description: 'Steps 4 and 5-2 of the harness flow: the development session. Use for "Start Task <id>." / "Continue Task <id>." (one task on its own branch, test-first, ending in a demo report), or "개발해: ..." without the harness; applying a review of any shape ("리뷰 반영해: ...", "Apply these review comments: <file>"); "Merge Task <id>." / "Merge branch <branch>." (the only step that integrates) and "Task <id> 되돌려" / "Revert Task <id>."; and debugging ("디버깅해: ...", "원인 찾아줘: ...", "왜 느린지 찾아줘").'
argument-hint: '"Start Task <id>." | "Continue Task <id>." | "개발해: ..." | "리뷰 반영해: <파일>" | "Merge Task <id>." | "디버깅해: ..."'
---

# Harness Steps 4 and 5-2: Develop, apply review, integrate

Follow AGENTS.md. Do only the part my message asks for:

| My message | Part |
|---|---|
| "Start Task <id>." / "Continue Task <id>." / "개발해: <request or file>" ("Implement: ...") | Develop |
| A review in any shape: a file path, pasted text, pull request comments ("리뷰 반영해: ...", "Apply these review comments: ...") | Apply review: read references/review-and-merge.md in this skill's folder and follow it |
| "Merge Task <id>." / "Merge branch <branch>." | Integrate: the same file, its "Integrate" part |
| "Task <id> 되돌려" / "Revert Task <id>." | the same file, "Undoing a merged task" |
| "디버깅해: ...", "원인 찾아줘: ...", "왜 느린지 찾아줘", or a Develop rule sends you there | Read references/debug.md in this skill's folder and follow it |

Without the harness (no .harness/config): read references/no-harness.md and references/develop-without-harness.md in this skill's folder first. They hold the session defaults, what stands in for each harness file, and how "개발해: ..." starts; everything below still applies.

# Develop

## Preconditions (Start Task <id>.)
1. `bash scripts/harness-state.sh start-check <id>`. `result=stop`: tell me the reason in CHAT_LANG and stop (it checks the task file and its status, a branch someone else may own, unmerged dependencies, PARALLEL and a dirty worktree). `result=ok` gives `dir`, `offset`, `base`, `branch_exists`; a worktree and PORT_OFFSET named in my message (or hm-auto's prompt) win over them. A request with no task file goes through hm-change first: tell me ("요구사항 추가해: ..." / "버그 등록해: ...") and stop.
2. Read files in the order in AGENTS.md.
3. SESSION_PER_TASK (.harness/config). 1: this session has not worked on another task or run harness steps 1–3; if it has, tell me to start a new session and stop. 0: an earlier task in this session is fine once its demo report was sent; re-read the files anyway and trust the docs and `git log`, not what you remember. Missing: ask me 1 or 0, write it to .harness/config, then continue.
4. Create the place to work:
   - WORKTREES=1: `git worktree add -b task/<id> <dir> <base>` (`branch_exists=yes`: `git worktree add <dir> task/<id>`), write `PORT_OFFSET=<offset>` to `<dir>/.harness/local`, run `bash scripts/hm.sh setup` in `<dir>`. From here on, run every command inside `<dir>`.
   - WORKTREES=0: `git switch -c task/<id> <base>` (`branch_exists=yes`: `git switch task/<id>`).
5. `bash scripts/hm.sh check` passes.

If a step fails, tell me which one in CHAT_LANG and stop.

## Preconditions (Continue Task <id>.)
Use when a session ended mid-task.
1. task/<id> exists and its task file says In Progress. Work in its worktree (`bash scripts/harness-state.sh worktree <id>`), or with WORKTREES=0 (and without the harness) switch the main worktree to task/<id> if it is not there already; uncommitted changes of this same task may be present: keep them.
2. Read the task file's Notes for Next Session and Log, `git diff <base>...HEAD`, and the uncommitted changes.
3. Tell me in two lines what is done and what is left, then continue from the first unfinished workflow step.

## Workflow
Run the Task workflow (end of this file) in order. Additional rules:
- Commit only on task/<id>, only inside its worktree.
- feature and bug tasks (a missing `- Type:` means feature): read references/tdd.md before the first test. A bug whose cause is not obvious, or the same test still failing after 3 fix attempts: references/debug.md (that test is its loop); ask only when it says to.
- If the work turns out to be a different type than the task says (a "chore" that must change behavior, a "bug" that is really a missing feature), stop and ask; the fix goes through hm-change.
- Name each test after its full AC ID: `R-01/AC-1` → `test_r01_ac1_...` (snake case), `r01-ac1: ...` (description strings), or the stack's naming style with the same parts. AC numbers restart per R-xx, so never use the AC number alone. A task's own criteria `T3/AC-1` → `test_t3_ac1_...`.
- (HAS_UI=1) Each E2E test saves one full-page screenshot per demo step to artifacts/e2e/screenshots/task-<id>/<step>.png.
- Keep the change inside the task's scope. A bug outside it goes to the task file's Issues found, not into the diff.
- My answer to a question (AGENTS.md "Ask the user when") becomes `DQ-<n>` under the task file's Decisions during development: behavior or approach, the R-xx, the question, the answer, the resulting behavior with concrete values; plus a Log entry and a test named after it (`test_task3_dq2_...` / `task3-dq2: ...`) that fixes that behavior. Do not edit REQUIRE.md or DECISIONS.md yourself: Integrate moves the DQs there.
- Context getting long before the task is done: commit `wip(task-<id>): <state>`, update Notes for Next Session with exact next steps, and tell me to run "Continue Task <id>." in a new session. Only that case makes a wip commit (AGENTS.md: a question leaves the work uncommitted).

## End of Develop
- Leave only the demo running (feature and bug tasks, HAS_SERVER=1: `bash scripts/hm.sh dev-bg` on this worktree's ports). Stop every other process you started.
- The report's "Next" line follows the task's Review policy and SESSION_PER_TASK. With SESSION_PER_TASK=0 and an already long context, recommend a new session anyway.
- STOP. No next task until I say so, no merge (that waits for the review, or for the demo check of a `Review: batch` task), no review of your own code. With SESSION_PER_TASK=0 the demo gate still applies: I check the demo before the next task starts in this session.

# Task workflow, report and Definition of Done
The three sections below were part of AGENTS.md until v4.1. An older project's AGENTS.md may still carry them; this file wins.

## Task workflow
1. Start checks (Preconditions above). Create the branch (and worktree), set `- Status: In Progress` in the task file, commit `chore(task-<id>): start`. MERGE=pr: `git push -u <REMOTE> task/<id>` so the team sees the task is taken.
2. Do the work the way the task's `- Type:` says:
   - feature: (GREENFIELD=0) first add characterization tests for existing code you will change; they must pass before you change anything. Then work the task's test list with the loop in references/tdd.md.
   - bug: first write a test that reproduces the bug and fails for that reason. Fix it. The test stays as a regression test. If the cause is not obvious, follow references/debug.md and keep its Diagnosis section in the task file.
   - chore (refactor, dependency upgrade, tooling, infrastructure; no intended behavior change): confirm `test` and `e2e` pass before you change anything. Change. The same tests pass with their assertions unchanged. Add tests only for behavior the task explicitly changes.
   - spike (answer a question): investigate and write the task file's Findings: the answer, the evidence, a recommendation, and follow-up tasks to propose through hm-change. Prototype code only under the path the task names, or none. No production code, no new tests required.
   - docs: documentation only.
3. The full suites pass: `bash scripts/hm.sh test` and `bash scripts/hm.sh e2e` with no arguments (screenshots in artifacts/e2e/screenshots/task-<id>/ if HAS_UI=1). docs and spike tasks: only if they changed code or tests.
4. If the task's DoD includes a load test or benchmark, run `bash scripts/hm.sh load` / `bash scripts/hm.sh bench` and record the numbers in the task file Log
   - A new migration: `bash scripts/hm.sh migrate` after adding it and after merging INTEGRATION in.
   - A write SPEC §3 lists under repeated and concurrent writes: one test sends the request twice (or at once) and the result stays correct.
5. `bash scripts/hm.sh check` passes. If the task adds or upgrades a dependency, or lists a SEC-xx, `bash scripts/hm.sh security` passes too
6. Commit: `<type>(task-<id>): <summary>` (feature: `feat`, bug: `fix`, chore: `chore` or `refactor`, spike and docs: `docs`)
7. In the task file: `- Status: In Review`, Log entry, Notes for Next Session. Commit `docs(task-<id>): ready for review`.
8. feature and bug: prepare the demo (`bash scripts/hm.sh dev-bg` if HAS_SERVER=1)
9. Send the report (format below)
10. STOP and wait. Do not start another task until the user says so (in this session only if SESSION_PER_TASK=0).

## Report format (in CHAT_LANG)
- Summary (3 lines at most)
- Demo (feature and bug): the task's demo scenario as steps I can follow (how to open or call it, what to expect), with the ports PORT_OFFSET gives this worktree
- Instead of a demo (chore, spike, docs): what changed and the evidence (tests that still pass, or the Findings)
- Test results: unit N passed, e2e N passed, (load / bench: p95 ms)
- Needs checking / open issues
- Next:
  - Review: each → "Review Task <id>." in a separate session (review always runs in a separate session)
  - Review: batch → "Merge Task <id>." (merged without its own review; "Review all." covers it later)
  - Tasks that can start now (their dependencies are merged). SESSION_PER_TASK=1: in a new session; 0: also in this session

## Definition of Done
- By type. feature: every AC is covered by passing unit or E2E tests. bug: the regression test failed before the fix and passes after it. chore: existing tests pass with unchanged assertions. spike: Findings answer the question with a recommendation. docs: the docs match the code.
- `bash scripts/hm.sh test`, `bash scripts/hm.sh e2e`, `bash scripts/hm.sh check` pass on the task branch after INTEGRATION is merged into it
- (HAS_UI=1) E2E follows the selector policy in SPEC §5
- Each SEC-xx in the task's Requirements has a passing test that proves it
- Commits follow `<type>(task-<id>): <summary>`
- Review comments applied and committed (Review: each), or the task is covered by a later "Review all." (Review: batch)
- Only then does the task file show Done (set by the apply-review step)
