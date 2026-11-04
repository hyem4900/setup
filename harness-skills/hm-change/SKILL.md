---
name: hm-change
description: 'Turns a new or changed requirement after setup (without the harness: a change record and task files only) into a change record, updated REQUIRE, SPEC and DECISIONS, and new or dropped tasks: a feature, a change, a bug, demo feedback, a removal, technical work, a spike, docs, security findings or a task split. Use when the user says "요구사항 추가해: ...", "요구사항 변경해: ...", "버그 등록해: ...", "수정 요청: ...", "보안 리뷰 반영해: <file>", "Task N 나눠줘".'
argument-hint: '"요구사항 추가해: ..." | "요구사항 변경해: ..." | "버그 등록해: ..." | "Task <id> 나눠줘"'
---

# Harness: Change request

Talk to me in CHAT_LANG and write documents in DOC_LANG (both in .harness/config; Korean and English if unset). Code, identifiers and the fixed tokens scripts parse stay in English.
Never modify paths in PROTECTED. Do not write product code: this skill changes docs and task files only.

## Inputs
With the harness: docs/REQUIRE.md, docs/SPEC.md and docs/DECISIONS.md, the task template docs/tasks/_template.md, `bash scripts/harness-state.sh status`.
Without the harness (no .harness/config): read references/no-harness.md and references/inputs.md in this skill's folder first; the latter says what stands in for each of those and what this skill then writes and leaves alone.

## Preconditions
- Read .harness/config, AGENTS.md, the requirements, the design sections the request touches, the task template and the task states (Inputs).
- Where you commit is clean (see "Commit").

## 1. Record the request
Take the next free CR number across docs/changes/ (on INTEGRATION and on any `change/*` branch) and write docs/changes/CR-<n>.md. Several requests in one message (e.g. collected by hm-auto during a run): one CR for all of them, its Request listing each one verbatim with its source, and as few new tasks as fit (one if they fit in one), numbered from the next free task ID; a request of a different Kind that cannot share a task gets its own CR.

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

Question format (every question in this skill, including D-xx in the confirmation): references/question-format.md in this skill's folder, or the same format in AGENTS.md "Ask the user when".

Clarifying, in rounds:
- A round is the **frontier**: every open question whose answer does not wait on another open question, in one message, at most 5, highest impact first, each numbered in the format above. I may answer in my own words or by number ("1 추천대로, 2 B").
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
Report in CHAT_LANG: the CR file, changed requirements, new / changed / dropped tasks with their dependencies, which tasks can start now, and the next step (hm-dev, "Start Task <id>.", or hm-auto, "자동으로 진행해").
Then stop.
