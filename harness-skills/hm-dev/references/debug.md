# Harness: Debug (part of hm-dev)

Follow AGENTS.md (languages, question format, forbidden actions), or without the harness the defaults in references/no-harness.md and the Inputs in references/develop-without-harness.md (the repository's own commands in place of `bash scripts/hm.sh <name>`, scratch files in the OS temp directory unless git ignores artifacts/). This procedure replaces guessing with a loop; it adds no new state. Use it for a bug whose cause is not obvious, after 3 failed fix attempts on the same test, or when I ask you to debug, find a cause, or find why something is slow.

## Where the fix goes
- Inside a task (Develop): work on that task's branch and worktree; the fix is part of the task.
- Asked directly with no task: diagnose only (Phases 1–4) on the integration head, in a temporary detached worktree as references/review-guide.md "Where to run" (in this skill's folder) describes (name `debug-<slug>`; with WORKTREES=0, the main worktree if it is clean and on INTEGRATION). Commit nothing and leave the tree as you found it, then report the root cause and the minimal repro and recommend registering it as a bug ("버그 등록해: ..." through hm-change) so the fix runs as a task.
- Asked directly without the harness: diagnose (Phases 1–4) on the current branch, in the current worktree if it is clean, else in a temporary detached worktree in the OS temp directory (`git worktree add --detach <dir> HEAD`, removed at the end). Report the root cause and the minimal repro, then ask whether to fix it on the current branch: if I say yes, do Phases 5–6 there and commit as `fix: <summary>`.
- Throwaway scripts, captured inputs and prototypes live under artifacts/debug/<task id or slug>/ (ignored by git). Never commit them.

## Before you start
Read the task file, the SPEC sections and REQUIRE §9 Glossary terms for the area, and the DECISIONS that touch it (whichever exist; a file I name comes first). Start the task file's `## Diagnosis` section (template below) and keep it current: a later session or the reviewer must be able to follow it. No task file: keep the same Diagnosis in a scratch file and put it in the report.

## Phase 1: Build a feedback loop
No theory before this exists. Build one command that is:
- red: it fails on this exact symptom (the wrong value, the error text, the time), not on "something broke"
- deterministic: fixed time and random seeds, this worktree's own data (HM_SLOT), test doubles for external services (SPEC §4d)
- fast (seconds) and unattended

Try, in this order: a failing test at the seam that reaches the bug, run alone (`bash scripts/hm.sh test <file>`, or `e2e <file>`) → a request against the components from `bash scripts/hm.sh dev-bg` on this worktree's ports → the CLI with fixture input compared with the expected output → replaying a captured input through the code path → a property or fuzz loop over many inputs → `git bisect run` between a known good and a known bad commit → for slowness, `bash scripts/hm.sh bench` or a timing harness.
- A flaky bug: raise the reproduction rate (repeat, run in parallel, add load, narrow the timing window). Never retry until it passes.
- No loop possible: stop and ask for one of: the exact steps or environment, a captured artifact (a log, a request, input data), or permission to add temporary instrumentation. List what you tried.
- Secrets: credentials come from the environment; never show a secret in a command, output or quoted artifact. Quote only the lines that carry the signal.

## Phase 2: Reproduce and minimise
Run the loop; confirm it fails with the reported symptom, not a nearby one, and record that symptom exactly. Remove inputs, steps, callers, configuration and data one at a time, re-running after each, until removing anything more makes it pass. The minimal repro becomes the regression test.

## Phase 3: Hypotheses
Write 3–5 ranked hypotheses in Diagnosis before testing any. Each is falsifiable: "if <cause>, then changing <one variable> makes <observable change>". Drop any without a prediction. In a chat with me, show the list and go on unless I reorder it; as a sub-agent, just record it.

## Phase 4: Probe
- One variable per probe, each testing one prediction. Record the result next to the hypothesis.
- A debugger or REPL first; otherwise targeted logs at the boundaries that separate hypotheses. Never broad logging to grep through.
- Every temporary log line or probe carries the tag `HM-DEBUG`, so one search removes them all. `bash scripts/hm.sh check` (the pre-commit hook) rejects a commit that still contains it, a `wip` commit included: remove the probes first and note them in Notes for Next Session. Without the harness nothing checks it for you: `git grep -n HM-DEBUG` must print nothing before any commit.
- Slowness: measure a baseline first (bench, profiler, query plan), then bisect the cost. Never fix before measuring.
- All hypotheses falsified: go back to Phase 2 with what the probes showed, and write new ones. After a second round with no cause, stop and ask.

## Phase 5: Fix
1. Turn the minimal repro into a failing regression test at the seam where the real bug happens (named after the AC it breaks, or `task<id>_bug_...`). A test that does not reach the real trigger gives false confidence: if no such seam exists, record that in Issues found and tell me.
2. Confirm it fails for the recorded symptom.
3. Fix the root cause, inside the task's scope. A fix that needs a contract, data model or dependency change, or code outside the scope: ask first (AGENTS.md).
4. The test passes; the Phase 1 loop on the original, unminimised scenario passes too; `bash scripts/hm.sh test` and `e2e` pass.

## Phase 6: Clean up
- No `HM-DEBUG` left (`bash scripts/hm.sh check` passes; without the harness, `git grep -n HM-DEBUG` is empty); throwaway files only under artifacts/debug/ or the OS temp directory.
- Diagnosis complete; the root cause and the hypothesis that held go into the fix commit message body and the task Log.
- Skipping a phase needs a one-line reason in Diagnosis.
- Diagnose only (no task): end the report with the next step, "버그 등록해: <the root cause in one line>" (hm-change), which turns it into a bug task.

## Diagnosis section (task file)
~~~markdown
## Diagnosis
- Symptom: <exact, as reproduced>
- Loop: `<command>` (red at <commit or state>)
- Minimal repro: <inputs / steps left>
- Hypotheses:
  1. <cause> → predicts <change> — <confirmed / falsified: what the probe showed>
- Root cause: <one or two lines>
- Regression test: <name, file>
~~~
