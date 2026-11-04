# Harness: Interview procedure (part of hm-req)

Read this before writing docs/QUESTION.md (Step 2) and follow it through the interview (Step 3). The question format (references/question-format.md) applies to every question here.

Question list (docs/QUESTION.md):
Every question lives in docs/QUESTION.md as a block I can answer by editing the file; REQUIRE.md holds no questions, only a `[Q<n>]` marker at each open point. Start the file from `templates/QUESTION.template.md`. IDs are `Q1`, `Q2`, … (older projects: `Q-01`); `Q-xx` below means such an ID. Write every block in CHAT_LANG in exactly this layout (labels too: 권장 / 답변 / 결정 in Korean, Recommended / Answer / Decision in English):

~~~markdown
## 🔴 **Q1 — 대상자 선정**
❓어떤 직원을 통근버스 대상자로 삼을까요? 대상 재직 상태, 출근으로 인정할 시간대, 20일 중 최소 출근 일수 등 대상자를 판정하는 모든 기준을 알려주세요.

🔍 `employees.csv`의 `status`에 재직 412명, 휴직 23명, 퇴사 9명. README에는 대상자 기준이 없음.

➡️ 권장: 재직만 통근버스 대상자로 삼습니다. 휴직·퇴사자는 출근하지 않으니 제외합니다.

🅰️ 답변:
```

```

✅ 결정:
~~~

- Heading: `## `, the impact mark (🔴 High, 🟡 Med, ⚪ Low), then in bold the ID, an em dash and the topic; a follow-up adds `(follow-up of Q<n>)` after the topic, inside the bold. Then the question exactly as in the question format: the ❓ line (with its examples and request to answer all, for a broad question), 🔍, options if any, ➡️ with its reason.
- Then `🅰️ 답변:` with an empty code block below it, a blank line, and `✅ 결정:` left empty. A blank line between blocks.
- My answer is the text inside the code block. An empty block is unanswered. If I write on the `🅰️ 답변:` line or below the block instead, take that as my answer too. "추천대로" / "as recommended" / "rec" adopts the recommendation; for options, the letter is enough.
- No list of the requirements a question affects: the `[Q<n>]` markers in REQUIRE.md are the only link. Every open question has at least one marker there; one that may add a requirement puts it in §1.
- Open blocks come first, highest impact first; decided blocks follow in ID order. IDs are never renumbered or reused.
- Impact is the effect of the answer, whichever category the question came from:
  - High: it changes the core result in most cases, or the structure or a stored format. A wrong guess means rework across tasks.
  - Med: it changes the result or behavior in some cases: an edge case, a boundary, a rare or invalid input. A wrong guess means some code and tests.
  - Low: the result stays the same; only presentation or a convenience changes (a display format, a wording, a default the user can change). A wrong guess takes minutes to fix.
  - Between Med and Low, ask: would the expected value of any test change? If yes, it is Med.
- The list holds every High and Med question, and every one is asked; there is no count limit, in either mode. A Low question is not listed: apply its recommendation as a proposed default (REQUIRE §7, Status `proposed`, evidence `Low: <why the result stays the same>`), so I confirm it with the other defaults. Grill mode lists and asks Low questions too.

Deciding a block (see "Recording"): write the decision after `✅ 결정:`, based on my answer in the code block; then apply it to REQUIRE.md. The rest of the block stays as it is: the heading, ❓, 🔍, options, ➡️ and the code block with my answer as I wrote it. The decision is the rule; the ➡️ recommendation stays as the record of what was proposed, so whoever reads the file later follows `✅ 결정`, never `➡️ 권장`.

~~~markdown
## 🔴 **Q1 — 대상자 선정**
❓어떤 직원을 통근버스 대상자로 삼을까요? 대상 재직 상태, 출근으로 인정할 시간대, 20일 중 최소 출근 일수 등 대상자를 판정하는 모든 기준을 알려주세요.

🔍 `employees.csv`의 `status`에 재직 412명, 휴직 23명, 퇴사 9명. README에는 대상자 기준이 없음.

➡️ 권장: 재직만 통근버스 대상자로 삼습니다. 휴직·퇴사자는 출근하지 않으니 제외합니다.

🅰️ 답변:
```
(my answer, verbatim)
```

✅ 결정: 재직자만 대상. 날짜별 첫 유효 태그의 중앙값이 08:00 전이면 07:00조, 08:00 이상 11:00 전이면 09:00조, 그 외는 대상 아님. → DR-01
~~~

- The decision is in CHAT_LANG and reads on its own: what was decided, with the values, even when the answer was only "추천대로". It ends with `→` and where it was applied (DR-xx, R-xx/AC-n, §4).
- When I leave a point to you ("합리적으로 판단해서 적어 주세요"), decide it, write `✅ 결정 (위임):` (English: `Decision (delegated):`) and the decision, and apply it to REQUIRE once, like any decision. It is not an assumption: it does not go into §7.
- Never edit my answer text; if you need more, add a follow-up block.

Two ways to answer:
- After writing the draft, send one message: the R-xx count by priority, the number of questions by impact and the paths of REQUIRE.md and QUESTION.md, the proposed defaults as one table (ID, what is handled, how, evidence), and the two ways to answer: write my answers in the code blocks under 🅰️ in QUESTION.md and tell me (e.g. "답 적었어", "answered"), or answer here round by round. End the message with the first round: first the proposed defaults as a question (**Proposed defaults**, ❓ may all of them apply as listed, correcting any by its ID?), then the first frontier, so I can start right away.
- Proposed defaults: "OK" or the like sets them all to `confirmed`. A correction with a concrete value is applied and marked `changed by Q-<k>` (a new QUESTION.md block holding my answer); a correction that is unclear becomes an open question. A default you find later is applied the same way, `proposed`, and the summary check lists those still proposed.
- In chat: in **rounds**. A round is the **frontier**: every open question whose answer does not wait on another open question, at most 5, highest impact first, in the question format. The first round, in every mode, is instead the highest-impact question of each applicable coverage category (at most 5, one per category), so no category is left for the end; the frontier takes over from the second round. I may answer in my own words, by number ("1 추천대로, 2 B, 3: 15분") or all at once ("전부 추천대로"). Each chat answer is copied verbatim into its block's code block when its batch is applied (see "Recording"), so the file stays the one record.
- In the file: when I say I answered, re-read QUESTION.md and process every newly filled code block in order of impact, applying "Challenging" below to each. An answer that needs more gets a follow-up block (empty code block, empty decision); the others are recorded and applied (see "Recording"). Then send one message: how many were decided, the follow-ups added (ID and one line each), and how many are still open, and end with the next round in the question format. I may keep answering in either way.

Asking:
- Never ask what the sources can answer. Before each question, check REQ_SOURCES, the data (run a query or script) and, for GREENFIELD=0, the code. If they answer it with near certainty, it is a proposed default, not a question; ask only if the finding is surprising or changes scope.
- If REQ_SOURCES=INTERVIEW, start with: what it is, who uses it, the one scenario that must work.

Coverage categories (the check before writing QUESTION.md, Step 2, and again after the answers): five categories, each with the points to check inside it. Walk each point; if the sources or the data answer it, it is a proposed default; otherwise each open decision is its own question, rated like any other.
- Roles and access: the kinds of users; what each role may see and do; whether anyone may see or change another user's data; how users sign in.
- Screens (HAS_UI=1): which screens the product needs, and on each the information that must be visible and the actions a user can take there; what a user sees on an error. Ask it as an open question ("어떤 화면이 필요한가요? 화면마다 꼭 보여야 할 정보와 할 수 있는 동작을 알려 주세요"), with the screens the sources suggest in 🔍. Never ask about layout or look (applied after development). The answers become ACs of the R-xx they belong to ("screen X shows ..."), which SPEC §5 is built from.
- Business logic, walked for each Must separately (a product-wide pass misses rules that only one feature has):
  - who or what it applies to: eligibility conditions, exceptions, missing data, and which exclusion wins when several apply;
  - input constraints: format, empty, too long, duplicate, out of range, and constraints against other records (distance, location, overlap, uniqueness across records);
  - goal: what it optimizes, which rule wins when two conflict, what a good enough result is;
  - numbers and time: units, rounding and where it applies, limits, whether boundaries are included, time zone, day boundaries;
  - ties and ordering: which result wins when two are equal, the order of lists;
  - running again: what may change and what must stay when it runs again or its inputs change (overwrite, keep, keep history), and how that is measured.
  A count you derive from the data (e.g. "412 users eligible") is shown with its conditions and how many each condition excludes, so I confirm the rule, not only the number.
- Data: what is kept and for how long; history on change and delete; what is kept or rolled back on a failure; which data is sensitive or regulated (what may be logged, shown, exported); the lists and exports an operator needs (e.g. the people left unassigned and why); data volume and users now and later (feeds HAS_LOAD and the NFRs).
- Access and deployment: who uses it from where: a demo on my machine, inside a team, or on the public internet. The answer goes into REQUIRE §1 `Access:`; how and where it is deployed is decided in hm-setup.

Each applicable category gets at least one question. A High or Med question in it counts. If it has none, add one broad question for it (the question format's broad form, with examples), asked even when it would rate Low. A category that does not apply gets `N/A: <reason>` in the Coverage lines instead (e.g. `Screens: N/A: HAS_UI=0, CLI only`). The Coverage lines at the top of QUESTION.md list, per category, its question IDs or that N/A line; keep them current as questions are added.

Order (walk the decision tree):
- From the second round, each round is the frontier of QUESTION.md, highest impact first (the first round asks one question per coverage category).
- After each round, look for what the answers opened: follow-up questions, decisions that depend on them, edge cases they imply. Add each one to QUESTION.md as a follow-up block (and its `[Q<n>]` marker in REQUIRE.md); they lead the next round.
- When the frontier has nothing ambiguous left, walk the coverage categories again with the answers so far: an answer may have opened one (a new input, a new rule, a new state).
- Security: roles, sign-in and sensitive data are asked in their categories above. Ask nothing else on security in this step (attacks, scans and hardening belong to hm-security); the baseline SEC-xx rows are written without asking (SKILL.md Step 2).

Challenging:
- If an answer contradicts the sources, the data, the existing system or an earlier answer, say so with the evidence (file §, count, Q-xx) and ask which one wins. Do not silently record either.
- If an answer is vague ("fast", "many users", "the usual way", "handle errors properly"), ask for a concrete value or example: the number, the input and the expected output, the exact message.
- If a rule has an obvious edge case the answer did not cover (empty, duplicate, zero, limit, concurrent, permission denied), ask about it.

Terms:
- When a domain word is ambiguous, used with two meanings, or has synonyms in the sources ("member" vs "user" vs "account"), pin one term with a one-line definition, the words it replaces, and an example. Use the pinned term from then on.

Recording (QUESTION.md is the only log), in batches rather than after every answer:
- Keep the answers given in chat (question, answer, resulting decision) in a short pending list.
- Apply the pending batch after each round, when I say stop or "rest: recommended", and always before the summary check; then ask the next round in the same message. Answers I write in the file are applied the same way, all newly filled ones together.
- Applying a batch is one edit of each file. QUESTION.md: each block's answer (chat answers copied into the code block) and `✅ 결정:`, nothing else in the block changed; new follow-up blocks. REQUIRE.md: every `[Q<n>]` marker replaced with the decided value, without an [ASSUMPTION] tag (a decided value is no assumption; also delete the tag from any text the decision confirms), and the R-xx, ACs, DR-xx, NFRs or Out of scope rows added or changed, each rule written once where it belongs (SKILL.md Step 2), with `Source: Q-xx` on new items. Tell me in one line which questions it applied.
- A pinned term goes into the REQUIRE §9 Glossary with `Q-xx` as its source.
- A resolved contradiction keeps both sides and the winner in its decision line.

Answers and stopping:
- "추천대로" / "as recommended" adopts your recommendation for that question.
- "나머지 추천대로" or "rest: recommended" adopts the recommendation of every open question (empty code block, empty decision); write each as `✅ 결정 (나머지 권장):` (English: `Decision (rest: recommended):`) and apply it like any decision, without an [ASSUMPTION] tag; the summary check lists them. "그만" / "stop" does the same and goes to the summary.
- Stop when every listed question has a decision and no follow-up is open.
- Follow-ups take their own impact: a Low follow-up becomes a proposed default, not a question.
- Grill mode: if I ask you to dig to the end ("끝까지 파고들어", "grill me", "꼼꼼하게 물어봐"), list and ask Low-impact questions too, and continue until nothing is ambiguous or I say stop.
- If an answer changes the profile (e.g. no performance target → HAS_LOAD=0), update .harness/config and tell me.
- When the interview ends, no `[Q<n>]` marker is left in REQUIRE.md, no block in QUESTION.md has an empty `✅ 결정:`, and every Coverage line names a decided question or carries `N/A: <reason>`.

Summary check (when the interview ends; apply any pending batch first):
- Send one message in CHAT_LANG of at most about 15 lines: the scope in two lines, the core scenarios, the key domain rules with concrete values, the pinned terms, the decisions taken as delegated or by "rest: recommended", and what is still [ASSUMPTION] (proposed defaults, unconfirmed numbers, security baseline rows). End it with the question asking me to confirm or correct.
- A correction is a new Q-xx: follow it as above, apply it, then show the summary again.
- When I confirm, clean up REQUIRE.md in one edit: §7 Status `proposed` → `confirmed`; delete every [ASSUMPTION] tag still left and every provenance note in the text ("delegated by Q-05", "(Q-01/Q-08)"), since `Source:` lines and QUESTION.md keep the provenance; the status line becomes `Status: Confirmed <date>`. Then REQUIRE.md is done.
