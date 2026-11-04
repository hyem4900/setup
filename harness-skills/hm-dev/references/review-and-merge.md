# Harness: Apply review and Integrate (part of hm-dev)

Read this for a review to apply ("리뷰 반영해: ...") or a merge ("Merge Task <id>.", "Merge branch <branch>."). The top of SKILL.md still applies: AGENTS.md, and without the harness references/no-harness.md and the Inputs in references/develop-without-harness.md.

# Apply review

## Preconditions
- Input is one of:
  - A path to a review file (e.g. `리뷰 반영해: artifacts/review/task-2-review-1.md`). Read that file and use it. Do not ask for pasted text.
  - Pasted review text in the review output format (references/review-guide.md in this skill's folder). If no file exists for it yet, save it with the next free number first (scratch files: artifacts/ with the harness, else the Inputs in develop-without-harness.md).
  - A review in any other shape: pull request comments, another tool's report, a security review, notes. Turn it into the Findings table of the review format first: one row per finding, `RV-<n>`, the severity as given or, if it has none, estimated and marked `(estimated)`, file:line, problem, suggested fix. Save it as the next free review file (no task: `review-<branch, with / as ->-<k>.md`) and show it with the plan in Step 1.
- Work where the branch lives: the task's worktree (`bash scripts/harness-state.sh worktree <id>`), or with WORKTREES=0 the main worktree switched to task/<id>. Review all: the main worktree. No task (no harness, or a review of a branch that is not task/<id>): the branch the review is about, checked out in the current worktree. A new session is fine; read AGENTS.md and the task file first, if they exist.
- With a task: it is In Review on task/<id>. Review all: tasks merged without their own review are In Review on INTEGRATION.
- `git status --porcelain` is empty where you work (and in the main worktree too when MERGE=local and you will merge there).

Naming by review type:

| Review | Branch you commit on | Commit scope |
|---|---|---|
| Task <id> | task/<id> | `fix(task-<id>)` / `docs(task-<id>)` |
| All | `fix/review-all-<k>`, created from the review's `Commit:` sha (k from the review file name; after a re-review that sha is the previous fix branch's head, so the fixes carry over) | `fix(all)` / `docs(all)`; the status rule applies to every task file on that branch that is In Review |
| No task (a branch) | that branch | `fix:` / `docs:` |

If the Findings table is empty, skip Steps 1–5. With a task, do Steps 6–8. Without a task, Steps 6–8 do not apply: there is no task file, status or docs/reviews/ to update, and nothing is merged until I say "Merge branch <branch>.".

## Steps
1. Make a plan table and show it before editing:
   `| RV-ID | Axis | Severity | Action (fix / defer / reject) | Kind | Reason |`
   - Kind: `mechanical` when a fixed pattern could catch it (a banned call, an import shape, a file location, a missing attribute), else `judgement`.
   - Blocker, Major: fix. If you disagree with one, mark it reject with a reason and ask me before continuing.
   - Minor: fix if it takes a few lines, otherwise defer to the task file's Issues found (no task: list it in the report).
   - Nit: fix only if trivial.
   - If a fix needs an interface contract, data model, dependency, or PROTECTED path change, ask me first.
2. Review all: `git switch -c fix/review-all-<k> <Commit sha>` in the main worktree (or a worktree at that sha).
3. For each fix of a missing test or an AC gap, write the test first and see it fail.
4. Apply fixes, running the tests you touch as you go. Then, if any fix changed code or tests, the full `bash scripts/hm.sh test` and `bash scripts/hm.sh e2e` must pass; `bash scripts/hm.sh check` must pass either way.
5. Commit: `fix(<scope>): address review RV-1, RV-3, ...` (no task: `fix: address review RV-1, RV-3, ...`)
6. Copy the review file to docs/reviews/ with the same name. Update the task file (Review all: every task file that is In Review):
   - Log entry: link to docs/reviews/<file>, the result, what changed
   - Deferred items in Issues found
   - A `judgement` finding whose kind already appeared in an earlier file in docs/reviews/: one line in docs/STANDARDS.md "Project rules" (if the project has that file) (the rule, then the RV-IDs and review files it came from), unless a line already covers it. A `mechanical` one goes in your report under Checks to add instead.
   - Status:
     - If any Blocker was fixed: stay In Review. Tell me to run hm-review, "Re-review Task <id>." (or "Re-review all."), in a separate session. Do not integrate.
     - Otherwise (no Blocker, or every Blocker rejected with my approval): Done.
7. Commit docs/reviews/<file>, the task file(s) and docs/STANDARDS.md if it changed: `docs(<scope>): review applied`
8. If the status is Done: Integrate.

# Integrate
For a Done task, a `Review: batch` task that is In Review (after development), a review-all fix branch, a step-5 branch (perf/<n>, security/<n>), or any branch I name. "Merge Task <id>." and "Merge branch <branch>." start here, with the same place-to-work and clean-tree checks as Apply review. Without the harness, INTEGRATION and MERGE are the defaults in no-harness.md, and Step 2 does not apply.
1. Note the branch head (`git rev-parse HEAD`), then bring INTEGRATION into the branch, in the branch's worktree: MERGE=pr: `git fetch <REMOTE>` and merge `<REMOTE>/<INTEGRATION>`; MERGE=local: merge `<INTEGRATION>`.
   - No conflict: go on.
   - Conflicts only in docs, lockfiles (regenerate them with the install command) or other mechanical spots (imports, lists both sides add to): resolve, commit the merge.
   - A conflict in logic: `git merge --abort`, stop and ask me. Resolving it changes reviewed code, so it needs my decision and usually a re-review.
2. Record the development decisions (task branches only; skip if the task file's Decisions during development has no DQ lines, or they already carry `→ R-xx/AC-n` or `→ D-xx`):
   - Each behavior DQ becomes an AC under its R-xx in REQUIRE.md, with the next free AC number for that R-xx (numbered now, after INTEGRATION was merged in, so it is current): `R-03/AC-5: Given … When … Then … (clarified in Task <id> DQ-2)`.
   - Each approach DQ becomes a D-xx in DECISIONS.md (next free number, Status Accepted, Context `Task <id> DQ-n`), and updates the SPEC section it affects (e.g. §3 for a stored format, §4 for a contract).
   - Append `→ R-03/AC-5` or `→ D-07` to the DQ line in the task file, so it is moved only once. Tests keep their DQ names; the AC line names the DQ, so the link holds.
   - Commit: `docs(task-<id>): record development decisions`.
3. If the merge brought a change outside Markdown (`git diff --name-only <noted head> HEAD` lists a file that is not `*.md`): the full `bash scripts/hm.sh test`, `bash scripts/hm.sh e2e` and `bash scripts/hm.sh check` must pass on the branch. If it brought only Markdown or nothing, the full runs at the noted head (Develop's last run, the review, or the fixes) still hold: skip them. If they fail, stop and ask.
4. MERGE=local: in the main worktree, clean and on INTEGRATION (WORKTREES=0: `bash scripts/hm.sh stop`, then `git switch <INTEGRATION>`): `git merge --no-ff --no-edit <branch>`. Then, WORKTREES=1: `bash scripts/hm.sh stop` in the task's worktree and `git worktree remove <dir>` (keep the branch). WORKTREES=0: the main worktree stays on INTEGRATION.
5. MERGE=pr: `git push -u <REMOTE> <branch>`. Write the pull request body in DOC_LANG to artifacts/pr/<branch, with `/` as `-`>.md (scratch files: artifacts/ with the harness, else the Inputs in develop-without-harness.md):
   - Summary: the smallest list or table that shows what changes for a user or a caller
   - Evidence: test and e2e counts at the pushed head, the review file in docs/reviews/, and the demo screenshots (artifacts/e2e/screenshots/task-<id>/) if any
   - Merge danger: one-way door or two-way door (can it be undone by reverting?), and the blast radius: what breaks, and for whom, if it is wrong
   - Closes: Task <id> and its R-xx (review all: the tasks in the range)
   Tell me to open (or update) the pull request from <branch> into INTEGRATION with that body, and merge it after the team's checks. The task counts as finished once it is merged.

## Undoing a merged task
Every merge is `--no-ff`, so one task is one merge commit on INTEGRATION and can be taken out whole: `git revert -m 1 <merge commit>` (find it with `git log --merges --oneline -- docs/tasks/<id>.md`). Do it only when I ask ("Task <id> 되돌려" / "revert Task <id>"), on INTEGRATION in a clean main worktree, with the full `test`, `e2e` and `check` afterwards; commit as `revert(task-<id>): <reason>`. Then set the task file to Dropped with the revert commit in its Log (that status line is parsed, so keep it exact), and tell me to record the requirement change through hm-change ("요구사항 변경해: ..." / a removal) if the behavior is gone for good; a task that will come back later instead stays Done and gets a new task through hm-change. With MERGE=pr, push the revert as a branch for a pull request like any change. A revert of a task that others already built on may conflict: stop and ask, as for any logic conflict.

## End of Apply review and Integrate
Report in CHAT_LANG: fixed / deferred / rejected counts, test results, final status, whether it was merged (or pushed and waiting for the team, with the PR body path), and the next step, including tasks that the merge unblocked (`bash scripts/harness-state.sh status`). When no task is left to start or in flight, the next step is the final check ("최종 확인해") and the step-5 skills not run since the last merge (no or older docs/TRACEABILITY.md: "누락 검토해", hm-audit; no or older docs/LOAD_TEST.md while SPEC §10 has targets: "부하 테스트 해", hm-load-test; no or older docs/security/review-<k>.md: "보안 점검해", hm-security), and last hm-explain ("설명 문서 만들어"). If that status prints a `review backlog:` line ending in `(suggest: Review all.)`, say in Next that enough batch work is merged to be worth a "Review all." in a separate session now rather than at the end; it is a suggestion, I decide.
Then, if any finding was `mechanical`, add **Checks to add**: per finding, the rule a check would enforce (a LINT_CMD rule or a guardrail pattern in .harness/config) and what it would have caught. I decide; an approved check becomes a chore task through hm-change.
Then stop.
