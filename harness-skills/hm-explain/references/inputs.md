# Inputs without the harness (part of hm-explain)

Read this with references/no-harness.md when `.harness/config` does not exist. Find each input in this order, and name in the header of docs/EXPLAIN.md the file that served (e.g. `Sources: docs/prd.md (stand-in for REQUIRE.md)`): a file I name ("설명 문서 만들어: <file>") → the harness file → a file in the repository that plays the same role (ask once if several fit) → the fallback.

| Input | Harness file | Stand-ins to look for | Fallback |
|---|---|---|---|
| Requirements | docs/REQUIRE.md | a PRD, a spec, the README's feature list | the README and the code's own entry points; cite features by name instead of R-xx |
| Decisions and their reasons | docs/DECISIONS.md, the `✅ 결정` lines of docs/QUESTION.md, task DQ lines | ADRs, design docs, pull request descriptions, commit messages | `no recorded reason` for every why, as in Rules |
| Design | docs/SPEC.md | architecture docs, API descriptions, schema files | the code alone; section 9 then has no differences from the design |
| Task states | `bash scripts/harness-state.sh status` | — | the default branch's history; skip the open-task question |
| Quality evidence | TRACEABILITY.md, LOAD_TEST.md, docs/security/, final-check.md | CI results, test reports | the test run of step 1 only |

Without the harness, the main worktree's default branch (`origin/HEAD`, else `main` or `master`) stands in for INTEGRATION, and the commit in step 5 does not happen.
