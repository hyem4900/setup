# Question format (shared by the harness skills)

Source: `harness-skills/_shared/question-format.md`. Do not edit the copy under `references/`; edit the source and run `harness-skills/sync-shared.sh`. In a project with AGENTS.md, its "Ask the user when" section carries the same format; this file is for the skills that run before AGENTS.md exists or without the harness.

Every question to the user, in CHAT_LANG:

~~~
❓ **Q-08 — Missing transfer time**: May a **common default transfer time** apply between same-name stations, and if so, how many seconds? `Yesol` and `Geumbit` share a name, but the data gives no walking time between them.

➡️ Allow transfers between same-name stations and apply a common default time confirmed by the owner: the sources treat them as one station everywhere else.
~~~

- First line: ❓, then the ID (Q-xx, D-xx, or a number in a round) and a short topic in bold, a colon, then the question and its context in one to three sentences. Bold the phrase the decision hinges on.
- Question first: the sentence ending in `?` comes right after the colon; the reason, evidence, counts and examples follow it, never before it. Bad: "5 pairs of segments have two records ... Should we use only the newest?" Good: "Should we use only the newest record? For example, `S201→S202` has 266 s from 2025 and 176 s from 2026."
- Names, values, file paths and IDs from the project go in code spans.
- If there are options, list them between the question and the recommendation, one line each: `A) ...`, `B) ...`. Each option says in plain words what will happen and what the user gains or gives up; config keys or technical names only in parentheses after that. Never present an option as only `KEY=value` pairs.
- Blank line, then ➡️ and your recommended answer with one line on why. Every question has one. If you cannot recommend, say what you would need to know, and recommend the safest choice meanwhile.
- Use only Markdown bold and code spans for emphasis (clients render them in accent colors); no HTML, no color codes.
- Questions always come last in the message. Findings, explanations, tables and summaries go first; nothing follows the last ➡️ line.
- Several questions: ask in **rounds**. A round is the frontier: every open question whose answer does not wait on another open question, in one message, numbered, highest impact first, at most 5. Word each so that "yes" accepts the recommendation; the user may answer by number ("1 yes, 2 B") or all at once ("all as recommended" / "전부 추천대로"). Follow-ups an answer opens lead the next round.
