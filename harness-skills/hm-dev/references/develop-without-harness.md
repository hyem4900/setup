# Developing without the harness (part of hm-dev)

Read this, with references/no-harness.md, when `.harness/config` does not exist. Every part of hm-dev still works: this file says what stands in for each harness file and how a task starts. Steps that need the harness do not apply: `harness-state.sh` (start-check, worktree), PARALLEL, SESSION_PER_TASK, worktrees, the Review policy.

## Inputs
Find each input in this order, and name in your report the file that served (e.g. `Review source: PR comments (stand-in for a review file)`): a file I name → the harness file → a file in the repository that plays the same role (ask once if several fit) → the fallback.

| Input | Harness file | Stand-ins to look for | Fallback |
|---|---|---|---|
| Rules, languages, question format | AGENTS.md | CONTRIBUTING.md, an agent instruction file (CLAUDE.md and the like) | the defaults in no-harness.md |
| Task | docs/tasks/<id>.md | an issue or spec file I name, my message | a new task file (Start, below) |
| Requirements and test seams | REQUIRE.md, SPEC §7 | a requirements or design doc; the folders the repository's tests are in | the task file's own acceptance criteria |
| Review to apply | a file under artifacts/review/ | pasted text, pull request comments, another tool's report | none: ask me for the review |
| Standards for fixes | docs/STANDARDS.md | CONTRIBUTING.md, CODING_STANDARDS.md, the lint configuration | none |
| test, e2e, check | `bash scripts/hm.sh test / e2e / check` | the repository's commands | none: say which checks did not run |
| Formatting before a commit | the pre-commit hook (`bash scripts/hm.sh fmt`) | the repository's format command or hook | none: match the surrounding style |
| Scratch files (reviews, debug, PR bodies) | artifacts/ | — | the OS temp directory, unless git ignores artifacts/ (`git check-ignore -q artifacts/x`) |

## Start ("개발해: <request or file>", or "Start Task <id>." with no .harness/config)
1. The task: docs/tasks/<id>.md if it exists (written earlier, e.g. by hm-change without the harness), else a new one. For a new one, read `templates/task.template.md` in the hm-setup skill folder and write docs/tasks/<id>.md from it: the next free number in docs/tasks/ (from 1), `- Status: In Progress`, `- Type:` from the request, `- Review: each`, `- Depends on: none`, `- Requirements: none` (or the IDs of a requirements doc I named), `- Source:` my message or the file. Acceptance criteria as Given/When/Then with concrete values, with IDs `T<id>/AC-<n>` (feature and bug), or "Done when" bullets; a demo scenario for feature and bug.
2. If the request leaves a value or a behavior open, ask in one round before writing the criteria, and never guess. Show me the criteria in a few lines and go on unless I correct them.
3. The tree is clean. Base: INTEGRATION (no-harness.md defaults); if the current branch is another one with commits not on INTEGRATION, ask which base.
4. `git switch -c task/<id> <base>` (or `git switch task/<id>` for an existing empty branch), then commit the task file: `chore(task-<id>): start`.

Then run the Task workflow (its step 1 is done) with the rules in SKILL.md. Decisions during development (DQ) stay in the task file; nothing moves them to REQUIRE.md.

## End
The report's "Next" line: "이 브랜치 리뷰해" (hm-review) in a separate session, or "Merge branch task/<id>." once I am satisfied.
