---
name: hm-explain
description: 'Step 6 of the harness flow, after development is done. Use for "설명 문서 만들어", "EXPLAIN 정리해", "Explain the project." (also without the harness). Reads the code on the integration branch with the requirements, decisions, design and task records, and writes docs/EXPLAIN.md in the chat language: the overall flow, architecture, core business logic, data model, a module map, the key decisions with their alternatives, quality evidence, limits, and expected questions with answers (how each requirement was built and why, why the code is shaped as it is, how data flows). Explains what was built, checked against the code; every reason cites its record.'
argument-hint: '"설명 문서 만들어" | "EXPLAIN 정리해" | "Explain the project."'
---

# Harness Step 6: Explain the built system

Talk to me in CHAT_LANG and write docs/EXPLAIN.md in CHAT_LANG too (from .harness/config; Korean if unset): it is written for me and for the people I present the project to. Code, identifiers, file paths and IDs (R-xx, D-xx, DQ-n) stay as they are.

## Inputs
With the harness: AGENTS.md first, then the code on INTEGRATION, docs/REQUIRE.md, the `✅ 결정` lines of docs/QUESTION.md, docs/DECISIONS.md, docs/SPEC.md, docs/tasks/ (Decisions during development, Issues found), docs/changes/, and, when they exist, docs/TRACEABILITY.md, docs/LOAD_TEST.md, the latest docs/security/review-<k>.md and the latest `artifacts/runs/*/final-check.md`.
Without the harness (no .harness/config): read references/no-harness.md and references/inputs.md in this skill's folder first; the latter says what stands in for each input.

## Preconditions
- Explain what is merged: the main worktree at the head of INTEGRATION (MERGE=pr: a temporary detached worktree at `<REMOTE>/<INTEGRATION>` after `git fetch`). Uncommitted changes: tell me and stop.
- `bash scripts/harness-state.sh status`: if a task is not Done or Dropped, list those tasks and ask once whether to explain the merged state now (the open tasks then appear under Limits) or wait.
- Read-only except docs/EXPLAIN.md. Run nothing that changes data; the tests may run (step 1).

## Rules
- The code is the truth. Every statement about structure or behavior is checked in the code and names where it lives (`path/to/file`, the function or module). Where the code differs from SPEC or DECISIONS, say so under "설계와 다른 점" (Differences from the design) and describe the code.
- A reason cites its record: an R-xx, DR-xx, NFR-xx or SEC-xx, a D-xx, a task's DQ-n, a CR-n, a review finding. When no record gives the reason, write `기록된 이유 없음` (English: `no recorded reason`) and, if the code makes the trade-off visible, add what it shows, marked as read from the code. Never invent a reason or an alternative nobody considered: alternatives come from D-xx "Alternatives considered", the options of the design questions, or a DQ.
- Plain words first, then the detail: each section opens with one or two sentences a non-developer can follow, then the specifics.
- Short and complete over long: one entry per component, computation, module and decision, no restated requirement text (cite the ID and say it in a few words), no code listings beyond a short signature or schema where it states something more precisely than prose.
- Diagrams are text: plain text boxes and arrows, or Mermaid if the repository's docs already use it.

## Steps
1. Run `bash scripts/hm.sh test` and `bash scripts/hm.sh e2e` once for the counts in section 8 (do not stop on a failure: report it there). Without the harness: the repository's test commands, or skip and say so.
2. Read the inputs, then the code: the entry points first (the components in SPEC §2, the routes or commands, the job or worker entry), then follow each main scenario through the layers. Map each top-level folder and module to its role.
3. Write docs/EXPLAIN.md in the format below, in parts of at most about 20 KB each (the long-files rule). The headings below are the Korean form; in another CHAT_LANG translate them and keep the numbering.
4. Check before committing: every R-xx Must appears in section 2, 4 or 10; every Accepted D-xx in section 7; every SPEC §6 computation in section 4; every path the document names exists.
5. Commit docs/EXPLAIN.md alone: `docs: explain the system` (MERGE=pr: on a branch `docs/explain-<date>`, pushed for a pull request). Without the harness: leave it uncommitted and tell me where it is. Running again later replaces the file; the commit history keeps the old one.

## docs/EXPLAIN.md

~~~markdown
# <product name>: 설명서
Explained commit <sha>, <date>. Sources: <the inputs that existed>.

## 1. 한눈에
(3–5 lines: what it does, for whom, the main constraint, the one scenario that matters most)

## 2. 전체 흐름
(each main scenario as a text diagram from the user's action to the stored or shown result: screen or command → API → service → computation → storage, with what is checked or transformed at each arrow; then one line per scenario on where it starts in the code)

## 3. 아키텍처
(the components and how they talk, as a diagram; per component: what it owns, how it starts, why it is separate or not (D-xx))

## 4. 핵심 비즈니스 로직
### <computation or rule>: <approach>
- 무엇을: (the result it produces, R-xx / DR-xx)
- 어떻게: (the model and algorithm in plain steps, how each domain rule enters)
- 왜: (D-xx, DQ-n; the alternatives and why they lost)
- 한계: (SPEC §6 Reach and Quality: what it never changes, how good the result is, against what)
- 코드 위치: (paths, functions); 확인하는 테스트: (test names)

## 5. 데이터 모델
(the main entities and relations as a small diagram or table; the rules the schema enforces; values that carry a decision: money, time, derived fields)

## 6. 모듈 지도
| 모듈·폴더 | 역할 | 주요 파일 | 의존하는 것 | 왜 이렇게 나눴나 |

## 7. 주요 결정
| D-xx | 결정 | 이유 | 포기한 대안과 그 대가 |

## 8. 품질 근거
(test counts from step 1, e2e, the load and benchmark results against SPEC §10, the latest security review verdict, the final check's Behavior and Targets lines; "not measured" where nothing measured it)

## 9. 한계와 알려진 문제
(open Issues found, targets not measured or missed, tasks not done, 설계와 다른 점)

## 10. 예상 질문과 답
### Q1. ★ <question>
<answer>
~~~

## Expected questions (section 10)
Questions a reviewer, interviewer or judge would ask about this product, each with an answer grounded like the rest of the document. Shape every question on one of these patterns, in CHAT_LANG:
- Requirement to implementation: "<R-xx in a few words>을 어떻게 구현했고, 왜 그렇게 했나요? 대안인 <alternative>에 비해 어떤 점에서 이득인가요?"
- Code as it is: "<module or component>은 <how it is built> 식으로 개발되어 있는데, 이렇게 한 이유가 무엇인가요?"
- Data flow: "<scenario>에서 데이터는 어떤 경로로 흐르나요? 각 단계에서 무엇이 검증되고 저장되나요?" and its variants: where a value is computed, what happens to stored results when the input changes, what is read while a computation runs.
- Failure and limits: what happens on invalid input, a concurrent write, a dependent component down, a load beyond the target; what the algorithm can never reach.

Cover, one question at least each: every Must R-xx, every Accepted D-xx that has alternatives, every SPEC §6 computation, every main scenario's data flow, and each component boundary; then the failure and limit questions that apply. Mark with ★ the ones most likely to be asked (core logic, the hardest trade-offs, the main data flow). Order: ★ first, then by section order.
Each answer: the direct answer in one or two sentences, then how it is built (paths), why (the records), the alternative and what it would have cost or gained, and the limit, if any. An answer with no record for its "why" says so, as in Rules.

## End
Report in CHAT_LANG: the path of docs/EXPLAIN.md and the commit, the section sizes in one line, the number of questions (★ count), the differences from the design found, and the statements left `기록된 이유 없음`. Then the next step as plain text: none is required; to change a fact in the product, "수정 요청: ..." (hm-change); to explain again after more merges, "설명 문서 만들어" (hm-explain).
