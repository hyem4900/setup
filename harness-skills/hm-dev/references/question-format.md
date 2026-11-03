# Question format (shared by the harness skills)

Source: `harness-skills/_shared/question-format.md`. Do not edit the copy under `references/`; edit the source and run `harness-skills/sync-shared.sh`. In a project with AGENTS.md, its "Ask the user when" section carries the same format; this file is for the skills that run before AGENTS.md exists or without the harness.

Every question to the user, in CHAT_LANG, in exactly this layout:

~~~
<mark> **<ID> — <short topic>**
❓<the question>? <for a broad question: concrete example aspects, and a request to answer all of them. For a narrow one: a concrete reading to confirm, if you have one>

🔍 <what you checked and found>
A) <option>   (only if there are options)
B) <option>

➡️ <"Recommended" in CHAT_LANG>: <your recommendation>. <one sentence on why>
~~~

Example (CHAT_LANG Korean, one round). Copy its layout exactly, and follow it for the level of the questions and the split between the question and 🔍:

~~~
🔴 **Q1 — 대상자 선정**
❓어떤 직원을 통근버스 대상자로 삼을까요? 대상 재직 상태, 출근으로 인정할 시간대, 20일 중 최소 출근 일수 등 대상자를 판정하는 모든 기준을 알려주세요.

🔍 `employees.csv`의 `status`에 재직 412명, 휴직 23명, 퇴사 9명. README에는 대상자 기준이 없음.

➡️ 권장: 재직만 통근버스 대상자로 삼습니다. 휴직·퇴사자는 출근하지 않으니 제외합니다.

🟡 **Q2 — 자정 넘은 출입 기록**
❓23:59를 넘는 시각 표시는 어떻게 처리할까요? 다음 날 새벽으로 해석하면 될까요?

🔍 `attendance.csv`에 24시 이상 기록 29건(최대 `28:40`). 모두 야간조 직원.

➡️ 권장: 다음 날 새벽으로 해석하고 전날 근무에 포함합니다. 야간 교대 기록 방식으로 보입니다.

🟡 **Q3 — 집 좌표 없는 직원**
❓집 좌표가 없는 직원은 어떻게 처리할까요?

🔍 `employees.csv`에서 `home_latitude`·`home_longitude`가 빈 직원 5명.

➡️ 권장: 집 좌표가 없는 직원은 노선 계산에서 제외하고, 운영자 페이지에서만 별도 목록으로 보여줍니다. 좌표를 추정하면 노선이 틀어질 수 있습니다.
~~~

- Title line: the mark, a space, then in bold the ID, an em dash and a short topic. Nothing else on that line.
  - Mark: the question's impact. 🔴 High, 🟡 Med, ⚪ Low (Low questions are asked only in grill mode). A question without an impact rating (a D-xx decision, a choice before the requirements exist, a question during development) has no mark: the line starts with the bold ID.
  - ID: a requirements question `Q1` (older projects: `Q-01`), a decision `D-01`, or the number in a round.
- Question line: ❓ directly followed by the question, at the level the owner thinks about the decision ("어떤 직원을 대상자로 삼을까요?"), not one detail of it ("최소 출근 일수는 15일인가요?"): a question narrowed to the answer you expect shrinks what the owner tells you.
  - A broad question (most High ones) must not stay abstract, or the owner answers only part of it. In the same line, name concrete example aspects and ask for all of them: "대상 재직 상태, 출근으로 인정할 시간대, 20일 중 최소 출근 일수 등 대상자를 판정하는 모든 기준을 알려주세요." The examples show the depth of answer you need; "등" and "모든" keep the rest open.
  - A narrow question (one edge case, most Med ones): the question, then the concrete reading you would apply, to confirm ("다음 날 새벽으로 해석하면 될까요?"), if you have one.
  - One decision per question: an aspect with its own data or its own edge case is its own question (above, the hour-28 records are Q2, not part of Q1). No evidence on this line.
- Blank line, then 🔍: the data behind the question, what you checked and found: files and columns in code spans, counts, example values, or that the sources say nothing about it ("README에는 대상자 기준이 없음"). No aspects to settle (they are on the question line) and no recommendation.
- If there are options, list them right after 🔍, one line each: `A) ...`, `B) ...`. Each option says in plain words what will happen and what the user gains or gives up; config keys or technical names only in parentheses after that. Never present an option as only `KEY=value` pairs.
- Blank line, then ➡️ and the recommendation, labeled "Recommended" in CHAT_LANG (Korean: `권장:`), followed by one sentence giving its reason: the evidence or what goes wrong otherwise. Every question has one. If you cannot recommend, say what you would need to know, and recommend the safest choice meanwhile. For a broad question, recommend what you can and say which aspects need the owner's values.
- A blank line between questions. Names, values, file paths and IDs from the project go in code spans. Use only Markdown bold and code spans for emphasis (clients render them in accent colors); no HTML, no color codes.
- Questions always come last in the message. Findings, explanations, tables and summaries go first; nothing follows the last ➡️ line.
- Several questions: ask in **rounds**. A round is the frontier: every open question whose answer does not wait on another open question, in one message, highest impact first, at most 5. The user may answer in their own words, by number ("1 추천대로, 2 B") or all at once ("all as recommended" / "전부 추천대로"); "추천대로" / "as recommended" adopts the recommendation. Follow-ups an answer opens lead the next round.
