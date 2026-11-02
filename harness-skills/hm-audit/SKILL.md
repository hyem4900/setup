---
name: hm-audit
description: Step 6-2 of the harness flow. Use for "누락 검토해" (or "누락 검토해: <requirements doc>", also without the harness) or a traceability check. Maps every requirement and accepted change request to tasks and tests on the integration branch, finds gaps and source violations, lists deepening candidates in the most-changed code and runs a retro on recurring findings; reports before fixing. Any time, also mid-project.
---

# Harness Step 6-2: Traceability audit

Talk to me in CHAT_LANG and write documents in DOC_LANG (both in .harness/config; Korean and English if unset). Code, identifiers and the fixed tokens scripts parse stay in English. Ask questions in the question format of AGENTS.md ("Ask the user when"): ❓ question with a bold topic, then ➡️ your recommendation.

## Inputs
With the harness: AGENTS.md first, then docs/REQUIRE.md (R-xx, AC, DR, NFR, SEC), docs/tasks/, docs/SPEC.md and REQUIRE §5 for contracts, seams and compatibility, `bash scripts/hm.sh test / e2e / check`, `bash scripts/harness-state.sh status`.
Without the harness (no .harness/config): read references/no-harness.md and references/inputs.md in this skill's folder first; the latter says what stands in for each of those and how the steps change.

## Preconditions
- Audit what is merged: run in the main worktree on INTEGRATION (MERGE=pr: a temporary detached worktree at `<REMOTE>/<INTEGRATION>` after `git fetch`). Tasks not merged yet count as not implemented; list them as in flight.
- Read-only until I approve fixes. The only file you may write before approval is docs/TRACEABILITY.md.

## Steps
1. Run `bash scripts/hm.sh test`, `bash scripts/hm.sh e2e`, and `bash scripts/hm.sh check`. Collect the actual test names that ran and passed. Run `bash scripts/harness-state.sh status` for task states across branches.
2. For every R-xx, AC (by full ID R-xx/AC-n), DR-xx, NFR-xx and SEC-xx in REQUIRE.md, find (a Should or Could whose acceptance criteria still say `when tasked` has no task yet: its Status is Missing, and its gap severity follows its priority):
   - the task file(s) in docs/tasks/ and their status (Dropped tasks do not count)
   - the implementation location (component, module, interface entry, screen)
   - the tests that cover it, confirmed by reading the test code, not only by name
   - whether those tests passed in step 1
   - for NFRs: where it was measured (LOAD_TEST.md load or benchmark results, a test, or nowhere). A latency target with no measurement is Untested.
   - for SEC-xx: the security test that proves it, or the latest docs/security/review-<k>.md that checked it. A SEC-xx with neither is Untested. If docs/security/ is empty, or the latest review is older than the last merged task that touched sign-in, credentials, access checks or input handling, list "run hm-security" under Gaps. Findings in the latest review that are still Open without a task are Gaps too.
3. Check the original sources against the implementation:
   - Each file in REQ_SOURCES, statement by statement
   - Each decision in REQUIRE §11 Questions (older projects: the DISCOVERY.md Interview Log)
   - Each Accepted change request in docs/changes/: its requirement changes are in REQUIRE.md and its tasks are Done
   - Any statement that is not implemented and not in REQUIRE Out of scope is a violation.
4. (GREENFIELD=0) Check REQUIRE §5 compatibility constraints: each has a characterization or E2E test that passes.
5. (more than one component) Each SPEC §4c contract has a test on both sides that passes.
   Also check development decisions: every DQ line in a merged task file points to an AC in REQUIRE.md or a D-xx in DECISIONS.md (`→ R-xx/AC-n` or `→ D-xx`) that says the same, and its test passes. A DQ that was never moved is a Gap.
   Also check the non-feature tasks: each Done bug task has its regression test, still passing; each Done spike task has Findings, and its recommendation was either turned into a change request or explicitly declined; chore and docs tasks need no requirement mapping.
6. Confirm PROTECTED paths are unchanged: `git diff --stat harness-init..HEAD -- <each PROTECTED path>` and `git status --porcelain -- <each PROTECTED path>` are both empty.
7. Deepening candidates. Find the hot spots first: the files changed most often since harness-init (`git log --name-only --format= harness-init..HEAD`, counted per file), leaving out Markdown, lockfiles and generated files. Read those, looking for friction:
   - a **shallow** module: its interface is nearly as complex as what it hides
   - one concept spread over many small modules, or copied between components
   - logic that is hard to test through its SPEC §7 seam, or tested only through mocks of its own internals
   Apply the **deletion test** to each suspect: would deleting it concentrate complexity in one place (a real module worth keeping) or only move it around (shallow, a candidate to merge into something deeper)? Keep at most 5 candidates, each with the files, the problem, the change in plain words, what it makes easier (tests, the next tasks), and a strength: Strong, Worth exploring, or Speculative. Use the REQUIRE §9 Glossary terms. Propose no interfaces yet, and drop a candidate that contradicts a D-xx unless the friction is worth reopening it (say so).
8. Retro. From docs/reviews/, the task files' Logs and Issues found, collect what came back more than once (the same kind of finding, a failure that cost a re-review or a MAX_CONTINUE, information agents kept hunting for), most severe first. For each, name the cheapest fix to the agents' environment:
   - mechanical (a fixed pattern a linter or grep could catch) → a check: a LINT_CMD rule or a guardrail pattern in .harness/config
   - judgement → a line in docs/STANDARDS.md "Project rules", if it is not there yet
   - hunting for information → a navigation pointer (AGENTS.md reading order, the codebase notes) or a harness command that shows it (a log, a fixture)
9. Write docs/TRACEABILITY.md:

~~~markdown
# Traceability

## Summary
Audited commit <sha>. Musts covered N/N, Shoulds N/N, Coulds N/N, ACs tested N/N, NFRs measured N/N, compatibility constraints tested N/N, component contracts tested N/N, change requests done N/N

## Matrix
| ID | Priority | Task | Implementation | Tests | Passing | Status (OK / Untested / Missing / Partial / In flight) |

## Gaps
| # | ID | Problem | Severity (Blocker for Must, Major for Should, Minor for Could) | Proposed fix |

## Source violations
| Source (file §, Q-xx, or CR-xx) | Problem | Proposed fix |

## Issues still open
(from every task file's "Issues found")

## Deepening candidates
| # | Files | Problem | Change | Makes easier | Strength |

## Retro
| # | What came back | Times | Fix (check / project rule / pointer / command) |
~~~

10. Commit docs/TRACEABILITY.md: `docs: traceability audit` (MERGE=pr: on a branch `docs/audit-<date>`, pushed for a pull request). Without the harness: leave it uncommitted and tell me where it is.

## End
Report the summary and the gap list in CHAT_LANG, sorted by severity, then the top deepening candidate and the retro items in one line each. Ask which gaps, candidates and retro items to act on, as one round of questions. Do not fix anything until I answer.
Approved items go through hm-change, which creates the tasks: gaps as one change request of kind `bug` or `feature`, deepening candidates and checks as `chore` (prefactor or expand–contract when they are wide), project rules and pointers as `docs`. Then they run through the normal flow. Without the harness, hm-change writes only the change record and task files, and "개발해: docs/tasks/<id>.md" (hm-dev) builds each one. Re-run this audit afterwards.
