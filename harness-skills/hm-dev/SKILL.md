---
name: hm-dev
description: Steps 4 and 5-2 of the harness flow: the development session. Use for "Start Task <id>." / "Continue Task <id>." (one task on its own branch, test-first, ending in a demo report), or "개발해: ..." without the harness; applying a review of any shape ("리뷰 반영해: ...", "Apply these review comments: <file>"); "Merge Task <id>." / "Merge branch <branch>." (the only step that integrates) and "Task <id> 되돌려" / "Revert Task <id>."; and debugging ("디버깅해: ...", "원인 찾아줘: ...", "왜 느린지 찾아줘").
---

# Harness Steps 4 and 5-2: Develop, apply review, integrate

Follow AGENTS.md (it sets the languages: CHAT_LANG for talking to me, DOC_LANG for documents; code, identifiers and the fixed tokens scripts parse stay in English; questions use its ❓/➡️ format). Do only the part my message asks for:

| My message | Part |
|---|---|
| "Start Task <id>." / "Continue Task <id>." / "개발해: <request or file>" ("Implement: ...") | Develop |
| A review in any shape: a file path, pasted text, pull request comments ("리뷰 반영해: ...", "Apply these review comments: ...") | Apply review: read references/review-and-merge.md in this skill's folder and follow it |
| "Merge Task <id>." / "Merge branch <branch>." | Integrate: the same file, its "Integrate" part |
| "Task <id> 되돌려" / "Revert Task <id>." | the same file, "Undoing a merged task" |
| "디버깅해: ...", "원인 찾아줘: ...", "왜 느린지 찾아줘", or a Develop rule sends you there | Read references/debug.md in this skill's folder and follow it |

Other skills: use another skill only when my message names it or a step of this skill names it. An installed skill whose description seems to fit the work (a design system, charts, documents) stays unused, unless SPEC or DECISIONS records that I chose it.
Files I name: a file named in my message is the first source for the role I give it, and harness files only fill what it lacks. If they disagree, show the difference and ask which one wins. If it is missing or does not fit that role, say so in one line and go on without it. Read it; edit it only if I ask.

## Inputs
Find each input in this order, and name in your report the file that served (e.g. `Review source: PR comments (stand-in for a review file)`): a file I name → the harness file → a file in the repository that plays the same role (ask once if several fit) → the fallback.
Without the harness (no .harness/config), every part still works; Develop starts from a request or a task file ("Preconditions (without the harness)"). Follow references/no-harness.md in this skill's folder for what not to create and the session defaults (languages, INTEGRATION, WORKTREES=0, MERGE=local, the repository's own commands, scratch files, the question format).

| Input | Harness file | Stand-ins to look for | Fallback |
|---|---|---|---|
| Rules, languages, question format | AGENTS.md | CONTRIBUTING.md, an agent instruction file (CLAUDE.md and the like) | the defaults above |
| Task workflow, report format, Definition of Done | AGENTS.md | — | those three sections of `templates/AGENTS.template.md` in the hm-setup skill folder (`../hm-setup/` from this skill's folder); read them there, never copy the file |
| Task | docs/tasks/<id>.md | an issue or spec file I name, my message | a new task file (Preconditions (without the harness)) |
| Requirements and test seams | REQUIRE.md, SPEC §7 | a requirements or design doc; the folders the repository's tests are in | the task file's own acceptance criteria |
| Review to apply | a file under artifacts/review/ | pasted text, pull request comments, another tool's report | none: ask me for the review |
| Standards for fixes | docs/STANDARDS.md | CONTRIBUTING.md, CODING_STANDARDS.md, the lint configuration | none |
| test, e2e, check | `bash scripts/hm.sh test / e2e / check` | the repository's commands | none: say which checks did not run |
| Formatting before a commit | the pre-commit hook (`bash scripts/hm.sh fmt`) | the repository's format command or hook | none: match the surrounding style |
| Scratch files (reviews, debug, PR bodies) | artifacts/ | — | the OS temp directory, unless git ignores artifacts/ (`git check-ignore -q artifacts/x`) |

# Develop

## Preconditions (Start Task <id>.)
1. No .harness/config: use "Preconditions (without the harness)" below. Otherwise AGENTS.md and docs/tasks/<id>.md exist on INTEGRATION; if not, stop and tell me to run hm-setup (or hm-change for a new task).
2. Read files in the order in AGENTS.md.
3. Run `bash scripts/harness-state.sh worktree <id>`. It prints `dir`, `offset`, `base`, `status`, `where`, `blocked_by`. If my message (or hm-auto's prompt) already gives a worktree and PORT_OFFSET, use those.
4. The task is Todo. `where` is not `remote`: a task/<id> branch that exists only on REMOTE belongs to someone else. If a local task/<id> branch exists with commits beyond `base`, ask me (an earlier session may own it). A branch with no commits beyond `base` (an earlier start that stopped before its first commit) may be reused.
5. `blocked_by` is empty: every task in Depends on is merged into INTEGRATION.
6. Fewer than PARALLEL tasks are In Progress (`bash scripts/harness-state.sh status`). If not, ask me.
7. Session rule from SESSION_PER_TASK in .harness/config:
   - 1: this session has not worked on another task or run harness steps 1–3. If it has, tell me to start a new session and stop.
   - 0: an earlier task in this session is fine, as long as its demo report was sent. Re-read the files in the AGENTS.md order anyway; trust the docs and `git log`, not what you remember from the earlier task.
   - Missing: ask me 1 or 0, write it to .harness/config, then continue.
8. Create the place to work:
   - WORKTREES=1: `git worktree add -b task/<id> <dir> <base>` (or `git worktree add <dir> task/<id>` to reuse an empty branch), write `PORT_OFFSET=<offset>` to `<dir>/.harness/local`, run `bash scripts/hm.sh setup` in `<dir>`. From here on, run every command inside `<dir>`.
   - WORKTREES=0: the main worktree is clean; `git switch -c task/<id> <base>` (or `git switch task/<id>`).
   - MERGE=pr: `git fetch <REMOTE>` first, so `base` is the team's latest INTEGRATION.
9. `bash scripts/hm.sh check` passes.

If any check fails, tell me which one in CHAT_LANG and stop.

## Preconditions (without the harness)
For "개발해: <request or file>", or "Start Task <id>." when there is no .harness/config. With the harness, a request that has no task file goes through hm-change first: tell me ("요구사항 추가해: ..." / "버그 등록해: ...") and stop.
1. The task: docs/tasks/<id>.md if it exists (written earlier, e.g. by hm-change without the harness), else a new one. For a new one, read `templates/task.template.md` in the hm-setup skill folder and write docs/tasks/<id>.md from it: the next free number in docs/tasks/ (from 1), `- Status: In Progress`, `- Type:` from the request, `- Review: each`, `- Depends on: none`, `- Requirements: none` (or the IDs of a requirements doc I named), `- Source:` my message or the file. Acceptance criteria as Given/When/Then with concrete values, with IDs `T<id>/AC-<n>` (feature and bug), or "Done when" bullets; a demo scenario for feature and bug.
2. If the request leaves a value or a behavior open, ask in one round before writing the criteria, and never guess. Show me the criteria in a few lines and go on unless I correct them.
3. The tree is clean. Base: INTEGRATION (Inputs); if the current branch is another one with commits not on INTEGRATION, ask which base.
4. `git switch -c task/<id> <base>` (or `git switch task/<id>` for an existing empty branch), then commit the task file: `chore(task-<id>): start`.
Steps that need the harness do not apply: harness-state.sh, PARALLEL, SESSION_PER_TASK, worktrees, the Review policy.

## Preconditions (Continue Task <id>.)
Use when a session ended mid-task.
1. task/<id> exists and its task file says In Progress. Work in its worktree (`harness-state.sh worktree <id>`), or with WORKTREES=0 (and without the harness) switch the main worktree to task/<id> if it is not there already (uncommitted changes of this same task may be present: keep them).
2. Read the task file's Notes for Next Session and Log, `git diff <base>...HEAD`, and uncommitted changes.
3. Tell me in two lines what is done and what is left, then continue from the first unfinished workflow step.

## Workflow
Run the Task workflow in AGENTS.md in order (without the harness: the one Inputs points to; its step 1 is already done). Additional rules:
- Commit only on task/<id>, only inside its worktree.
- feature and bug tasks (a missing `- Type:` means feature): read references/tdd.md before the first test. A bug whose cause is not obvious: references/debug.md.
- If the work turns out to be a different type than the task says (a "chore" that must change behavior, a "bug" that is really a missing feature), stop and ask; the fix goes through hm-change.
- Name each test after its full AC ID: `R-01/AC-1` → `test_r01_ac1_...` (snake case), `r01-ac1: ...` (description strings), or the stack's naming style with the same parts. AC numbers restart per R-xx, so never use the AC number alone. A task's own criteria `T3/AC-1` → `test_t3_ac1_...`.
- (HAS_UI=1) Each E2E test saves one full-page screenshot per demo step to artifacts/e2e/screenshots/task-<id>/<step>.png.
- When a test fails, read the error, form one hypothesis, fix, re-run. After 3 failed attempts on the same test, switch to references/debug.md (that test is its loop); ask only when it says to.
- Keep the change inside the task's scope. If you notice a bug outside it, add it to the task file's Issues found instead of fixing it.
- Questions follow AGENTS.md "Ask the user when". When I answer one, record it in the task file's Decisions during development as `DQ-<n>` (behavior or approach, the R-xx, the question, the answer, the resulting behavior with concrete values), add a test named after it that fixes that behavior, and add a Log entry. Do not edit REQUIRE.md or DECISIONS.md yourself: Integrate moves the DQs there (without the harness they stay in the task file).
- If your context is getting long before the task is done: commit work in progress as `wip(task-<id>): <state>`, update Notes for Next Session with exact next steps, and tell me to run "Continue Task <id>." in a new session. Only that case makes a wip commit; a question leaves the work uncommitted (AGENTS.md), and "Continue Task <id>." picks it up.
- Before reporting, update Notes for Next Session: what the next session of this task (and its reviewer) must know, any workaround in place, any flaky test.

## End of Develop
- Leave only the demo running (feature and bug tasks: `bash scripts/hm.sh dev-bg`, HAS_SERVER=1, on this worktree's ports). Stop any other process you started.
- Send the report in the format from AGENTS.md (chore, spike and docs tasks: no demo, the evidence instead). Its "Next" line follows the task's Review policy and SESSION_PER_TASK. With SESSION_PER_TASK=0, if the context is already long, recommend a new session anyway. Without the harness, "Next" is "이 브랜치 리뷰해" (hm-review) in a separate session, or "Merge branch task/<id>." once I am satisfied.
- STOP. Do not start another task until I say so, do not merge (that waits for the review, or for the demo check of a `Review: batch` task), and do not review your own code. With SESSION_PER_TASK=0 the demo gate still applies: I check the demo before the next task starts in this session.
