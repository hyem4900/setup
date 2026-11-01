# Running without the harness (shared by the harness skills)

Source: `harness-skills/_shared/no-harness.md`. Do not edit the copy under `references/`; edit the source and run `harness-skills/sync-shared.sh`.

Read this when `.harness/config` does not exist. Every skill except hm-auto works in such a repository; the skill's Inputs table says what it reads instead of each harness file.

## Do not create the harness
Create none of `.harness/config`, AGENTS.md, `scripts/` or git hooks: they belong to hm-setup, and other skills would take them for a finished setup. Do not edit REQUIRE.md, SPEC.md, DECISIONS.md or a config either: a document the skill would normally update is read only, and what it would have changed goes into the skill's own output (a change record, a review, a report).

## Defaults for this session
- CHAT_LANG: the language the user writes in. DOC_LANG: the language of the repository's docs, else English. Code, identifiers and the fixed tokens scripts parse stay in English.
- INTEGRATION: the repository's default branch (`origin/HEAD`, else `main` or `master`; ask if none). WORKTREES=0, MERGE=local: work in the current worktree and merge locally.
- Commands: wherever the skill says `bash scripts/hm.sh <name>`, use the repository's own command for that purpose (package scripts, a task runner, a Makefile; ask once if unclear). If there is none, say which checks did not run.
- Scratch files (reviews, debug files, load results, PR bodies): `artifacts/` if git ignores it (`git check-ignore -q artifacts/x`), else the OS temp directory; print the path.
- Questions: the format in `references/question-format.md`, last in the message.
- Name in the output which file served for each input (e.g. `Spec source: README.md (stand-in for REQUIRE.md)`).
