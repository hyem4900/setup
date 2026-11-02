---
name: hm-setup
description: Steps 2–3 of the harness flow: plan and set up in one go. Use when the user says "설계 시작해" or "하네스 만들어", or asks for an architecture and SPEC from docs/REQUIRE.md or to create the harness. Asks the D-xx decisions, writes DECISIONS.md and SPEC.md, then builds the harness (AGENTS.md, task files, commands, guardrails) from this skill's templates and commits it. Also starts without REQUIRE.md, and refreshes harness files later. Not for changes after setup (hm-change).
---

# Harness Steps 2–3: Plan and set up

Talk to me in CHAT_LANG and write documents in DOC_LANG (both in .harness/config; Korean and English if unset). Code, identifiers and the fixed tokens scripts parse stay in English.
Never modify paths listed in PROTECTED.
Do not write application code in this skill. Only documents, .harness/config, agent entry files, scripts, git hooks, .gitignore and .gitattributes.
Other skills: use another skill only when my message names it or a step of this skill names it. An installed skill whose description seems to fit the work (a design system, charts, documents) stays unused, unless SPEC or DECISIONS records that I chose it.
Files I name: a file named in my message is the first source for the role I give it, and harness files only fill what it lacks. If they disagree, show the difference and ask which one wins. If it is missing or does not fit that role, say so in one line and go on without it. Read it; edit it only if I ask.

This skill's folder holds what you copy into the project: `templates/` (SPEC, AGENTS, REVIEW, STANDARDS, task file, config commands) and `scripts/`. Copy them; never retype them. Read a template only when you reach the step that uses it. Part B lives in `references/setup.md`, and the start without docs/REQUIRE.md in `references/no-require.md`.

## Where to start
- docs/REQUIRE.md has an open `[Q-xx]` marker: the hm-req interview was cut off. Stop and tell me to finish it with hm-req.
- docs/REQUIRE.md or .harness/config is missing: read references/no-require.md in this skill's folder and follow it first (from a file I name, a requirements file in the repository, or our conversation); it ends where Part A begins. With REQUIRE.md present and only the config missing, do its profile steps only (R2, then R4 without Q-xx).
- The tag harness-init exists, or AGENTS.md has the harness section (the line `Project profile: see .harness/config`): this is a refresh. Go to "Refresh".
- docs/tasks/ (or docs/changes/) exists without either: tasks were written without the harness (hm-dev "개발해", hm-change). Set up normally (Part A, then Part B) and adopt them in B2.
- docs/SPEC.md and docs/DECISIONS.md exist but no tasks: ask whether to keep the plan (go to Part B) or redo it (Part A; keep D-xx numbers and append).
- Otherwise: Part A, then Part B.
- Read .harness/config, docs/REQUIRE.md fully (its §11 decisions included), and every file in REQ_SOURCES. Projects set up by an older harness may also have docs/DISCOVERY.md: read it too.

# Part A: Plan

## A1. Existing system (GREENFIELD=0)
Analyse it before asking anything, since hm-req did not write it down: entry points per component, how it builds, runs and tests today (run the commands and note the result), how components talk (HTTP, events, shared database, files), the existing tests and their state, conventions to follow, fragile areas. It feeds SPEC (§2, §3 and §4 marked Existing, §8) and the D-xx questions; write no separate document.

## No web search
Do not search the web or browse documentation in this skill; it stalls the plan, and Task 0 proves the choices anyway. Decide from the requirements, the repo and what you already know.
- Design for what fits the product best, not for what this machine has installed: do not check installed runtimes or tools here. Task 0 checks them and asks me to install what is missing.
- Versions: the current stable major version you know, written in SPEC §1 (major only). Exact versions are pinned by the lockfile Task 0 creates. Exception: versions the repo already pins (GREENFIELD=0: version files such as `.python-version`, `.nvmrc`, `engines`, lockfiles) are the project's decision; keep them.
- A fact that a decision hinges on and that you cannot check locally (a recent breaking change, a feature of a tool, a license, an end-of-support date): do not look it up. Make the choice, write `needs check: <what>` in its Reason, and Task 0 verifies it; if it turns out wrong, Task 0 stops and asks.
- Search only when I ask for it.

## A2. Ask before planning
List every technical decision that is ambiguous or not covered by REQUIRE.md, then ask me in ONE message.
The tech stack questions below always come first and do not count toward the limit. Beyond them, default at most 5 decisions (HACKATHON: 3). If more decisions are hard to reverse, ask the most important ones first and say how many remain; I decide whether to go through them or take your defaults.

### Tech stack: always ask
Ask one D-xx per layer the product has, never decide a layer silently: backend (language and framework), frontend (HAS_UI=1: how screens are built and served), database or storage, and any other layer that applies (mobile app, queue or worker runtime, CLI packaging).
- Options: two or three per layer. Always include the most widely used choices for that kind of product and layer (for a web frontend, both a component-based single-page framework with its own build and a server-rendered or plain-page approach), not only the one with the fewest moving parts. If I named a language or framework I know or prefer, include it.
- Each option says what it gives and costs for this product, including how it fits the other layers (one language end to end, a build step, two processes to run, typing across the boundary, what I already know).
- The recommendation weighs MODE (HACKATHON favors fewer moving parts) and REQUIRE; the options do not.
- A layer that REQ_SOURCES, REQUIRE or my answers already fix is written as given, not asked. GREENFIELD=0: the existing stack is given; ask only about a layer that is new or that REQUIRE forces to change.

### Core logic: always ask
Find the product's core computations: the R-xx and DR-xx whose result depends on an algorithm rather than on storing and showing data (routing, matching, ranking and recommendation, search relevance, scheduling and allocation, pricing, deduplication, aggregation over large data). Ask one D-xx per computation on how it is done; never leave it to development. These questions come right after the stack and do not count toward the limit either.
- Make the question concrete for this product, not a textbook choice. For a route finder, for example: which shortest-path algorithm and how it is changed (what the nodes and edges are, how transfers, waiting and walking times enter the cost, whether time of day matters, one criterion or several such as time then transfers, how many routes come back and how near-duplicates are removed, what is precomputed).
- Options: two or three approaches, each with what it gets right or wrong for this product (exact or approximate result, which domain rules it handles naturally and which need extra work, speed at the REQUIRE §4 data size against the NFR, how hard it is to build and test).
- Cite the DR-xx, NFR-xx and data facts it depends on. If REQUIRE leaves a rule the algorithm needs undecided (what "best" means, a tie-break), ask that in the same question.
- The answers go into SPEC §6, one entry per computation.

Where to look, depending on config:
- Always: runtime and deployment target, error handling style, IDs (the time budget is already fixed by MODE)
- Components: which processes or apps make up the product (one is fine), what each owns, how they talk (HTTP, RPC, events/queues, shared database, files), and how they start together for development (the harness starts each one, or an existing launcher starts them all). For GREENFIELD=0, the existing components come first.
- Isolation (WORKTREES=1): which mutable resources parallel worktrees would otherwise share (database or schema, cache, queues, buckets, container projects, temp folders) and how each worktree gets its own copy from HM_SLOT. Usually a default, not a question.
- DATA_SOURCES set: storage choice, loading strategy (on startup vs one-time import), unresolved quality issues, derived fields
- HAS_SERVER=1: API style, pagination, filtering, sorting defaults, validation, auth if any
- HAS_UI=1: platform (browser, mobile, desktop), server-rendered vs SPA where it applies, navigation, empty/error states, design direction (tone, density, mobile; if I name a design system or a design skill to follow, record it in SPEC §9 and a D-xx, so development may use it; never pick one yourself), and the E2E selector policy: `test-id` (default: tests select only by test id; most stable), `test-id+role` (role lookups with an accessible name are also allowed; keeps tests close to how users and assistive tech see the UI), or `none` (no rule)
- HAS_SERVER=0: command/API surface, input/output formats, exit codes, packaging
- Any latency or throughput NFR: caching, indexes, precomputation needed to meet it
- Security (REQUIRE §10): decide by default and list it under "Defaults I chose". Ask a D-xx only when REQUIRE leaves open something that changes what gets built: how users sign in (own passwords, an external identity provider, API keys), or a SEC-xx beyond the baseline (encryption of stored personal data, audit logs, multi-factor sign-in). The password hash and the other baseline controls are never questions.
- GREENFIELD=0: where new code goes, which existing patterns to follow, what may be refactored. Default to the existing stack; only ask if REQUIRE.md forces a change.
- Test tooling, for every need that applies: unit tests, E2E through the outer interface (with screenshots if HAS_UI=1), load (HAS_LOAD=1), benchmarks (§10b), security scans, and code quality (a linter, the type checker, a formatter) for every language in the stack. See "Choosing test tools".

How to choose:
- Ask only about decisions that are hard to reverse or change what gets built.
- Decide everything else yourself and list it under "Defaults I chose" so I can override.
- In HACKATHON mode, recommend the option with the fewest moving parts (one process, one language, no build step if possible), but still list the mainstream options.
- Ground each decision in a citation (R-xx, NFR-xx, DR-xx, a REQUIRE §4 data fact, a §11 decision, or what you found in the existing code).
  - Bad: "Which database should we use?"
  - Good: "NFR-02 needs p95 < 300ms for search over 120k rows (REQUIRE §4). A) SQLite + FTS index B) pandas in memory. Recommend A: persistent, indexed, fast enough."

Format (the defaults table first, then each D-xx as below, separated by a blank line; the questions come last):

~~~
**Defaults I chose**
| # | Item | Choice | Reason |

❓ **D-01 — Search storage**: **Where should the searchable data live?** `NFR-02` needs p95 < 300ms for search over 120k rows (REQUIRE §4).
A) SQLite + FTS index — persistent, indexed / one more file to manage
B) pandas in memory — no setup / reloads 120k rows on every start

➡️ A: persistent, indexed, and fast enough for `NFR-02`.
~~~

- The rules of the format (question first, options in plain words, one recommendation each, questions last) are in references/question-format.md in this skill's folder: read it before A2. A question that comes up later (while writing SPEC or setting up) uses the same format.

### Choosing test tools
The harness does not prescribe test tools. For each testing need that applies, recommend one tool and name one alternative, judged in this order:
1. Already used in the repo (GREENFIELD=0), or native to the chosen stack's language
2. Runs headless and non-interactively from a harness command (`bash scripts/hm.sh <name>`), and exits non-zero on failure
3. Covers the need:
   - UI E2E (HAS_UI=1): drives the real UI (browser, or the device/emulator or desktop app), selects elements by a test-id attribute, saves full-screen screenshots at a given viewport or device size
   - Service E2E (HAS_SERVER=1, HAS_UI=0): a client inside the test framework (HTTP, or the message/RPC protocol the components use), against the running components
   - CLI / library E2E (HAS_SERVER=0): subprocess or fresh-process calls from the test framework
   - Load (HAS_LOAD=1): scripted user scenarios with weights, a set user count and duration, per-endpoint p50/p95/p99, error rate and RPS written to a machine-readable file
   - Benchmark (§10b): excludes warm-up runs, repeats measured runs, reports p50/p95 per target
   - Code quality, for every language in the stack: a linter, the type checker if the language has one, and a formatter that rewrites the files it is given and has a check mode. Prefer the stack's standard ones; one tool may cover several. The repo's own configuration wins (GREENFIELD=0)
   - Security scans, here: only a dependency vulnerability audit for each package manager, preferring one built into the package manager (no new dependency). Static security analysis and a history secret scan are added by hm-security on its first run, so they cost nothing up front
4. Fewest new dependencies and moving parts (in HACKATHON mode, weigh this most)

Judge these from what you know and what the repo shows (see "No web search"); Task 0 proves each tool runs headless and does what it was chosen for.
List the choices under "Defaults I chose", with the alternative in the Reason column. Ask a D-xx only when two options are close or the stack has no common choice.
Record each tool in SPEC §1 (major version), how it is used in §7, and its commands in §2.

I will reply like "D-01: A, D-02: B, default 3 → X" or "all as recommended" (e.g. "전부 추천대로").
Do not write any file until I reply. This is the only stop between here and the final report.

## A3. docs/DECISIONS.md

~~~markdown
## D-01 {title}
- Status: Accepted | Default
- Context:
- Decision:
- Alternatives considered:
- Consequences:
~~~

Record every accepted default too, with Status: Default.

## A4. docs/SPEC.md
Copy `templates/SPEC.template.md` to docs/SPEC.md and fill every section, following the notes in it.
- Keep every numbered section so references stay stable. If a section does not apply, write `N/A (<config key>=<value>)` on one line.
- Name tables, entities, endpoints, fields, events, screens and modules after the REQUIRE §9 Glossary terms (English identifiers for them where DOC_LANG is not English, chosen once and used everywhere).
- Write only what a decision needs: what tasks must agree on, and what Part B turns into commands (§2). No file paths below the top-level folders, no code. The one exception is a short schema, type or state shape that states a decision more precisely than prose.

Rules:
- Every Must R-xx is listed under Requirements by at least one §4 entry or §5 screen.
- Every component in §2 has a health check that proves its identity, and every arrow in "Talks to" has a §4c entry.
- Every NFR with a latency, throughput, or load target appears in §10a or §10b. A concurrent-user target needs §10a: if HAS_SERVER=1 and HAS_LOAD=0, ask me whether to switch HAS_LOAD to 1. With HAS_SERVER=0, use §10b.
- Write `N/A (no performance NFR)` under §10a or §10b when it has no rows.
- Every SEC-xx appears in §12a or §12b with how it is verified.
- If something new comes up while writing SPEC that needs a decision, stop and ask in the D-xx format.

Then do not stop: tell me in at most about 10 lines what the plan is (stack, components with ports, main entities, the `needs check` items), and go on to Part B. Changes I ask for after the final report are cheap, since no task has started.

# Part B: Set up
Read references/setup.md in this skill's folder and follow it (B0 checks, B1 install, B2 task files, B3 harness commands, B4 traceability, B5 git, Finish).

# Refresh
When the tag harness-init exists, or AGENTS.md has the harness section. Regenerate only what I ask for among AGENTS.md (harness section), docs/REVIEW.md, docs/STANDARDS.md (its Project rules always stay), the commands section of .harness/config, .harness/guardrail-samples, scripts/ and .githooks/, from this skill's current templates and scripts (copy the two scripts directly; run `bash scripts/hm.sh selftest` after a pattern change), and show me the diff before committing (`chore: refresh harness`).
Always, whatever I asked to refresh: compare the keys of `templates/config-commands.template` with the commands section of .harness/config. A key the template has and the config lacks was added to the harness after this project was set up (e.g. `TYPECHECK_CMD`): list each with the template's comment and a proposed value from SPEC §2 and the stack, ask in one round, and add the lines (empty when the stack has nothing for it). Never remove or reorder the keys the project has. Keep project-specific lines I added. A project set up before docs/STANDARDS.md existed: refreshing AGENTS.md or docs/REVIEW.md also adds docs/STANDARDS.md, and lines I added to the old AGENTS.md "Security" or "Backend baseline" sections move into it. Never touch task files, REQUIRE, SPEC or DECISIONS, and never re-tag harness-init. A design change or new requirements go through hm-change.
