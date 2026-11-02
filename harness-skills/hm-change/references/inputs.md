# Inputs without the harness (part of hm-change)

Read this with references/no-harness.md when `.harness/config` does not exist. Find each input in this order, and name in the CR file the file that served (e.g. `Requirements: docs/prd.md (stand-in for REQUIRE.md)`): a file I name → the harness file → a file in the repository that plays the same role (ask once if several fit) → the fallback.

| Input | Harness file | Stand-ins to look for | Fallback |
|---|---|---|---|
| Requirements | docs/REQUIRE.md | a PRD, a spec, the README's feature list, issues | none: the request itself |
| Design and contracts | docs/SPEC.md, docs/DECISIONS.md | design docs, API descriptions, ADRs | the code |
| Task template | docs/tasks/_template.md | — | `templates/task.template.md` in the hm-setup skill folder (`../hm-setup/` from this skill's folder); read it there |
| Task states | `bash scripts/harness-state.sh status` | — | the task files in docs/tasks/ and the task/<id> branches |

Without the harness, this skill writes only the CR file and task files: it reads the stand-ins for the impact analysis but never edits them, skips the REQUIRE, SPEC and DECISIONS updates in step 4, and lists in the CR's Impact table what those docs would need. Tasks it writes start with "개발해: docs/tasks/<id>.md" or "Start Task <id>." (hm-dev).
