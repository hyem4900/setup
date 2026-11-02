# Review Guide

## Rules
- Read-only. Do not modify source, tests, or docs, except writing the review file (and the screenshots of the Demo walkthrough).
- Run `bash scripts/hm.sh test`, `bash scripts/hm.sh e2e`, and `bash scripts/hm.sh check` yourself, at the commit you review, and report the results. Do not trust the task file.
- You may run the product to use it as a user would (Demo walkthrough). Stop what you started before you finish.
- Read .harness/config first; skip checklist items that do not apply and say so.
- Never run `git commit`, `git tag`, `git merge`, `git checkout`/`git switch` in an existing worktree, `git stash`, or anything else that changes a tree someone works in.

## Where to run
- Review Task <id>: the task's worktree if it exists, is clean, and is at the head of task/<id>. Otherwise a temporary detached worktree: `git worktree add --detach <WORKTREE_DIR>/review-<id> task/<id>` (a teammate's task: `<REMOTE>/task/<id>`), with `PORT_OFFSET` from `bash scripts/harness-state.sh worktree review-<id>` in its `.harness/local`, then `bash scripts/hm.sh setup`. Remove it with `git worktree remove` at the end. Never switch branches in a worktree someone works in.
- Review all: the main worktree if it is clean and at the integration head (MERGE=pr: `<REMOTE>/<INTEGRATION>` after `git fetch`); otherwise a temporary detached worktree at that head.

## Scope
INT below means INTEGRATION (MERGE=pr: `<REMOTE>/<INTEGRATION>`).
| Request | Diff | Also read |
|---|---|---|
| Review Task <id>. | `git diff INT...task/<id>` (three dots: only the task's own changes) | the task file, its R-xx in REQUIRE.md, SPEC sections it touches |
| Re-review Task <id>. | `git log -p --first-parent --no-merges <C>..task/<id>`, C = `Commit:` of the latest docs/reviews/task-<id>-review-*.md on the branch | that review |
| Review all. | `git diff <C>..INT`, C = `Commit:` of the latest applied docs/reviews/review-all-*.md, else the tag harness-init | REQUIRE.md, SPEC.md, the task files of tasks merged in that range |
| Re-review all. | `git diff <C>..fix/review-all-<k>`: k from the latest review-all-<k>.md (applied on the unmerged branch fix/review-all-<k>, with a Blocker), C its `Commit:`. Your `Commit:` line is the head of fix/review-all-<k> | that review |
| Review range <A>..<B>. | `git diff <A>..<B>` | what the range touches |

Leave generated files and lockfiles out of the diff you read (`-- . ':!<lockfile>'`), but check that lockfile changes match the dependency changes.

## Checklist
Two axes, kept apart so one cannot hide the other: code can follow every standard and build the wrong thing, or build the right thing against the standards. Report each axis on its own; never merge or rerank findings across them.

### Spec axis: did it build what was asked?
Sources: the task file (its Decisions during development included), its R-xx in REQUIRE.md, the SPEC sections it touches.
1. Goal of the task, by its `- Type:`. feature: each Given/When/Then in REQUIRE.md for the task's R-xx is implemented and tested. bug: a regression test reproduces the reported behavior and the fix makes it pass. chore: no behavior change; existing test assertions untouched. spike: Findings answer the question with evidence; no production code. docs: the docs match the code.
2. Interface contract: matches SPEC §4 exactly (paths/commands, params, output shape, error codes and format), including contracts between components (§4c)
3. Data model: matches SPEC §3; migrations are new files (merged ones untouched), named per SPEC §3, and none drops or narrows data without a recorded decision; the writes SPEC §3 lists as repeated or concurrent have their guard and a test
4. Domain rules and core logic: each core computation follows SPEC §6 (model, algorithm and its changes, result rules, tie-breaking) and is tested with its listed cases; each domain rule is implemented in one place (no copies), unit tested with edge cases at the SPEC §7 seam; names follow the REQUIRE §9 Glossary
5. Data handling (if DATA_SOURCES): rules from REQUIRE §4 applied as specified
6. Compatibility (if GREENFIELD=0): characterization tests exist for touched code and still pass; REQUIRE §5 holds
7. Decisions: every behavior a user or another component can notice is decided by an AC, a DR-xx, or a DQ the user answered in the task file's Decisions during development, and each DQ has a test. Observable behavior the agent chose without asking (an edge case, a tie-break, a rounding rule, a choice of algorithm that changes results) is Major: list the question to ask in the finding
8. Scope: behavior or options nobody asked for (scope creep), and edits outside the task's scope
9. Demo walkthrough (HAS_UI=1; feature and bug tasks): done as below, or skipped with the reason

### Standards axis: is it built the way this project builds things?
Sources: docs/STANDARDS.md (Project rules first, then the baselines, then the smell baseline) and the AGENTS.md Forbidden list. An older project without docs/STANDARDS.md: the "Security" and "Backend baseline" sections of AGENTS.md, plus the smell baseline in the hm-setup skill's templates/STANDARDS.template.md.
10. Tests: cover failure paths and empty states, assert behavior through the public interface (not implementation details, not a value recomputed the way the code computes it), no skipped tests; (HAS_UI=1) selectors follow the selector policy in SPEC §5
11. Error handling: invalid input, not-found, empty data, a dependent component being down (with a timeout on the call); no swallowed exceptions; errors logged with the request ID; correct status codes (4xx vs 5xx, no 200 with an error, no state change on GET); no stack traces or internals leaked to the user
12. Security: the SPEC §12 controls for what the change touches and the Security baseline: password and credential storage (slow salted hash; no plain or fast hash anywhere, logs included), access checks per object, input validation, injection (SQL, shell, path, template), XSS and CSRF where they apply, secrets in code or logs; each SEC-xx in the task has a test that proves it
13. Data and resources (Backend baseline): schema constraints, `created_at` / `updated_at`, indexes on filter, join or sort columns; multi-step writes in one transaction; N+1 queries, unbounded reads, work repeated per request or per call, chatty calls between components; connections, files or streams not released; money in floating point, times not in UTC
14. AGENTS.md forbidden actions: PROTECTED untouched, no unlisted dependencies, no hook bypass
15. Project rules and smells: each Project rule in docs/STANDARDS.md; the smell baseline as judgement calls (name the smell, quote the hunk, Minor at most). Skip what LINT_CMD already enforces.

## Demo walkthrough
Only when HAS_UI=1, the task is a feature or a bug with a Demo scenario, and you have a tool that drives the UI the way a user does (for a web app, a browser you can control). Without such a tool, write `skipped: no UI tool` and go on; never install one for the review.
1. Run the product on the commit you review, on this worktree's ports (`bash scripts/hm.sh help`). If `bash scripts/hm.sh health` shows every component healthy (the demo the developer left running), use it and leave it running. Otherwise run `bash scripts/hm.sh dev-bg`, and `bash scripts/hm.sh stop` when you finish (before removing a temporary worktree).
2. Follow the task's Demo scenario step by step and compare each result with the expected one.
3. Try the inputs around it, a few on each screen the task touches: empty and very long values, invalid formats, the same action twice in a row, back and reload in the middle of a flow, a narrow (mobile) window. Check the empty, loading and error states SPEC §5 names.
4. Create your own data with unique names; never change or delete data you did not create.
5. Each difference is a finding with the steps, the input and what you saw, rated by the severity table (an unmet AC or a crash is a Blocker). Screenshots that back a finding go to a folder next to the review file, named like it without `.md`.

Review all: the scenarios of the feature and bug tasks merged in the range, on the integration head. Re-review: only the steps the fixes touch, if any.

## Severity
| Level | Meaning | Handling |
|---|---|---|
| Blocker | AC not met, contract broken, failing test, security hole, data corruption, broken existing behavior | Must fix. Re-review required. |
| Major | Missing test for an AC, wrong edge case, error handling gap, observable behavior decided without asking, a broken Project rule | Must fix (for an unasked decision: ask the user, then apply the answer). No re-review. |
| Minor | Readability, small duplication, naming, a code smell | Fix if cheap, otherwise log in the task's Issues found. |
| Nit | Style preference | Optional. |

## Output
Write to `<main worktree>/artifacts/review/task-<id>-review-<k>.md` (or `review-all-<k>.md`), where k is the next unused number across that folder and docs/reviews/, and print the same content. The main worktree is the parent of `git rev-parse --path-format=absolute --git-common-dir`.
The reviewer never commits. The apply-review step (hm-dev) copies the file to docs/reviews/ and commits it, so the history survives clones.

```
# Review: Task <id>
Verdict: APPROVE | CHANGES REQUESTED
Commit: <full sha of the head you reviewed>
test: N passed / N failed
e2e: N passed / N failed
check: pass / fail
Axes: spec N findings (worst: <severity or none>), standards N findings (worst: <severity or none>)

## Findings
### Spec
| ID | Severity | File:line | Problem | Suggested fix | Ref (R-xx / SPEC §) |
| RV-1 | Blocker | ... | ... | ... | ... |

### Standards
| ID | Severity | File:line | Problem | Suggested fix | Ref (STANDARDS § / rule / smell) |

## AC coverage
| AC (R-xx/AC-n) | Implemented | Tested by |

## Demo walkthrough
skipped: <reason>   (or the table and the line below)
| Step | Expected | Observed | OK |
Extra inputs tried: <list>
```
Verdict is CHANGES REQUESTED if there is any Blocker or Major.

Fixed format, because scripts parse it:
- The `Verdict:` line is exactly `Verdict: APPROVE` or `Verdict: CHANGES REQUESTED`, at the start of a line.
- The `Commit:` line holds the full sha of task/<id> (or the integration head for review all) that you reviewed.
- One Findings row per finding, in the table of its axis. ID is `RV-<n>`, numbered across both tables. Severity is exactly one of `Blocker`, `Major`, `Minor`, `Nit` (put "Needs verification" in Problem, not in Severity).
- No findings on an axis: keep its header row and write no rows.
