# Inputs without the harness (part of hm-audit)

Read this with references/no-harness.md when `.harness/config` does not exist. Find each input in this order, and name in TRACEABILITY.md the file that served (e.g. `Requirements: docs/prd.md (stand-in for REQUIRE.md)`): a file I name ("누락 검토해: <file>") → the harness file → a file in the repository that plays the same role (ask once if several fit) → the fallback.

| Input | Harness file | Stand-ins to look for | Fallback |
|---|---|---|---|
| Requirements | docs/REQUIRE.md (R-xx, AC, DR, NFR, SEC) | a PRD, a spec, the README's feature list | none: stop and ask me which document holds the requirements |
| Tasks | docs/tasks/ | — | none: leave the Task column out |
| Design (contracts, seams, compatibility) | docs/SPEC.md, REQUIRE §5 | design docs, API descriptions | skip steps 4–5 and say so |
| test, e2e, check | `bash scripts/hm.sh test / e2e / check` | the repository's commands | none: say which did not run; coverage then rests on reading the tests |
| Task states | `bash scripts/harness-state.sh status` | — | the task files and the task/<id> branches |
| Coverage lines | the top of docs/QUESTION.md | — | none: write `coverage not recorded` and skip that check |

With a stand-in for REQUIRE.md, number its statements yourself (`S-1`, `S-2`, ... in document order, quoting each in a few words) and use those IDs in steps 2–3; steps 2 and 3 become one pass over the document. Without the tag harness-init, step 6 does not apply and steps 7–8 look at the last 100 commits instead.
