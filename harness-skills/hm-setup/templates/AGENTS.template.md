# AGENTS

Project profile: see .harness/config (MODE, SESSION_PER_TASK, PROTECTED, HAS_SERVER, HAS_UI, HAS_LOAD, GREENFIELD, INTEGRATION, MERGE, PARALLEL, WORKTREES).

## Reading order
1. AGENTS.md (this file) and .harness/config
2. Your task file docs/tasks/<id>.md (status, scope, Log, Notes for Next Session)
3. docs/SPEC.md sections referenced by that task
4. docs/REQUIRE.md entries for the task's R-xx
5. Before exploring the code: the codebase notes `artifacts/notes/codebase.md` in the main worktree (the parent of `git rev-parse --path-format=absolute --git-common-dir`), if they exist. They describe the commit on their `Commit:` line; check `git log` since then.
Read DECISIONS.md, the REQUIRE §11 decisions and docs/changes/ only when SPEC does not answer a question. `bash scripts/harness-state.sh status` shows every task's status and next action when you need it.

## Commands
Run everything through `bash scripts/hm.sh <command>` (setup, migrate, dev, dev-bg, stop, health, status, test, e2e, load, bench, security, fmt, check, selftest; `help` lists them with this worktree's ports): it exports this worktree's ports and HM_SLOT resources, so tests reach this worktree's own database and services.
- While you iterate, run only the tests you are working on: `bash scripts/hm.sh test <file>` (and `e2e <file>`).
- At each gate (the end of a task, after review fixes, after a merge), run `test` and `e2e` with no arguments: the full suites.
- Formatting is automatic: the pre-commit hook formats the staged code files and stages them again. A file you staged only in part is left as it is, and lint then rejects it until you run `bash scripts/hm.sh fmt <file>` and stage it.
The stack-specific commands are in the commands section of .harness/config. When one must change (a new component, a new test directory), change its line there and note it in the task Log.

## Language
- Talk to the user in CHAT_LANG (.harness/config). Write documents (docs/, task files, reviews) and commit message summaries in DOC_LANG.
- Always English, whatever DOC_LANG is: code and identifiers; the field names and values scripts parse (`- Status:`, `- Type:`, `- Review:`, `- Depends on:`, `Verdict:`, `Commit:`, severities); ID formats (R-01/AC-1, D-01, RV-1, CR-1); commit type prefixes (`feat(task-<id>):`); section headings of the harness templates.
- Domain terms: use the terms in the REQUIRE §9 Glossary in code names, UI text, API fields, tests and docs (translated per DOC_LANG where needed, but always the same concept). Never use a word it lists under "Not to be called". A concept the Glossary lacks is a question for me, not a new synonym.

## Per-worktree resources
Ports move with PORT_OFFSET. Everything else parallel worktrees must not share (database or schema, cache prefix, queue names, container project names, temp folders) is derived from `$HM_SLOT` in the commands in .harness/config (SPEC §2). Never point two worktrees at the same mutable resource.

## Standards
REQUIRE §10 (SEC-xx) and the SPEC §12 controls apply to every task. docs/STANDARDS.md holds the security baseline, the backend baseline and this project's coding rules; the reviewer checks every diff against it. Read its matching section before you write code that:
- stores or checks a password, token or other credential, handles a secret, builds a query, shell command or file path from input, or decides who may access an object → Security baseline
- writes several rows or calls at once, adds a table or migration, calls out of the process, lists data, or handles money or time → Backend baseline
Its Project rules apply everywhere; they are short, so read them once per task.

## Skills and files
- Use another skill only when my message names it, or a step of the harness skill you are running names it. An installed skill whose description seems to fit the work (a design system, charts, documents) stays unused, unless SPEC or DECISIONS records that I chose it (e.g. a design system in SPEC §9).
- A file I name in my message comes first for the role I give it; the harness docs fill what it lacks. If they disagree, show the difference and ask which one wins.

## Branches and worktrees
- Every task lives on its own branch `task/<id>`, created from INTEGRATION (MERGE=pr: from REMOTE/INTEGRATION).
- WORKTREES=1: each task has its own worktree. `bash scripts/harness-state.sh worktree <id>` gives its directory and PORT_OFFSET; `.harness/local` in that worktree holds `PORT_OFFSET=<n>` so parallel worktrees never share ports. Work only inside your task's worktree.
- WORKTREES=0: the task branch is checked out in the main worktree.
- Task status lives in the task file on the task branch. INTEGRATION only learns it through a merge.
- Only the apply-review step (hm-dev: "Apply these review comments", "Merge Task <id>.") merges into INTEGRATION (MERGE=local) or pushes a finished branch for the team's merge (MERGE=pr).

## Forbidden
- Modifying any path in PROTECTED (`bash scripts/hm.sh check` enforces this)
- Changing the interface contract (SPEC §4, including contracts between components) or data model (SPEC §3) without asking
- Adding dependencies not listed in SPEC §1 without asking
- Skipping, deleting, or weakening tests to make them pass
- Bypassing git hooks (`--no-verify`)
- Committing task work directly on INTEGRATION, or touching another task's branch or worktree
- Working on more than one task at a time in one session. With SESSION_PER_TASK=1, also more than one task per session; with 0, the next task may follow in the same session only after the demo report and my "Start Task <id>."
- Changing REQUIRE.md or adding tasks while developing. New or changed requirements go through hm-change.
- Reviewing your own work. Review runs in a separate session.
- Setting a task to Done, or merging into INTEGRATION. Only the apply-review step (hm-dev) does that.
- Leaving background processes running at the end of a session, except the demo (`bash scripts/hm.sh dev-bg`)
- Editing a migration that is already merged into INTEGRATION (add a new one instead), or a migration that drops or narrows data that may exist, without asking
- Tests that call a real external service listed in SPEC §4d, or that depend on data another test left behind
- Weakening, disabling or working around a security control (SPEC §12, the docs/STANDARDS.md Security baseline, a validation, a header, an access check) to make something work or a test pass
- Committing a real secret, or marking a real one with `harness:allow-secret`
- Committing temporary debug probes (lines tagged `HM-DEBUG`; `bash scripts/hm.sh check` blocks them)

## Ask the user when
- SPEC and REQUIRE disagree, or an AC cannot be met as written
- A fix requires changing the interface contract, data model, a dependency, or a PROTECTED path
- (GREENFIELD=0) A change would alter existing behavior not covered by REQUIRE §5
- The branch task/<id> already has commits at start (locally, or on REMOTE when MERGE=pr: someone else may own the task), or your worktree is dirty at start
- A task in Depends on is not merged into INTEGRATION yet (its status there is not In Review or Done)
- PARALLEL tasks are already In Progress
- The same test still fails after 3 fix attempts and the debug procedure (hm-dev) cannot build a reproducing loop or finds no cause after two rounds of hypotheses
- A task needs a security control SPEC §12 does not define, or would change one
- An edge case the ACs and DR-xx do not decide, whose result a user or another component would notice: empty, missing or duplicate data, the same request sent twice, ties, limits and overflow, ordering, rounding and units, time zones and dates, concurrent changes, partial failure. Do not pick a behavior and lock it into a test without asking.
- A choice of algorithm or approach that changes results or is hard to reverse: exact vs approximate, which record wins, tie-breaking, matching rules, a stored format, an ID scheme, a speed vs accuracy trade-off. Not a question: an internal choice with no observable difference (a data structure, a helper's shape); decide it and log it as `- Internal: <choice>, because <reason>` under the task file's Decisions during development.

Before you stop to ask, finish the work that does not depend on the answer, without guessing the answer in code. Then ask every open question at once (the frontier, below). Record each answer in the task file's Decisions during development and add a test that fixes the decided behavior (named after the task and the decision, e.g. `test_task3_dq2_...` or `task3-dq2: ...`). An answer that changes an existing AC, rule or contract is a requirement change: it goes through hm-change.

Ask in rounds. A round is the **frontier**: every open question whose answer does not wait on another open question, in one message, numbered (`❓ **1 — <topic>**`), each with its own ➡️. A question that depends on another's answer goes in the next round. Word each question so that "yes" accepts your recommendation; I may answer by number ("1 yes, 2 B"). Each question, in CHAT_LANG:

```
❓ **<short topic>**: <the question first (the sentence ending in ?), then the reason, evidence or example; one to three sentences; the phrase the decision hinges on in **bold**; names, values, paths and IDs in `code`>
A) <option>   (only if there are options)
B) <option>

➡️ <your recommended answer, and one line on why>
```

Each option says in plain words what will happen and what I gain or give up; keys or technical names only in parentheses after that. Every question carries a recommendation; if you cannot recommend, say what you would need to know and recommend the safest choice meanwhile. Use only Markdown bold and code spans for emphasis (no HTML, no color codes). Questions always come last in the message: a report, findings or explanation go first, and nothing follows the last ➡️ line.

When you stop to ask, do not make a wip commit: leave the work uncommitted and the task In Progress. A `wip(task-<id>)` commit means only "context ran out, continue in a new session".

## Task workflow
1. Start checks (hm-dev). Create the branch (and worktree), set `- Status: In Progress` in the task file, commit `chore(task-<id>): start`. MERGE=pr: `git push -u <REMOTE> task/<id>` so the team sees the task is taken.
2. Do the work the way the task's `- Type:` says:
   - feature: (GREENFIELD=0) first add characterization tests for existing code you will change; they must pass before you change anything. Then work the task's test list as **tracer bullets**: one test, red for the right reason, the least code that turns it green, then the next test (hm-dev references/tdd.md).
   - bug: first write a test that reproduces the bug and fails for that reason. Fix it. The test stays as a regression test. If the cause is not obvious, follow the debug procedure in hm-dev (feedback loop, minimal repro, ranked hypotheses, one probe at a time) and keep its Diagnosis section in the task file.
   - chore (refactor, dependency upgrade, tooling, infrastructure; no intended behavior change): confirm `test` and `e2e` pass before you change anything. Change. The same tests pass with their assertions unchanged. Add tests only for behavior the task explicitly changes.
   - spike (answer a question): investigate and write the task file's Findings: the answer, the evidence, a recommendation, and follow-up tasks to propose through hm-change. Prototype code only under the path the task names, or none. No production code, no new tests required.
   - docs: documentation only.
3. The full suites pass: `bash scripts/hm.sh test` and `bash scripts/hm.sh e2e` with no arguments (screenshots in artifacts/e2e/screenshots/task-<id>/ if HAS_UI=1). docs and spike tasks: only if they changed code or tests.
4. If the task's DoD includes a load test or benchmark, run `bash scripts/hm.sh load` / `bash scripts/hm.sh bench` and record the numbers in the task file Log
   - A new migration: `bash scripts/hm.sh migrate` after adding it and after merging INTEGRATION in.
   - A write SPEC §3 lists under repeated and concurrent writes: one test sends the request twice (or at once) and the result stays correct.
   - A test that passes alone but fails after others is a test-isolation bug: fix its data setup; never retry, reorder or skip it.
5. `bash scripts/hm.sh check` passes. If the task adds or upgrades a dependency, or lists a SEC-xx, `bash scripts/hm.sh security` passes too
6. Commit: `<type>(task-<id>): <summary>` (feature: `feat`, bug: `fix`, chore: `chore` or `refactor`, spike and docs: `docs`)
7. In the task file: `- Status: In Review`, Log entry, Notes for Next Session. Commit `docs(task-<id>): ready for review`.
8. feature and bug: prepare the demo (`bash scripts/hm.sh dev-bg` if HAS_SERVER=1)
9. Send the report (format below)
10. STOP and wait. Do not start another task until the user says so (in this session only if SESSION_PER_TASK=0).

## Report format (in CHAT_LANG)
- Summary (3 lines at most)
- Demo (feature and bug; from the task's demo scenario, ports with PORT_OFFSET applied):
  - With a screen: how to open it (URL or how to launch the app) and the steps
  - A service without a screen: the requests to send (e.g. curl) and the expected responses
  - A command or library: the commands to run and the expected output
- Instead of a demo (chore, spike, docs): what changed and the evidence (tests that still pass, or the Findings)
- Test results: unit N passed, e2e N passed, (load / bench: p95 ms)
- Needs checking / open issues
- Next:
  - Review: each → "Review Task <id>." in a separate session (review always runs in a separate session)
  - Review: batch → "Merge Task <id>." (merged without its own review; "Review all." covers it later)
  - Tasks that can start now (their dependencies are merged). SESSION_PER_TASK=1: in a new session; 0: also in this session

## Definition of Done
- By type. feature: every AC is covered by passing unit or E2E tests. bug: the regression test failed before the fix and passes after it. chore: existing tests pass with unchanged assertions. spike: Findings answer the question with a recommendation. docs: the docs match the code.
- `bash scripts/hm.sh test`, `bash scripts/hm.sh e2e`, `bash scripts/hm.sh check` pass on the task branch after INTEGRATION is merged into it
- (HAS_UI=1) E2E follows the selector policy in SPEC §5
- Each SEC-xx in the task's Requirements has a passing test that proves it (e.g. two users with the same password get different stored hashes; another user's object returns 403 or 404; a malicious input is rejected or harmless)
- Commits follow `<type>(task-<id>): <summary>`
- Review comments applied and committed (Review: each), or the task is covered by a later "Review all." (Review: batch)
- Only then does the task file show Done (set by the apply-review step)
