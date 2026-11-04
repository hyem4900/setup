---
name: hm-dev
description: 'Steps 3 and 4.2 of the harness flow: the development session. Use for "Start Task <id>." / "Continue Task <id>." (one task on its own branch, test-first, ending in a report that offers a demo), "Demo Task <id>." / "데모 보여줘" (start the product and walk me through the task''s demo scenario), "최종 확인해" / "Final check." (test, e2e, check, security, every load target and the evidence for each promised target on the integration branch, report only), or "개발해: ..." without the harness; applying a review of any shape ("리뷰 반영해: ...", "Apply these review comments: <file>"); "Merge Task <id>." / "Merge branch <branch>." (the only step that integrates) and "Task <id> 되돌려" / "Revert Task <id>."; and debugging ("디버깅해: ...", "원인 찾아줘: ...", "왜 느린지 찾아줘").'
argument-hint: '"Start Task <id>." | "Continue Task <id>." | "Demo Task <id>." | "개발해: ..." | "리뷰 반영해: <파일>" | "Merge Task <id>." | "디버깅해: ..."'
---

# Harness Steps 3 and 4.2: Develop, apply review, integrate

Follow AGENTS.md. Do only the part my message asks for:

| My message | Part |
|---|---|
| "Start Task <id>." / "Continue Task <id>." / "개발해: <request or file>" ("Implement: ...") | Develop |
| "Demo Task <id>." / "데모 보여줘" / yes to the demo offer at the end of a report | Demo (below) |
| "최종 확인해" / "Final check." | Final check (below) |
| A review in any shape: a file path, pasted text, pull request comments ("리뷰 반영해: ...", "Apply these review comments: ...") | Apply review: read references/review-and-merge.md in this skill's folder and follow it |
| "Merge Task <id>." / "Merge branch <branch>." | Integrate: the same file, its "Integrate" part |
| "Task <id> 되돌려" / "Revert Task <id>." | the same file, "Undoing a merged task" |
| "디버깅해: ...", "원인 찾아줘: ...", "왜 느린지 찾아줘", or a Develop rule sends you there | Read references/debug.md in this skill's folder and follow it |

Without the harness (no .harness/config): read references/no-harness.md and references/develop-without-harness.md in this skill's folder first. They hold the session defaults, what stands in for each harness file, and how "개발해: ..." starts; everything below still applies.

# Develop

## Preconditions (Start Task <id>.)
1. `bash scripts/harness-state.sh start-check <id>`. `result=stop`: tell me the reason in CHAT_LANG and stop (it checks the task file and its status, a branch someone else may own, unmerged dependencies, PARALLEL and a dirty worktree). `result=ok` gives `dir`, `offset`, `base`, `branch_exists`; a worktree and PORT_OFFSET named in my message (or hm-auto's prompt) win over them. A request with no task file goes through hm-change first: tell me ("요구사항 추가해: ..." / "버그 등록해: ...") and stop.
2. Read files in the order in AGENTS.md.
3. SESSION_PER_TASK (.harness/config). 1: this session has not worked on another task or run harness steps 1–2; if it has, tell me to start a new session and stop. 0: an earlier task in this session is fine once its report was sent; re-read the files anyway and trust the docs and `git log`, not what you remember. Missing: ask me 1 or 0, write it to .harness/config, then continue.
4. Create the place to work:
   - WORKTREES=1: `git worktree add -b task/<id> <dir> <base>` (`branch_exists=yes`: `git worktree add <dir> task/<id>`), write `PORT_OFFSET=<offset>` to `<dir>/.harness/local`, run `bash scripts/hm.sh setup` in `<dir>`. From here on, run every command inside `<dir>`.
   - WORKTREES=0: `git switch -c task/<id> <base>` (`branch_exists=yes`: `git switch task/<id>`).
5. `bash scripts/hm.sh check` passes.

`base` may be `task/<d>` (STACK=1): Task <d> is finished but still in review, and this task builds on its branch. Then, before step 3 of the Task workflow (the full suites), merge in what Task <d> changed since you started: INTEGRATION if Task <d> is merged by then, otherwise the latest `task/<d>`; resolve conflicts in favor of Task <d>'s review fixes. This task's review and merge wait until Task <d> is merged (the script holds them).

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
- Stop every process you started; leave nothing running. A demo is not prepared unless I ask for it (Demo below).
- The report's "Next" line follows the task's Review policy and SESSION_PER_TASK. With SESSION_PER_TASK=0 and an already long context, recommend a new session anyway.
- STOP. No next task until I say so, no merge (a `Review: each` task waits for its review), no review of your own code. With SESSION_PER_TASK=0, a demo I ask for runs before the next task starts in this session.

# Demo (Demo Task <id>.)
Only when I ask. It shows me the task working; it changes nothing in the repository (no commits, no edits).
1. Where: if task/<id> is not merged into INTEGRATION, its worktree (`bash scripts/harness-state.sh worktree <id>`; WORKTREES=0: the main worktree, switched to task/<id> if it is not there). If it is merged, the main worktree at INTEGRATION, or at a branch that contains the merge. Without the harness: the branch the work is on. Never switch a worktree that has uncommitted changes: tell me which work is in the way and stop.
2. Start the product there: `bash scripts/hm.sh dev-bg` on that worktree's ports (HAS_SERVER=1; if a component fails because the worktree was never set up, `bash scripts/hm.sh setup` first), then `bash scripts/hm.sh health`. Data the scenario needs: only through the product's own screens, API or the documented setup command, never by editing PROTECTED files.
3. Send, in CHAT_LANG: the task's Demo scenario as steps I can follow (the URL or command with the ports, the accounts, what to expect at each step), the screenshots in artifacts/e2e/screenshots/task-<id>/ if any, and how to end it ("데모 끝" / "done").
4. Leave the demo running. When I say it is done, or before the next step that uses this worktree, `bash scripts/hm.sh stop`.
5. A change I ask for while watching is a change request: tell me to say "수정 요청: ..." (hm-change), or, under hm-auto, the orchestrator collects it.
6. When I say it is done: stop it and repeat the next step from the task's report (its review or merge).

# Final check (최종 확인해 / Final check.)
The checklist before I submit or ship: it measures the integration branch as it is, fixes nothing, and changes nothing in the repository (no commits, no edits). hm-auto runs it at the end of a run of target `all`; I may ask for it any time.
1. Where: the main worktree, at the head of INTEGRATION and clean. If it is on another branch or has uncommitted changes, tell me and stop. If a component fails because the worktree was never set up, `bash scripts/hm.sh setup` first.
2. Run, and record each result (do not stop at the first failure): `bash scripts/hm.sh test`, `bash scripts/hm.sh e2e`, `bash scripts/hm.sh check`; `bash scripts/hm.sh security` (it fails only at the SPEC §12 severity in the dependencies the product ships with); HAS_LOAD=1: `bash scripts/hm.sh load` once at each target in tests/load/targets.json (a target without a scenario is "not measured", never invented); SPEC §10b targets: `bash scripts/hm.sh bench`. Stop every process you started.
3. Collect the evidence for every target the product promised, beyond the suites: each NFR-xx in REQUIRE §6, each SPEC §10 target, and each SPEC §6 core computation (does its result meet the "Quality" line on the real data: a measured number, a comparison with another approach or a bound, or the named test that asserts it; `Quality: not set` is N/A with that reason, an older SPEC without the line is judged by its "Result" line). Evidence is a measurement from step 2, a test that asserts that exact target (name it), or a result file in the repository with its date and commit. Passing suites alone are not evidence for a target no test asserts: that row is "not measured", never pass. Measure nothing new beyond step 2; a target that would need a new script or scenario is "not measured", with what measuring it would take.
4. Report in CHAT_LANG, in one table: item (test, e2e, check, security, each NFR-xx, each load and benchmark target, each §6 computation), target, result (counts, p95, error rate, findings, the measured value), evidence (the command, test name or file), and one of pass / fail / not measured / N/A. N/A carries its reason (e.g. "no load target: HAS_LOAD=0"). Then the failures, one line each, worded as a change request I can copy ("수정 요청: ..."), with what fixing it would take in one phrase. Last, two separate lines, never merged into one verdict:
   - Behavior: the suites (test, e2e, check, security) all pass, or which fail.
   - Targets: N pass, N fail, N not measured (list the not measured ones). "Ready to submit" only when nothing fails and nothing is not measured; otherwise name what matters most.
5. Do not fix anything, even a one-line change: I decide what to fix before the deadline.
6. End the report with the next step: each failure is fixed through its "수정 요청: ..." (hm-change); then the step-5 skills not run since the last merge (no or older docs/TRACEABILITY.md: "누락 검토해", hm-audit; no or older docs/LOAD_TEST.md while SPEC §10 has targets: "부하 테스트 해", hm-load-test; no or older docs/security/review-<k>.md: "보안 점검해", hm-security); last, hm-explain ("설명 문서 만들어") writes docs/EXPLAIN.md.

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
8. Send the report (format below). Do not prepare a demo.
9. STOP and wait. Do not start another task until the user says so (in this session only if SESSION_PER_TASK=0).

## Report format (in CHAT_LANG)
- Summary (3 lines at most)
- chore, spike, docs: what changed and the evidence (tests that still pass, or the Findings)
- Test results: unit N passed, e2e N passed, (load / bench: p95 ms)
- Needs checking / open issues
- Next:
  - Review: each → hm-review, "Review Task <id>." in a separate session (review always runs in a separate session)
  - Review: batch → hm-dev, "Merge Task <id>." (merged without its own review; hm-review "Review all." covers it later)
  - Tasks that can start now (their dependencies are merged): hm-dev, "Start Task <id>.", or several at once with hm-auto ("자동으로 진행해"). SESSION_PER_TASK=1: in a new session; 0: also in this session
- feature and bug: last, the demo offer, in the question format of AGENTS.md: `**Task <id> demo**`, ❓ whether I want to see the demo now ("데모를 보여드릴까요?"), 🔍 what it would show in one line (from the task's Demo scenario) and the E2E screenshots that already show it, if any; ➡️ yes only if "Needs checking" lists something to see on screen, otherwise skip it and look later with "Demo Task <id>.", with the reason. Yes starts Demo above; anything else needs nothing.

## Definition of Done
- By type. feature: every AC is covered by passing unit or E2E tests. bug: the regression test failed before the fix and passes after it. chore: existing tests pass with unchanged assertions. spike: Findings answer the question with a recommendation. docs: the docs match the code.
- `bash scripts/hm.sh test`, `bash scripts/hm.sh e2e`, `bash scripts/hm.sh check` pass on the task branch after INTEGRATION is merged into it
- (HAS_UI=1) E2E follows the selector policy in SPEC §5
- Each SEC-xx in the task's Requirements has a passing test that proves it
- Commits follow `<type>(task-<id>): <summary>`
- Review comments applied and committed (Review: each), or the task is covered by a later "Review all." (Review: batch)
- Only then does the task file show Done (set by the apply-review step)
