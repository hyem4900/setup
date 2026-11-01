---
name: hm-change
description: Takes in a new or changed requirement after harness setup, or without the harness (then only a change record and task files) (a feature, a change, a bug, demo feedback, a removal, technical work, a question to investigate, a security review's findings, a task split) and turns it into a change record, updated REQUIRE, SPEC and DECISIONS, and new or dropped task files, without restarting the flow. Use when the user says "요구사항 추가해: ...", "요구사항 변경해: ...", "버그 등록해: ...", "수정 요청: ...", "보안 리뷰 반영해: <file>", "Task N 나눠줘", or asks to add, change, split or drop requirements or tasks mid-project.
---

# Harness: Change request

Talk to me in CHAT_LANG and write documents in DOC_LANG (both in .harness/config; Korean and English if unset). Code, identifiers and the fixed tokens scripts parse stay in English.
Never modify paths in PROTECTED. Do not write product code: this skill changes docs and task files only.
Other skills: use another skill only when my message names it or a step of this skill names it. An installed skill whose description seems to fit the work (a design system, charts, documents) stays unused, unless SPEC or DECISIONS records that I chose it.
Files I name: a file named in my message is the first source for the role I give it, and harness files only fill what it lacks. If they disagree, show the difference and ask which one wins. If it is missing or does not fit that role, say so in one line and go on without it. Read it; edit it only if I ask.

## Inputs
Find each input in this order, and name in the CR file the file that served (e.g. `Requirements: docs/prd.md (stand-in for REQUIRE.md)`): a file I name → the harness file → a file in the repository that plays the same role (ask once if several fit) → the fallback.
Without the harness (no .harness/config), create none of .harness/config, AGENTS.md, scripts/ or git hooks: they belong to hm-setup, and other skills would take them for a finished setup. For this session use: CHAT_LANG the language I write in; DOC_LANG the language of the repository's docs, else English; INTEGRATION the repository's default branch (`origin/HEAD`, else main or master; ask if none); MERGE=local. Ask questions as ❓ **topic**: question, then ➡️ your recommendation, last in the message.

| Input | Harness file | Stand-ins to look for | Fallback |
|---|---|---|---|
| Requirements | docs/REQUIRE.md | a PRD, a spec, the README's feature list, issues | none: the request itself |
| Design and contracts | docs/SPEC.md, docs/DECISIONS.md | design docs, API descriptions, ADRs | the code |
| Task template | docs/tasks/_template.md | — | `templates/task.template.md` in the hm-setup skill folder (`../hm-setup/` from this skill's folder); read it there |
| Task states | `bash scripts/harness-state.sh status` | — | the task files in docs/tasks/ and the task/<id> branches |

Without the harness, this skill writes only the CR file and task files: it reads the stand-ins for the impact analysis but never edits them, skips the REQUIRE, SPEC and DECISIONS updates in step 4, and lists in the CR's Impact table what those docs would need. Tasks it writes start with "개발해: docs/tasks/<id>.md" or "Start Task <id>." (hm-dev).

## Preconditions
- Read .harness/config, AGENTS.md, the requirements, the design sections the request touches, the task template and the task states (Inputs).
- Where you commit is clean (see "Commit").

## 1. Record the request
Take the next free CR number across docs/changes/ (on INTEGRATION and on any `change/*` branch) and write docs/changes/CR-<n>.md:

~~~markdown
# CR-<n>: <title>
- Date: YYYY-MM-DD
- Kind: feature | change | bug | removal | non-functional | security | chore | spike | docs | split
- Source: user chat | demo of Task <id> | issue <key> | file <path> | security review docs/security/review-<k>.md
- Status: Proposed

## Request
(verbatim)

## Impact
| Item (R-xx/AC-n, DR-xx, NFR-xx, SPEC §, Task <id>, code area) | Now | After | Action |

## Clarifications
(Q-<k> and Term lines from step 3; "none" if the request was clear)

## Decisions
(D-xx entries, if any)

## Tasks
| Task | Title | Type | Requirements | Depends on | Review | New / Changed / Dropped |
~~~

Kinds:
- feature: new behavior. New R-xx with ACs, SPEC entries, new task(s).
- change: an existing AC, rule or contract changes. Edit it in place, new task(s) for the code.
- bug: an existing AC says X, the product does Y. No requirement change unless the AC was missing or wrong. One task whose first test reproduces the bug.
- removal: a requirement goes away. Move it to REQUIRE Out of scope; Todo tasks that only served it become Dropped; code removal is a task.
- non-functional: a new or changed NFR with a number; SPEC §10 and the DoD of the affected task(s).
- chore: technical work with no requirement change (refactor, dependency upgrade, tooling, infrastructure, test cleanup). No REQUIRE change; one or more `Type: chore` tasks with "Done when" bullets.
- spike: an open question to answer before deciding (feasibility, which library, why it is slow). One `Type: spike` task whose Findings recommend an answer; acting on it is a later CR.
- docs: documentation only. One `Type: docs` task.
- security: the findings and improvements of a security review (hm-security), or a security requirement I add. Request: the review file path, not its copied text.
  - Each open finding becomes a `Type: bug` task, `Review: each`, whose first test is the finding's reproducing test. Related findings with one fix may share a task. Critical and High: always a task, depending on nothing it does not need, so it can start first. Medium: a task by default. Low: a task or an accepted risk, my choice.
  - Each improvement becomes a task (chore for tooling and hardening with no behavior change, feature when users see it), an accepted risk, or nothing, my choice.
  - A missing or changed security requirement goes into REQUIRE §10 as SEC-xx; a missing or changed control into SPEC §12. The tasks list the SEC-xx in Requirements.
  - An accepted risk is a D-xx: the finding, why it is accepted, until when, and who decided. Never accept a Critical without asking twice.
  - In the review file, set each finding's `- Status:` to `Task <id>` or `Accepted risk (D-xx)`, in the same commit.
- split: a task is too big (e.g. it hit MAX_CONTINUE). Todo: replace it with smaller tasks (old one Dropped). In Progress: do not edit its branch. Read its task file on task/<id> (Log, Notes for Next Session, the tests that pass) to see what is finished; the finished ACs stay in that task, every other AC moves to new tasks that depend on it. Write the new task files on INTEGRATION as usual, and tell me the line to give the owner session next ("Continue Task <id>." with the ACs it keeps); that session narrows the task file's Acceptance criteria and Tests to those ACs, notes `Split by CR-<n>` in its Log, and finishes.

## 2. Analyse impact
- Find every R-xx/AC, DR-xx, NFR-xx, SPEC section (including §4c contracts between components and §2 components), task file and code area the request touches. Read the code where needed; do not guess.
- Tasks by status:
  - Todo: update its acceptance criteria, scope and tests in place; add "Changed by CR-<n>" to its Log.
  - In Progress or In Review: do not edit its branch. Default: let it finish and add a follow-up task that depends on it. If the change makes the work wrong, say so and propose Dropped plus a new task; I decide.
  - Done: never reopen. Add a new task.
  - No longer needed: Status `Dropped`, with the CR in its Log.
- Contract changes (SPEC §3, §4), new components, and new dependencies are decisions: write them in the hm-setup D-xx format, with a citation.
- Behavior that already shipped (Done tasks, or GREENFIELD=0 code) changes only behind a regression or characterization test written first; say which in the task.

## 3. Clarify, then confirm
Clarify first when the request is not yet clear enough to write ACs or "Done when" bullets with concrete values: it can be read more than one way, it gives no values or examples, it contradicts REQUIRE.md, a DR-xx, the Glossary or shipped behavior, or it is large (more than one new R-xx, or a contract change). Otherwise skip to the confirmation.

Question format (every question in this skill, including D-xx in the confirmation):

~~~
❓ **Q-2 — Missing transfer time**: May a **common default transfer time** apply between same-name stations, and if so, how many seconds? `Yesol` and `Geumbit` share a name, but the data gives no walking time between them.

➡️ Allow transfers between same-name stations and apply a common default time confirmed by the owner: REQUIRE `DR-04` already treats them as one station.
~~~

- First line: ❓, the ID (Q-<k> or D-xx) and a short topic in bold, a colon, then the question and its context in one to three sentences in CHAT_LANG. Bold the phrase the decision hinges on; names, values, paths and IDs in code spans.
- Question first: the sentence ending in `?` comes right after the colon; the reason, evidence, counts and examples follow it, never before it. Bad: "5 pairs of segments have two records ... Should we use only the newest?" Good: "Should we use only the newest record? For example, `S201→S202` has 266 s from 2025 and 176 s from 2026."
- Options, if any, one line each between the question and the recommendation: `A) ...`, `B) ...`. Each option says in plain words what will happen and what I gain or give up; keys or technical names only in parentheses after that.
- Blank line, then ➡️ and your recommended answer with one line on why. Every question has one; if you cannot recommend, say what you would need to know and recommend the safest choice meanwhile.
- Only Markdown bold and code spans for emphasis; no HTML, no color codes.
- Questions always come last in the message. Findings, explanations and tables go first; nothing follows the last ➡️ line.

Clarifying, in rounds:
- A round is the **frontier**: every open question whose answer does not wait on another open question, in one message, at most 5, highest impact first, each numbered in the format above. Word each one so that "yes" accepts the recommendation; I may answer by number ("1 yes, 2 B").
- Never ask what REQUIRE.md, SPEC.md, the code or the data can answer. Look it up and state what you found with its evidence.
- The follow-ups an answer opened (dependent decisions, implied edge cases) lead the next round.
- If an answer contradicts REQUIRE.md, a DR-xx, a Done task's behavior or an earlier answer, say so with the evidence and ask which one wins. If it is vague, ask for a concrete value or example.
- Use the REQUIRE §9 Glossary terms. A new or ambiguous domain word gets pinned (term, definition, replaced words, example).
- After every answer, append to the CR's `## Clarifications` section: `- Q-<k>: <question> → <answer> → <resulting decision>`, or `- Term: <term> = <definition> (not: <replaced words>)`.
- Stop when nothing that changes the ACs, tasks or contracts is ambiguous. "추천대로" / "as recommended" adopts the recommendation; "나머지 추천대로" / "rest: recommended" or "그만" / "stop" adopts the rest as [ASSUMPTION]. Grill mode ("끝까지 파고들어", "grill me") also asks Low-impact questions until nothing is ambiguous or I say stop.

Then confirm in one message in CHAT_LANG, in this order: the request as you understood it, the Impact table (updated with what clarifying changed), the proposed tasks (ID, title, type, depends on, review policy, which can run in parallel), and last the D-xx questions and the confirmation question.
For a small change (one R-xx, no contract change, no D-xx), a one-line confirmation is enough.
Do not write anything beyond docs/changes/CR-<n>.md (Status: Proposed) until I reply. Accepting your recommendation (e.g. "추천대로", "as recommended") accepts everything.
If I reject it: Status Rejected with my reason, commit, stop.

## 4. Apply
- REQUIRE.md: new R-xx take the next free number; never renumber or reuse an ID. A changed AC is edited in place with `(changed by CR-<n>)` at the end of the line; its old wording goes into the CR Impact "Now" column. Removed requirements move to Out of scope with "CR-<n>" as the reason. The Source of a new R-xx is `CR-<n>`.
- Glossary (REQUIRE §9): add the pinned terms with `CR-<n>` as the source; a changed definition is edited in place with `(changed by CR-<n>)`. Older REQUIRE.md files without §9 get it appended.
- DECISIONS.md: append D-xx with the next free number, Status Accepted or Default, Context citing CR-<n>.
- SPEC.md: update the sections; keep the numbering; each new §4 entry or §5 screen lists its Requirements.
- Tasks: create `docs/tasks/<id>.md` from the task template (Inputs) with `- Source: CR-<n>`. Without REQUIRE.md, a task's acceptance criteria carry their own IDs `T<id>/AC-<n>`, and `- Requirements:` names the stand-in's sections or `none`.
  - ID: the next free number, or the repo's existing ID scheme (e.g. issue keys).
  - Size: one session (rough guide: at most about 3 R-xx or 8 ACs). Split bigger ones.
  - Type: feature for feature, change and non-functional; bug for bug and for security findings; chore, spike or docs for those kinds; removal is a chore unless users see the change (then feature). A split keeps the type of the task it splits.
  - Review: `each` only for a one-way door (a migration that drops, narrows or rewrites stored data; sign-in, credentials or access control; a contract something outside the repository relies on), `batch` for the rest.
  - Depends on: the tasks whose code it builds on. When PARALLEL > 1, also tasks that will edit the same files.
  - Prefactor first: when the change is easier after a refactor, that refactor is its own `chore` task, and the change depends on it.
  - A wide change (one mechanical change whose blast radius fans across the codebase: renaming a column, retyping a shared symbol, swapping a library used everywhere) goes as expand–contract, each step a `chore` task that leaves `test` and `e2e` green: expand (add the new form beside the old one) → migrate the callers in batches sized by blast radius (per component or folder; one task each, depending on the expand task, able to run in parallel) → contract (delete the old form, depending on every migrate task).
  - feature and bug: acceptance criteria with full AC IDs, demo scenario, tests table, as in the template. An R-xx whose acceptance criteria in REQUIRE.md still say `when tasked` gets them written there now (clarify open values first, as in step 3). chore, spike, docs: "Done when" bullets; no demo scenario.
- Check traceability for what changed: every new or changed Must AC appears in a Todo task; every new interface entry belongs to a task; Depends on has no cycles.
- CR: Status Accepted; fill the Tasks table.

## Commit
- MERGE=local: commit on INTEGRATION in the main worktree: `docs(cr-<n>): <title>`. With WORKTREES=0 and the main worktree on a task branch: if it is clean, switch to INTEGRATION, commit, and switch back; if it is not clean, stop and tell me.
- MERGE=pr: `git fetch <REMOTE>`, branch `change/CR-<n>` from `<REMOTE>/<INTEGRATION>`, commit, `git push -u <REMOTE> change/CR-<n>`, and tell me to open a pull request. The new tasks become visible to the script once it is merged.
- If REQUIRE.md or DECISIONS.md conflict with another change merged meanwhile, renumber only the IDs this CR added.
- Without the harness: commit on the current branch if the tree is clean (say which branch); if it is not clean, stop and tell me.

## Finish
Report in CHAT_LANG: the CR file, changed requirements, new / changed / dropped tasks with their dependencies, which tasks can start now, and the next step ("Start Task <id>.", or run automatically with hm-auto).
Then stop.
