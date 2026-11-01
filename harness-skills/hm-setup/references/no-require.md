# Harness Steps 2–3 without docs/REQUIRE.md (part of hm-setup)

Read this when docs/REQUIRE.md is missing. It turns the requirements I already have into the two files Part A needs, .harness/config and docs/REQUIRE.md, and then Part A and Part B run as usual. It is not the hm-req interview: open points are asked once, and the rest become [ASSUMPTION]s. The rules at the top of SKILL.md apply. "The hm-req skill folder" is `../hm-req/` from the hm-setup folder; read its templates there, never copy them into the repository.

## R1. The requirements source
In this order:
1. A file I name ("하네스 만들어: docs/prd.md").
2. Files in the repository that say what to build: a PRD, a spec or brief, issues, the README's feature list, docs/**/*.md. If several fit, ask once which ones count.
3. My message and this conversation. Requirement text I pasted is saved verbatim to docs/BRIEF.md and used as the source.
With none of these, ask me in one round: what it is, who uses it, and the one scenario that must work.
Also read docs/tasks/ and docs/changes/ if they exist (written without the harness): they are context for what is built or planned, and B2 adopts them.

## R2. The profile (only when .harness/config is missing)
Detect from the repository (never scan .git/, dependency or build output, artifacts/, .run/):
- GREENFIELD: 0 if there is application code or a build file, else 1
- HAS_SERVER: 1 if the product has a long-running process (an HTTP API, a web front end on a dev server, a worker, a scheduler)
- HAS_UI: 1 if users work through screens (browser, mobile, desktop)
- HAS_LOAD: 1 only if HAS_SERVER=1 and the source gives a number for concurrent users, traffic or latency under load
- REQ_SOURCES: the files from R1 (BRIEF.md for pasted text); DATA_SOURCES: product data files (not config, manifests, lockfiles, test fixtures or migrations)
- PROTECTED: REQ_SOURCES and DATA_SOURCES, plus anything I say must not change
- CHAT_LANG: the language I write in; DOC_LANG: the language of the repository's docs, else English; AGENT_FILES: the agent entry files that exist, plus CLAUDE.md
- INTEGRATION: the current branch
Three keys are my choice, so ask them, each in plain words with your recommendation: the Mode (FULL: about five first tasks and load tests at three levels; HACKATHON for a deadline under a day: about three tasks, one load run), Task sessions (SESSION_PER_TASK: a new chat per task, or the next task in the same chat after a demo), and How work is run (solo, one task at a time: `PARALLEL=1 WORKTREES=0 MERGE=local`; solo, several at once in worktrees: `PARALLEL=2`–`3 WORKTREES=1` and a WORKTREE_DIR outside the repository; a team merging through pull requests: `MERGE=pr` and a REMOTE).

## R3. The REQUIRE.md draft
Fill `templates/REQUIRE.template.md` from the hm-req skill folder into docs/REQUIRE.md:
- §1 starts with `Written by hm-setup from <source> without the requirements interview.`
- One R-xx per requirement the source states, with `Source: <file> §x`. Priority: Must when the source says so or the one scenario that must work needs it, else Should. Every Must gets Given/When/Then acceptance criteria with concrete values and full IDs (R-01/AC-1); Should and Could say `when tasked`.
- Non-functional requirements only with a number; §9 Glossary only for terms that are ambiguous or have synonyms in the source; §10 the security rows the source implies, plus the baseline rows that apply (passwords, sign-in, users' own data, secrets, untrusted input), marked [ASSUMPTION].
- A value or a rule the source leaves open gets a `[Q-<k>]` marker where it is used and a §11 block: the question, `- Why:`, `- Affects:`, `- Recommended:`, an empty `- answer:`.
- Task files from R1: each `T<id>/AC-n` criterion maps to an R-xx/AC, or becomes one.

## R4. One round of questions
Send one message: the profile table (key, value, evidence, what it means for the project), then the questions, numbered, in the question format of A2, each worded so that "yes" accepts your recommendation: the three choices from R2 (when the config is missing), then the open Q-xx, highest impact first, at most 5. Questions last.
After my answer:
- Write .harness/config from `templates/config.template` in the hm-req skill folder, with the values settled.
- Apply every answer in REQUIRE.md (`- answer:` and `- decision:` lines, each `[Q-xx]` marker replaced by the decided value). Unanswered and lower-impact questions adopt their recommendation as [ASSUMPTION]. No `[Q-xx]` marker is left.
- Go on to Part A without stopping. Its A2 round of D-xx questions is the only other stop.

## At Finish
Add to the final report: REQUIRE.md was written from <source> without the interview, the [ASSUMPTION]s it holds in one line each, and that confirming or changing them later goes through hm-change ("요구사항 변경해: ...").
