# Inputs without the harness (part of hm-review)

Read this with references/no-harness.md when `.harness/config` does not exist. Find each input in this order, and name in the review the file that served (e.g. `Spec source: README.md (stand-in for REQUIRE.md)`): a file I name → the harness file → a file in the repository that plays the same role (ask once if several fit) → the fallback.

| Input | Harness file | Stand-ins to look for | Fallback |
|---|---|---|---|
| Review guide (scope, checklist, severity, output format) | docs/REVIEW.md | — | `templates/REVIEW.template.md` in the hm-setup skill folder (`../hm-setup/` from this skill's folder). Read it there; never copy it into the repository |
| Standards | docs/STANDARDS.md (older projects: AGENTS.md "Security" and "Backend baseline") | CONTRIBUTING.md, CODING_STANDARDS.md, a style guide, the lint configuration | `templates/STANDARDS.template.md` in the hm-setup skill folder |
| Spec | the task file, its R-xx in REQUIRE.md, the SPEC sections it touches | the pull request description, the issue the commits reference, a design doc | none: skip the Spec axis, write `Spec: skipped (no spec found)` in the review, and the AC coverage table becomes N/A |
| Demo scenario | the task file's Demo scenario | numbered steps in the spec stand-in | none: `skipped: no demo scenario` |
| test, e2e and check | `bash scripts/hm.sh test / e2e / check` | the repository's commands | none: write `not run (no command found)` on that line |
| Where the review file goes | `<main worktree>/artifacts/review/` | — | without the harness: the same folder if git ignores artifacts/ (`git check-ignore -q artifacts/x`), else the OS temp directory; print the path |
| Where to run | the task worktree, or a detached worktree under WORKTREE_DIR (review guide "Where to run") | — | `git worktree add --detach <OS temp dir>/review-<slug> <sha>`, removed at the end; or the current worktree when it is clean and at that sha |
