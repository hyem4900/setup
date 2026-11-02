# Inputs without the harness (part of hm-load-test)

Read this with references/no-harness.md when `.harness/config` does not exist. Find each input in this order, and name in LOAD_TEST.md the file that served (e.g. `Targets: docs/prd.md §5 (stand-in for SPEC §10)`): a file I name → the harness file → a file in the repository that plays the same role (ask once if several fit) → the fallback.

| Input | Harness file | Stand-ins to look for | Fallback |
|---|---|---|---|
| Targets | SPEC §10a and §10b (from the REQUIRE NFRs) | numbers in a requirements doc, a performance section in the README or design docs | ask me, in one round: per endpoint or command, the p95; for a service, also the concurrent users and the error rate |
| Load and benchmark tools | SPEC §1 | a load or benchmark setup already in the repository | recommend one (precondition in SKILL.md) |
| Production-like start | `bash scripts/hm.sh load` (each component's `<c>_PROD` command on PORT_OFFSET + 100) | the repository's production start command (a start script, a container file) | ask me; write it into LOAD_TEST.md Conditions |
| Levels and duration | LOAD_LEVELS, LOAD_DURATION | — | 10 users, the target, twice the target; 2 minutes each |
| Scenarios | the demo scenarios in docs/tasks/ | the README's usage, API docs, E2E tests | the main user flows, which I confirm |
| test, e2e, check | `bash scripts/hm.sh test / e2e / check` | the repository's commands | none: say which did not run |
