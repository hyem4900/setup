# Task <id>: <title>
- Status: Todo
- Type: feature
- Review: each
- Core: no
- Depends on: none
- Requirements: R-xx, R-yy (DR-xx, NFR-xx, SEC-xx); `none` for a chore, spike or docs task that serves no requirement
- Source: initial plan

## Scope
Interface entries, screens, modules, components (with SPEC section refs).

## Existing code touched
(GREENFIELD=0) files/modules and the characterization tests that protect them

## Acceptance criteria
feature and bug: copy the Given/When/Then from REQUIRE.md with their full IDs (R-01/AC-1), adjusted only to add concrete values. A bug without an R-xx states the wrong and the expected behavior as Given/When/Then.
chore, spike, docs: "Done when" bullets instead (e.g. "all tests pass on the new major version", "Findings recommend one option").

## Demo scenario
(feature and bug) Numbered steps a human follows (screen, request, or shell), with expected results. A bug's scenario reproduces the original report.

## Findings
(spike) The question, the answer, the evidence, a recommendation, and follow-up tasks to propose through hm-change.

## Diagnosis
(bug, when the debug procedure is used) Symptom, loop command, minimal repro, ranked hypotheses with results, root cause, regression test.

## Tests
| Test | Type (unit/e2e/characterization/security/load/bench) | Covers AC (R-xx/AC-n) or SEC-xx | File |

## DoD additions
(e.g. first load test)

## Decisions during development
Behavior and approach questions the ACs did not decide, asked and answered while developing (hm-dev moves them into REQUIRE.md or DECISIONS.md at integration):
- DQ-1 (behavior, R-xx): <question> → <answer> → <resulting behavior, with concrete values>; test: <test name>
- DQ-2 (approach): <question> → <answer> → <what was chosen and why>
- Internal: <choice>, because <reason> (no observable difference; not asked)

## Issues found
| ID | Description | Severity | Status |

## Log
- YYYY-MM-DD HH:MM what happened (test counts, load numbers, decisions, user answers)

## Notes for Next Session
(Overwritten by each session of this task: what the next session must know)
