# Harness Step 3: Set up (part of hm-setup)

Part B of hm-setup, read once the plan (Part A) is written. The rules at the top of SKILL.md still apply: CHAT_LANG and DOC_LANG, PROTECTED, no application code. "This skill's folder" below is the hm-setup folder, the parent of this file's folder.

## B0. Checks
- SPEC §1 names a tool for every test need that applies (unit, E2E, load if HAS_LOAD=1, benchmark if §10b has rows). If one is missing (an older SPEC), recommend one and name one alternative (SKILL.md "Choosing test tools"), ask me, and add it to SPEC §1, §2 and §7 before going on.
- If this is already a git repo and `git status --porcelain` shows changes outside docs/ and .harness/, ask me before going further. Never sweep my uncommitted work into the harness commit.
- Tooling: `git` (2.31 or newer, for worktrees and path output) and `bash` (3.2 or newer; on Windows, Git Bash). No other build tool is required: every harness command is `bash scripts/hm.sh <name>`.
- Windows: the `bash` on PATH is often the WSL launcher (C:\Windows\System32\bash.exe), not Git Bash. Run `bash -c 'echo $OSTYPE'`: it must print `msys` or `cygwin`. If it prints something else, tell me to put Git's `bin` folder (usually `C:\Program Files\Git\bin`) before `C:\Windows\System32` in PATH, or to call Git Bash by its full path, and stop. Git hooks are not affected: git runs them with its own shell.

## B1. Install the fixed files (one command)
From the project root, run `bash <this skill's folder>/scripts/install.sh`. In one run it:
- copies `scripts/hm.sh` and `scripts/harness-state.sh` unchanged and makes them executable
- writes AGENTS.md from the template, or appends its harness section under `# Harness` to an existing AGENTS.md (GREENFIELD=0), never moving existing content
- makes every file in AGENT_FILES (default `CLAUDE.md`) point to AGENTS.md (`Read AGENTS.md first ...` and `@AGENTS.md`), unless it already does
- copies docs/REVIEW.md, docs/STANDARDS.md, docs/tasks/_template.md and .harness/guardrail-samples from the templates
- writes the git hooks (.githooks/pre-commit runs `bash scripts/hm.sh check --hook`, which formats the staged code files with FORMAT_CMD and stages them again, then checks them and lints only them, skipping LINT_CMD when only Markdown is staged; commit-msg enforces `<type>(<scope>): <summary>`) and sets `core.hooksPath`
- appends the missing .gitignore lines (`artifacts/`, `.run/`, `.harness/local`, the real env files) and .gitattributes lines (LF for scripts, hooks, config and task files)
- appends the commands section of .harness/config with placeholders

It never overwrites an existing file and prints one line per file. Do not copy or write these files by hand, and do not write helper scripts that generate harness files: what is left is editing (B2, B3), plus the stack's usual .gitignore entries if missing. Do not ignore tests/fixtures/, .harness/config, docs/tasks/ or docs/reviews/. WORKTREE_DIR must be outside the repository, so test runners and file watchers never scan other worktrees.

## B2. Task files (docs/tasks/)
One file per task: `docs/tasks/<id>.md`. Separate files keep parallel branches from conflicting, and new tasks are added without renumbering.
IDs: numbers by default (0, 1, 2, ...). A team may use issue keys or `<initials>-<n>` instead; any ID matching `[A-Za-z0-9][A-Za-z0-9._-]*` works. Never reuse an ID.

Write each task from `docs/tasks/_template.md`, which B1 installed (the leading underscore keeps it out of the task list); hm-change uses it too.

Task files written before setup (without the harness, by hm-dev "개발해" or hm-change) are adopted, not replaced:
- Keep their IDs, status, branches and Log. New tasks take the next free IDs after them.
- Fill what the template asks that they lack (`- Review:`, `- Core:`, Requirements). Map each `T<id>/AC-n` criterion to the R-xx/AC it matches in REQUIRE.md and write that ID next to it (`T3/AC-1 = R-02/AC-4`), so tests keep their names; a criterion REQUIRE does not cover is a question for me (add it as an AC, or leave it task-only).
- A task that is Done or merged counts as built: plan the rest around it, and list it in the traceability check (B4).
- docs/changes/CR-*.md stay as they are; the next CR takes the next free number.

Fixed format, because scripts parse it: the `- Status:`, `- Type:`, `- Review:`, `- Core:` and `- Depends on:` lines, exactly as in the template, in English whatever DOC_LANG is.
- Status: `Todo`, `In Progress`, `In Review`, `Done`, `Dropped` (no longer needed; set only by hm-change).
- Type: `feature` (new or changed behavior from R-xx), `bug` (behavior that is wrong), `chore` (refactor, dependency upgrade, tooling, infrastructure; no intended behavior change), `spike` (answer a question; the result is Findings, not production code), `docs`. A missing line means feature. Only feature and bug tasks have a demo; the workflow and DoD per type are in AGENTS.md.
- Review: `each` (own review before merge) or `batch` (merged after the demo, reviewed later by "Review all.").
- Depends on: task IDs separated by commas (`1, 2` or `Task 1, Task 2`), or `none`.

### Task 0: walking skeleton
Compose it from the config and SPEC §2. Include every row whose condition holds.

| Condition | Task 0 includes |
|---|---|
| always | Folder structure from SPEC §8, unit test harness with fixtures, E2E harness with one smoke test, every harness command working (disabled ones print `skip`; `fmt` on a badly formatted sample file fixes it and `check` then passes), git hooks installed by `bash scripts/hm.sh setup` |
| a database | MIGRATE_CMD set up; `bash scripts/hm.sh setup` creates and migrates this worktree's database; one test proves tests isolate their data (it runs twice in a row and passes) |
| SPEC §4d lists external services | Each has its test double wired in the test setup; the real credentials are only read from the environment and never needed for `test` or `e2e` |
| always | Secrets and environment-specific settings read from the environment; an example env file with placeholder values committed, the real one ignored; SECRET_PATTERN proven by `bash scripts/hm.sh selftest` (B3). Nothing more on security in Task 0. The controls every request needs are wired once, by the first slice that adds such an entry point, as part of its DoD and each with a test, so later tasks inherit them; B2 lists the ones that apply in that task's Scope: an auth layer that denies by default and checks roles on the server; session cookies HttpOnly, Secure in production, SameSite; CSRF protection for cookie sessions; a CORS allow-list; the security headers of SPEC §12 (CSP, frame protection, HSTS); a redirect to HTTPS in production; a request body size limit; generic error responses in production mode |
| GREENFIELD=0 | The commands in .harness/config call the existing install/run/test commands (an existing Makefile, package scripts or task runner stays as it is); existing tests pass under `bash scripts/hm.sh test`; one characterization test of the main existing flow |
| HAS_SERVER=1 | Every component in SPEC §2 starts with `bash scripts/hm.sh dev-bg`, passes its health check, and stops with `bash scripts/hm.sh stop`; the smoke E2E goes through the outermost component (e.g. screen → API) |
| HTTP components | GET /healthz returning `"service": "<SERVICE>-<component>"`; a component that only serves pages (a UI dev server) carries `<meta name="service" content="<SERVICE>-<component>">` in its index page instead |
| DATA_SOURCES set | Loading of all data with the rules from REQUIRE §4. Row counts exposed in a health check or printed by a load command |
| HAS_UI=1 | The design token file built from the SPEC §9 direction, its path written into SPEC §9; an empty screen using it with the root test-id (`app-root`); smoke E2E checks it and saves a screenshot |
| always | `bash scripts/hm.sh doctor` prints `doctor: ok` (its warnings are listed in the Task 0 report) |
| always | Every runtime and tool in SPEC §1 is present on this machine at the chosen major version. One that is missing or too old: stop and tell me how to install it (the official installer or a version manager), and continue once I say it is done |
| SPEC §1 or DECISIONS.md has `needs check` items | Each one verified on this machine (the tool installs, runs headless from its harness command, does what it was chosen for); the mark removed from SPEC and DECISIONS. One that fails: stop and ask, with the alternative from the Reason column |
| HAS_SERVER=0 | The CLI/library entry point runs and prints its version or help; smoke E2E runs it as a subprocess |
| SPEC §2 lists per-worktree resources | Each is derived from `$HM_SLOT` in .harness/config; run `test` (and `e2e`) once with `PORT_OFFSET=<PORT_STEP>` in `.harness/local` and confirm it uses its own copy (e.g. database `app_1`), then restore it |
| HAS_LOAD=1 | A placeholder load scenario under tests/load/ in the load tool from SPEC §1, hitting a health check; tests/load/targets.json from SPEC §10a; `bash scripts/hm.sh load` runs it |
| SPEC §10b has targets | tests/bench/ with one placeholder benchmark and tests/bench/targets.json from SPEC §10b; `bash scripts/hm.sh bench` runs it |

### Task 1 onward: vertical slices
- Each slice cuts through every layer and component that applies (data → logic → interface → screen) and is demoable on its own.
- Cover every Must. Riskiest Must first. Start with about 5 slices (FULL) or about 3 (HACKATHON); that is a starting point, not a cap: split anything that will not fit one session (rough guide: at most about 3 R-xx or 8 ACs per task). If time is fixed (HACKATHON) and the Musts do not fit, ask me what to cut.
- Mark the core task (the most used read path, or the main command) with `- Core: yes`. If HAS_LOAD=1, its DoD includes a first `bash scripts/hm.sh load` at the target user count. If SPEC §10b has targets, the DoD of each task that implements a benchmarked command or function includes `bash scripts/hm.sh bench`.
- A Should or Could R-xx whose acceptance criteria say `when tasked` and that gets a task now: write its ACs in REQUIRE.md first, by the hm-req rules (full IDs, Given/When/Then, concrete values; ask me in the question format if a value is open). The rest keep `when tasked` until hm-change gives them a task.
- Slices are `Type: feature`. Work that serves no requirement directly but must happen (a dependency upgrade, a risky unknown to settle before a slice) is its own chore or spike task, which the slices it unblocks depend on.
- Review policy, the same in both modes: `each` only for a **one-way door** (a migration that drops, narrows or rewrites stored data; sign-in, credentials or access control, a SEC-xx; a contract that something outside this repository relies on, such as a public API or a published file or event format), `batch` for the rest, spike and docs included; "Review all." covers the batch tasks at the end. A task I call risky is always `each`.
- Depends on: the tasks whose code this one builds on. When PARALLEL > 1, also make tasks that will edit the same files depend on each other, so parallel branches do not conflict. Prefer slices that touch different modules or components so they can run in parallel.

### Wide changes and prefactoring
hm-change carries the same rules for tasks it adds.
- Prefactor first: when a slice is easier after a refactor ("make the change easy, then make the easy change"), that refactor is its own `chore` task, and the slice depends on it.
- A **wide change** is one mechanical change whose blast radius fans across the codebase (renaming a column, retyping a shared symbol, swapping a library used everywhere), so one task cannot land it green, and in parallel it would conflict with every open branch. Sequence it as **expand–contract**, each step a `chore` task that leaves `test` and `e2e` green:
  1. Expand: add the new form beside the old one; nothing breaks.
  2. Migrate: move the callers in batches sized by blast radius (per component or folder), one task per batch, each depending on the expand task. Batches touch different files, so they can run in parallel.
  3. Contract: delete the old form once no caller is left, depending on every migrate task.

There is no PROGRESS.md: status lives in the task files, and `bash scripts/harness-state.sh status` (also `bash scripts/hm.sh status`) shows the table across branches.

## B3. Harness commands (.harness/config)
`hm.sh` runs the harness commands (setup, migrate, dev, dev-bg, stop, health, status, test, e2e, load, bench, security, fmt, check, selftest, doctor, help); every command always exists, and one turned off by the config prints `skip: <reason>` and exits 0. `harness-state.sh` reads task files and branches across worktrees for hm-auto, hm-dev and hm-review, and changes nothing on its own.
Do not write a Makefile or another task-runner file for the harness. If the project already has one (GREENFIELD=0), leave it as it is and call it from the commands (e.g. `TEST_CMD=make test`). If I ask for `make <name>` shortcuts, such a Makefile may only forward each target to `bash scripts/hm.sh <name>`.

Fill the commands section B1 appended to .harness/config from SPEC §2: replace every placeholder, delete the example component lines that do not apply, and add one line per per-worktree resource. Same format: one `KEY=value` per line, the value is the rest of the line taken literally (no quotes needed, no inline comments). Commands run with `bash -c` after every key is exported, so a command refers to other keys as `$NAME` at run time.

- `<c>_PORT` is a base. hm.sh exports `<c>_PORT` as base + PORT_OFFSET (from the worktree's .harness/local), and base + PORT_OFFSET + 100 during `load`, so every port moves together. Components that call each other get the other's port from `$<c>_PORT` (pass it through an environment variable in the command), never a hardcoded number.
- Write each command as you would type it in bash. Use forward slashes in paths. A value used by several commands (a database URL, a data path) can be its own key, referenced as `$NAME`.
- INSTALL_CMD runs once per worktree (`bash scripts/hm.sh setup` at every task start when WORKTREES=1), so write it so that worktrees share the package manager's download cache instead of downloading again: a tool with a global store (pnpm, uv, cargo, go modules, Maven, Gradle) does this by itself; npm needs `npm ci --prefer-offline`, pip a cache dir outside the worktree. Say in SPEC §2 which it is.
- `HM_SLOT` is PORT_OFFSET / PORT_STEP: 0 in the main worktree, 1, 2, ... in task worktrees. Every per-worktree resource in SPEC §2 gets its own key built from it, and the commands use that key. A resource that must be created first (a database, a schema) is created by INSTALL_CMD or by the test setup, idempotently.
- TEST_CMD and E2E_CMD: put `"$@"` where the runner takes test files or a name filter, so `bash scripts/hm.sh test <file>` runs only those and no arguments runs everything (`hm.sh help` warns when it is missing). With several components, put it on the runner a single file belongs to, or leave it out where a path would break the command.
- LINT_CMD: the linter and the formatter's check mode from SPEC §2, as one command that takes files as `"$@"` (no arguments: the whole project). The pre-commit hook runs it on the staged code files only, so a commit costs seconds whatever the project size; a direct `check` runs it on everything. With several languages, one call per tool filtered by extension.
- TYPECHECK_CMD: the type checker, over the whole project (a type check cannot be limited to the staged files). It runs only in a direct `check` (task end, review, merge), never in the hook. Empty if the language has no type checker.
- FORMAT_CMD: the formatter, rewriting the files it is given: put `"$@"` where it takes files (paths from the project root), and make it skip file types it does not handle (its ignore-unknown option, or one call per component filtered by folder or extension). The pre-commit hook runs it on the staged code files and stages the result, so formatting never blocks a commit; `bash scripts/hm.sh fmt` with no arguments formats the whole project.
- Leave LINT_CMD, TYPECHECK_CMD or FORMAT_CMD empty only if the stack has no such tool, and say so in the Finish report.
- SECURITY_CMD: at setup, only the dependency vulnerability audit from SPEC §2 (usually built into the package manager). hm-security chains static security analysis and a history secret scan onto it on its first run. It exits non-zero on a finding at or above the severity SPEC §12 sets (default High) and writes reports to artifacts/security/. Leave it empty if the stack has no built-in audit. It is not part of `check`: scans can be slow and need the network.
- SECRET_PATTERN: an extended regex, matched case-insensitively, for secrets that must never be committed. `check` runs it on every staged and tracked file, so the pre-commit hook enforces it, and prints only file:line, never the value. Start from the default in the template (private keys, a cloud access key format, quoted values assigned to password, secret, key or token names) and add the key formats of the services in SPEC §1. Lines containing `harness:allow-secret` are ignored; use it only for fakes in tests and documented examples.
- LOAD_LEVELS by MODE: FULL `10 <target> <2x target>`, HACKATHON `<target>`.
- A health check proves it is THIS project's component. `http_has <url> <text>` (built into hm.sh) passes only if the response contains the text: use `<SERVICE>-<component>`, which /healthz returns as `service` and a UI dev server carries in its meta tag. A non-HTTP component (worker, consumer) writes a ready marker or answers a ping command. A check that only tests "something listens on the port" is not enough.
- A component that is not long-running (a CLI, a library) is not in COMPONENTS. With HAS_SERVER=0, COMPONENTS is empty and DEV_CMD is one sample invocation.

### Guardrails (`bash scripts/hm.sh check`)
It reads everything from .harness/config. The pre-commit hook (`check --hook`) checks only the staged files (unchanged files passed when they were committed); a direct `check` checks the whole tree. It fails when:
- a PROTECTED path changed since the tag harness-init (committed, staged, modified, or a new file)
- SECRET_PATTERN matches a staged or tracked file (except .harness/config, .harness/guardrail-samples and lines marked `harness:allow-secret`)
- a staged or tracked file other than Markdown still holds the debug tag `HM-DEBUG` (debug probes)
- SKIP_PATTERN matches under any of TEST_DIRS
- (HAS_UI=1) SELECTOR_PATTERN matches under any of E2E_DIRS (empty pattern: no check)
- a task file's `- Status:`, `- Type:` or `- Review:` has a value outside its list
- LINT_CMD fails (the hook: on the staged code files; a direct `check`: on the whole project)
- TYPECHECK_CMD fails (a direct `check` only)

A directory in the list that does not exist prints a warning; a broken regex fails loudly instead of passing silently.

Write these for the tools in SPEC §1:
- TEST_DIRS: every directory that holds unit or E2E tests, across components (e.g. `tests api/tests web/src`). Co-located test files are fine: list their source directories.
- E2E_DIRS (HAS_UI=1): the directories with UI E2E tests.
- SKIP_PATTERN: every way the unit and E2E frameworks can skip or disable a test (skip markers, skip calls, disabled-test aliases).
- SELECTOR_PATTERN (HAS_UI=1): a deny list for the UI E2E tool, following the selector policy in SPEC §5:
  - `test-id`: match every element-selection API that does not go through the test-id attribute: role, text, label, placeholder and title lookups, and CSS, XPath or platform selectors that are not the test id.
  - `test-id+role`: the same, but role lookups with an accessible name are allowed; text, label, placeholder, title, CSS and XPath lookups are still denied.
  - `none`: leave SELECTOR_PATTERN empty.
  Configure the tool to use the test-id attribute as its test-id attribute if it has such a setting.

Patterns are extended regular expressions (`grep -E`), written as they are: quotes, commas and `#` need no escaping.

Prove them with one command, not with throwaway files or scratch repositories: write `.harness/guardrail-samples` (B1 installed it with its format in the header): a `skip:` line for each skip style of the test tools, `selector-deny:` lines for each denied selector style and `selector-allow:` lines for each allowed one (HAS_UI=1), and a fake `secret:` line for each key format you added to SECRET_PATTERN. Then run `bash scripts/hm.sh selftest` once. It checks every sample against its pattern, plus built-in secret and debug samples, a bad task file and the PROTECTED paths, then runs `check` on the tree (LINT_CMD included). Fix the patterns until it prints `selftest: ok`.

## B4. Traceability check (report only)
Before committing, check the points below and fix the task files for anything unmapped. Report the result in the Finish message; write no file (docs/TRACEABILITY.md belongs to hm-audit):
- Every Must R-xx maps to a task file and to at least one named test
- Every AC in REQUIRE.md appears, by its full ID (R-xx/AC-n), in some task's acceptance criteria (a Should or Could still marked `when tasked` has none yet and needs no task)
- Every NFR with a latency or throughput target is in SPEC §10a or §10b and in some task's DoD
- Every interface entry (SPEC §4, including §4c between components) and screen (SPEC §5) belongs to a task
- Every component in SPEC §2 is started by Task 0
- Every SEC-xx maps to a task with a security test, or to a SPEC §12 control that Task 0 or a task wires in
- (GREENFIELD=0) Every existing module a task touches has a characterization test listed
- Depends on has no cycles and names existing tasks

## B5. Git
- If not a git repo: `git init` (before B1, so the installer can set `core.hooksPath`).
- INTEGRATION in .harness/config is the branch you are on (ask if it should be another).
- Stage only the harness files explicitly: AGENTS.md, the files in AGENT_FILES, .gitignore, .gitattributes, .githooks/, .harness/config, .harness/guardrail-samples, docs/, scripts/, plus any PROTECTED input files not yet tracked. Never `git add -A` in an existing repo.
- MERGE=local: commit on INTEGRATION: `chore: harness docs, commands, guardrails`, then `git tag harness-init`.
- MERGE=pr: commit the same on a branch `chore/harness`, `git tag harness-init`, push the branch and the tag (`git push -u <REMOTE> chore/harness harness-init`), and tell me to open a PR into INTEGRATION. Tasks become visible to the script once it is merged.
  - The git hooks run only on each developer's machine, so the team's pull requests need the same gates in CI. Add one job to the repository's CI (its existing system; if there is none, ask me which one) that runs, on every pull request into INTEGRATION: `bash scripts/hm.sh setup`, `bash scripts/hm.sh check`, `bash scripts/hm.sh test`, `bash scripts/hm.sh e2e` (on Windows runners, Git Bash). Commit it with the harness. `check` there runs the whole tree, so it also catches what a developer committed with hooks bypassed.
- Run `bash scripts/harness-state.sh status` once after the commit to confirm it lists every task with status Todo (it reads committed task files). Task 0 proves `dev-bg` / `stop` once the components exist.

## Finish
Report in CHAT_LANG:
- Decisions made and the stack summary; any R-xx not covered by SPEC; the `needs check` items Task 0 will verify
- Profile summary: components with their ports, per-worktree resources, which harness commands are active vs skip, branch/merge/parallel settings, agent entry files written
- Task list with type, requirement IDs, review policy, dependencies, which one is the core task, and which tasks can run in parallel first
- Traceability result
- Next step, both ways:
  - Manual: SESSION_PER_TASK=1 → "Start Task 0." in a new session; SESSION_PER_TASK=0 → also possible in this session. With PARALLEL > 1, open one session per task whose dependencies are merged and run them at the same time
  - Automatic: in a chat that supports sub-agents (Codex, Claude Code), ask to run automatically (hm-auto). Demo checks and questions hold only their own task; it waits for me when nothing else can run
  - A change to the plan (SPEC, DECISIONS) before Task 0 starts: tell me and I fix the plan, the task files and the commit. Later, and for new or changed requirements: hm-change (e.g. "add a requirement: ...")

Then stop. Do not start Task 0.
