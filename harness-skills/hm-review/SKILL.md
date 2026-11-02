---
name: hm-review
description: 'Step 5-1 of the harness flow. Use in a separate session for "Review Task <id>.", "Re-review Task <id>.", "Review all.", "Re-review all.", "Review range A..B." or "이 브랜치 리뷰해" / "Review this branch." (with or without the harness). Read-only review on two axes (Spec: built what was asked; Standards: built the project''s way) at the exact commit under review; also for a teammate''s pushed branch.'
argument-hint: '"Review Task <id>." | "Re-review Task <id>." | "Review all." | "이 브랜치 리뷰해"'
---

# Harness Step 5-1: Review

You did not write this code. Review it as an outsider. Talk to me in CHAT_LANG; write the review in DOC_LANG, keeping its fixed lines and tokens in English. Ask questions in the question format of AGENTS.md ("Ask the user when"): ❓ question with a bold topic, then ➡️ your recommendation.

## Inputs
With the harness: AGENTS.md first, then docs/REVIEW.md (scope, checklist, severity, output format), docs/STANDARDS.md, the task file with its R-xx in REQUIRE.md and the SPEC sections it touches, the task's Demo scenario, `bash scripts/hm.sh test / e2e / check`; the review file goes to `<main worktree>/artifacts/review/`.
Without the harness (no .harness/config): read references/no-harness.md and references/inputs.md in this skill's folder first; the latter says what stands in for each of those and what to do when nothing does.

## Preconditions
- "Review Task <id>.": task/<id> exists (locally, or as `<REMOTE>/task/<id>` for a teammate's task after `git fetch`) and its task file on that branch says In Review.
- "Re-review Task <id>.": task/<id> has a docs/reviews/task-<id>-review-*.md committed.
- "Review all.": the integration head exists (MERGE=pr: `git fetch` first and use `<REMOTE>/<INTEGRATION>`).
- "Re-review all.": the latest review-all-<k>.md has a Blocker and is applied on the unmerged branch fix/review-all-<k>.
- "Review range A..B.": both ends resolve (`git rev-parse`).
- "이 브랜치 리뷰해" / "Review this branch." (or a branch I name): the range is `<merge-base of the branch and INTEGRATION>..<branch head>`, and the diff is not empty. The review file is named `review-<branch, with / as ->-<k>.md`.

If a precondition fails, tell me in CHAT_LANG and stop.

## Rules
The review guide (docs/REVIEW.md) is the standard: its Rules, Where to run, Scope, Checklist, Demo walkthrough, Severity and Output apply as written. This file adds only how the session runs.
- Where to run: the task worktree given in the prompt when it is clean and at the head of task/<id>; otherwise the temporary detached worktree the guide describes, removed with `git worktree remove` at the end. The current worktree is fine when it is clean and already at that sha.
- Older REVIEW.md files without a Demo walkthrough section: do it as the current template describes (`templates/REVIEW.template.md` in the hm-setup skill folder).
- If a finding is a guess, mark it "Needs verification" and say what would confirm it. Do not inflate severity.

## Steps
1. Write down the full sha you review for the `Commit:` line (`git rev-parse task/<id>`; review all: the integration head; re-review all: the head of fix/review-all-<k>; a branch or range: its head), the diff command from the guide's Scope table and the commit list (`git log --oneline` over the same range).
2. Run `test`, `e2e` and `check`, and do the Demo walkthrough, yourself: they need this worktree's ports.
3. The two axes of the checklist, apart:
   - If the diff is large (more than about 300 changed lines, from `git diff --shortstat`) and you can start sub-agents: start two fresh ones in parallel, read-only, one per axis. Give each the sha, the diff command, the commit list, its axis's sources and checklist items from the review guide, the severity table, and the Findings row format, and ask for its rows only, in under about 400 words. The Spec agent also fills the AC coverage table.
   - Otherwise (a smaller diff, or no sub-agents): two passes yourself, Spec first, then Standards; finish one axis before you read the other's sources. Starting sub-agents costs more than they save on a small diff.
   On the Spec axis, fill the AC coverage table first, using full AC IDs (R-xx/AC-n), or the spec stand-in's numbered criteria. Every AC must have an implementation location and a test, or it is a Blocker. Read the task file's Log for decisions the user made during development.
4. Write the review file in the guide's Output format and print the same content.

## End
Add two lines in CHAT_LANG after the review:
- Verdict and counts per severity
- Next step: in the development session, apply this review with the review file path (e.g. "리뷰 반영해: <path>" / "apply review: <path>"). With a task, run it even with zero findings: Done and the merge happen only in that step.

Then stop.
