# Harness: Interview procedure (part of hm-req)

Read this before writing REQUIRE §11 (Step 2) and follow it through the interview (Step 3). The question format in SKILL.md applies to every question here.

Question list (REQUIRE §11):
Every question also lives in REQUIRE §11 as a block I can answer by editing the file. Write the blocks in CHAT_LANG (I answer them), with the field names in English:

~~~markdown
### Q-08 (High) — Missing transfer time
May a **common default transfer time** apply between same-name stations, and if so, how many seconds?
- Why: `Yesol` and `Geumbit` share a name, but the data gives no walking time between them (§4).
- Affects: R-03/AC-2, DR-02 (where the `[Q-08]` marker sits)
- Options: A) one default time for every pair / B) a time per pair, entered by the operator   (only if there are options)
- Recommended: A, with a value the owner confirms: the sources treat same-name stations as one station everywhere else.
- answer:
~~~

- The heading holds the ID, the impact (High, Med, Low), and `follow-up of Q-xx` or `optional` when they apply. The first line is the question, question first, as in the chat format; `- Why:` holds the reason, evidence and examples.
- `- answer:` stays empty for me. I may answer on that line or on indented lines below it. "추천대로" / "as recommended" / "rec" adopts the recommendation; for options, the letter is enough.
- When you process an answer, add `- decision: <resulting decision>` below it. Never edit my answer text; if you need more, add a follow-up block.
- The list holds every High and Med question. If it holds more than the mode's default count, mark the lower-impact ones beyond it `optional`: left blank, they adopt the recommendation as [ASSUMPTION] when the interview ends. Low questions are listed only in grill mode.

Two ways to answer:
- After writing the draft, send one message: the R-xx count by priority, the number of questions by impact and the file path, the proposed defaults as one table (ID, what is handled, how, evidence), and the two ways to answer: edit the `- answer:` lines and tell me (e.g. "답 적었어", "answered"), or answer here round by round. End the message with the first round in the chat format: first ❓ **Proposed defaults**: may all of them apply as listed (correct any by its ID)?, then the first frontier, so I can start right away.
- Proposed defaults: "OK" or the like sets them all to `confirmed`. A correction with a concrete value is applied and marked `changed by Q-<k>` (a new §11 block holding my answer); a correction that is unclear becomes an open question. A default you find later is applied the same way, `proposed`, and the summary check lists those still proposed.
- In chat: in **rounds**. A round is the **frontier**: every open question whose answer does not wait on another open question, at most 5, highest impact first, numbered in the format above. Word each one so that "yes" accepts the recommendation; I may answer by number ("1 추천대로, 2 B, 3: 15분") or all at once ("전부 추천대로"). Each chat answer is written into its `- answer:` line when its batch is applied (see "Recording"), so the file stays the one record.
- In the file: when I say I answered, re-read §11 and process every newly filled answer in order of impact, applying "Challenging" below to each. An answer that needs more gets a follow-up block (empty answer, no decision yet); the others are recorded and applied (see "Recording"). Then send one message: how many were decided, the follow-ups added (ID and one line each), and how many are still open, and end with the next round in the chat format. I may keep answering in either way.

Asking:
- Never ask what the sources can answer. Before each question, check REQ_SOURCES, the data (run a query or script) and, for GREENFIELD=0, the code. If they answer it with near certainty, it is a proposed default, not a question; ask only if the finding is surprising or changes scope.
- If REQ_SOURCES=INTERVIEW, start with: what it is, who uses it, the one scenario that must work.

Order (walk the decision tree):
- Each round is the frontier of REQUIRE §11, highest impact first.
- After each round, look for what the answers opened: follow-up questions, decisions that depend on them, edge cases they imply. Add each one to REQUIRE §11 as a `follow-up of Q-xx` block; they lead the next round.
- When the frontier has nothing ambiguous left, cover whatever is still missing among:
  user types, core scenarios, domain rules, edge cases, interface (screens / API / CLI / events between components), performance expectations, security and privacy (see below).
- Security and privacy: keep it short; the full security review comes later (hm-security). Ask at most one combined question, in plain words: who may see or change whose data, how users sign in, and which data is sensitive or regulated. Mark it `optional` unless the sources or my answers mention payment, health, minors, other systems' credentials or a compliance rule. Skip it entirely when it does not apply (a local CLI with no users and no network); say so in one line. Never spend more than this question and its follow-ups on security in this step.

Challenging:
- If an answer contradicts the sources, the data, the existing system or an earlier answer, say so with the evidence (file §, count, Q-xx) and ask which one wins. Do not silently record either.
- If an answer is vague ("fast", "many users", "the usual way", "handle errors properly"), ask for a concrete value or example: the number, the input and the expected output, the exact message.
- If a rule has an obvious edge case the answer did not cover (empty, duplicate, zero, limit, concurrent, permission denied), ask about it.

Terms:
- When a domain word is ambiguous, used with two meanings, or has synonyms in the sources ("member" vs "user" vs "account"), pin one term with a one-line definition, the words it replaces, and an example. Use the pinned term from then on.

Recording (the §11 blocks are the only log), in batches rather than after every answer:
- Keep the answers given in chat (question, answer, resulting decision) in a short pending list.
- Apply the pending batch after each round, when I say stop or "rest: recommended", and always before the summary check; then ask the next round in the same message. Answers I write in the file are applied the same way, all newly filled ones together.
- Applying a batch is one edit of REQUIRE.md: each block's `- answer:` (chat answers) and `- decision:` lines, every `[Q-xx]` marker replaced with the decided value, and the R-xx, ACs, DR-xx, NFRs or Out of scope rows added or changed (`Source: Q-xx` for new ones). New follow-up blocks go in with the same edit. Tell me in one line which questions it applied.
- A pinned term goes into the §9 Glossary with `Q-xx` as its source.
- A resolved contradiction keeps both sides and the winner in its decision line.

Answers and stopping:
- "추천대로" / "as recommended" adopts your recommendation for that question.
- "나머지 추천대로" or "rest: recommended" adopts the recommendation of every open question (blank answer, no decision) and writes each decision as [ASSUMPTION]. "그만" / "stop" does the same and goes to the summary.
- Stop when every question that is not `optional` has a decision and no follow-up is open. Blank `optional` questions then adopt their recommendation as [ASSUMPTION].
- Follow-ups are never `optional` when their parent is High; otherwise they take their own impact.
- Grill mode: if I ask you to dig to the end ("끝까지 파고들어", "grill me", "꼼꼼하게 물어봐"), list Low-impact questions too, mark nothing `optional`, and continue until nothing is ambiguous or I say stop.
- If an answer changes the profile (e.g. no performance target → HAS_LOAD=0), update .harness/config and tell me.
- When the interview ends, blank `optional` questions adopt their recommendation as [ASSUMPTION] in place of their markers. No `[Q-xx]` marker is left in the document.

Summary check (when the interview ends; apply any pending batch first):
- Send one message in CHAT_LANG of at most about 15 lines: the scope in two lines, the core scenarios, the key domain rules with concrete values, the pinned terms, and the [ASSUMPTION]s. End it with the question asking me to confirm or correct.
- A correction is a new Q-xx: follow it as above, apply it, then show the summary again. REQUIRE.md is done when I confirm.
