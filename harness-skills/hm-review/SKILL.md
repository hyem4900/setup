---
name: hm-review
description: Step 5-1 of the harness flow. Use in a separate session for "Review Task <id>.", "Re-review Task <id>.", "Review all.", "Re-review all.", "Review range A..B." or "이 브랜치 리뷰해" / "Review this branch." (with or without the harness). Read-only review on two axes (Spec: built what was asked; Standards: built the project's way) at the exact commit under review; also for a teammate's pushed branch.
---

# Harness Step 5-1: Review

You did not write this code. Review it as an outsider. Talk to me in CHAT_LANG; write the review in DOC_LANG, keeping its fixed lines and tokens in English. Ask questions in the question format of AGENTS.md ("Ask the user when"): ❓ question with a bold topic, then ➡️ your recommendation.
Other skills: use another skill only when my message names it or a step of this skill names it. An installed skill whose description seems to fit the work (a design system, charts, documents) stays unused, unless SPEC or DECISIONS records that I chose it.
Files I name: a file named in my message is the first source for the role I give it, and harness files only fill what it lacks. If they disagree, show the difference and ask which one wins. If it is missing or does not fit that role, say so in one line and go on without it. Read it; edit it only if I ask.

## Inputs
Find each input in this order, and name in the review the file that served (e.g. `Spec source: README.md (stand-in for REQUIRE.md)`): a file I name → the harness file → a file in the repository that plays the same role (ask once if several fit) → the fallback.
Without the harness (no .harness/config): follow references/no-harness.md in this skill's folder (what not to create, the defaults for languages, branch, commands and scratch files, and the question format). With the harness, AGENTS.md covers this and you read it first.

| Input | Harness file | Stand-ins to look for | Fallback |
|---|---|---|---|
| Review guide (scope, checklist, severity, output format) | docs/REVIEW.md | — | `templates/REVIEW.template.md` in the hm-setup skill folder (`../hm-setup/` from this skill's folder). Read it there; never copy it into the repository |
| Standards | docs/STANDARDS.md (older projects: AGENTS.md "Security" and "Backend baseline") | CONTRIBUTING.md, CODING_STANDARDS.md, a style guide, the lint configuration | `templates/STANDARDS.template.md` in the hm-setup skill folder |
| Spec | the task file, its R-xx in REQUIRE.md, the SPEC sections it touches | the pull request description, the issue the commits reference, a design doc | none: skip the Spec axis, write `Spec: skipped (no spec found)` in the review, and the AC coverage table becomes N/A |
| Demo scenario | the task file's Demo scenario | numbered steps in the spec stand-in | none: `skipped: no demo scenario` |
| test, e2e and check | `bash scripts/hm.sh test / e2e / check` | the repository's commands | none: write `not run (no command found)` on that line |
| Where the review file goes | `<main worktree>/artifacts/review/` | — | without the harness: the same folder if git ignores artifacts/ (`git check-ignore -q artifacts/x`), else the OS temp directory; print the path |

## Preconditions
- "Review Task <id>.": task/<id> exists (locally, or as `<REMOTE>/task/<id>` for a teammate's task after `git fetch`) and its task file on that branch says In Review.
- "Re-review Task <id>.": task/<id> has a docs/reviews/task-<id>-review-*.md committed.
- "Review all.": the integration head exists (MERGE=pr: `git fetch` first and use `<REMOTE>/<INTEGRATION>`).
- "Re-review all.": the latest review-all-<k>.md has a Blocker and is applied on the unmerged branch fix/review-all-<k>.
- "Review range A..B.": both ends resolve (`git rev-parse`).
- "이 브랜치 리뷰해" / "Review this branch." (or a branch I name): the range is `<merge-base of the branch and INTEGRATION>..<branch head>`, and the diff is not empty. The review file is named `review-<branch, with / as ->-<k>.md`.

If a precondition fails, tell me in CHAT_LANG and stop.

## Where to run
Follow the review guide's "Where to run". In short: run the tests on the commit you review, never on a worktree where someone else is working.
- If the prompt gives a task worktree, use it when it is clean and at the head of task/<id>.
- Otherwise create a temporary detached worktree (the guide tells how, including its PORT_OFFSET; without the harness: `git worktree add --detach <OS temp dir>/review-<slug> <sha>`), and remove it with `git worktree remove` at the end. The current worktree is fine instead when it is clean and already at that sha. Adding and removing a detached worktree changes no branch and no file of the project.

## Rules
- Read-only. The only files you may write are the review output (named as in the review guide; never overwrite an earlier review) and the screenshots of the Demo walkthrough next to it.
- Demo walkthrough (HAS_UI=1, or a product with screens): if you can drive the UI the way a user does (for a web app, a browser you can control), follow the Demo scenario and try the inputs around it. Reuse components that are already healthy and stop only the ones you started. Without such a tool, skip it and say so in the review. Older REVIEW.md files without this section: do it anyway, as described here.
- Do not run `git commit`, `git tag`, `git merge`, `git checkout`/`git switch` in an existing worktree, `git stash`, or anything else that changes a tree someone works in.
- Run test, e2e and check yourself (Inputs). Report the real numbers.
- Read .harness/config if it exists, and skip checklist items that do not apply, saying which and why.
- If a finding is a guess, mark it "Needs verification" and say what would confirm it. Do not inflate severity.

## Steps
1. Follow the review guide for scope, checklist, severity, and output format. Write down the full sha you review for the `Commit:` line (`git rev-parse task/<id>`; review all: the integration head; re-review all: the head of fix/review-all-<k>; a branch or range: its head), the diff command and the commit list (`git log --oneline` over the same range).
2. Run `test`, `e2e` and `check`, and do the Demo walkthrough, yourself: they need this worktree's ports.
3. Review the two axes of the checklist apart, so neither colours the other:
   - If the diff is large (more than about 300 changed lines, from `git diff --shortstat`) and you can start sub-agents: start two fresh ones in parallel, read-only, one per axis. Give each the sha, the diff command, the commit list, its axis's sources and checklist items from the review guide, the severity table, and the Findings row format, and ask for its rows only, in under about 400 words. The Spec agent also fills the AC coverage table.
   - Otherwise (a smaller diff, or no sub-agents): two passes yourself, Spec first, then Standards; finish one axis before you read the other's sources. Starting sub-agents costs more than they save on a small diff.
   On the Spec axis, fill the AC coverage table first, using full AC IDs (R-xx/AC-n), or the spec stand-in's numbered criteria. Every AC must have an implementation location and a test, or it is a Blocker. Read the task file's Log for decisions the user made during development.
4. Number the findings RV-1, RV-2, ... across both axes, keep each in its axis's table, and fill the `Axes:` line. Never merge or rerank findings across axes.
5. Write the review file and print the same content.

## End
Add two lines in CHAT_LANG after the review:
- Verdict and counts per severity
- Next step: in the development session, apply this review with the review file path (e.g. "리뷰 반영해: <path>" / "apply review: <path>"). With a task, run it even with zero findings: Done and the merge happen only in that step.

Then stop.
