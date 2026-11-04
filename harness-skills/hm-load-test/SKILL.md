---
name: hm-load-test
description: 'Step 5.2 of the harness flow. Use for "부하 테스트 해", "성능 테스트 해", or a load test or benchmark against the SPEC §10 targets (without the harness: from a document, or asked). Measures, finds bottlenecks, fixes, re-measures and writes docs/LOAD_TEST.md. Load test when HAS_LOAD=1; single-caller benchmarks (§10b) otherwise. Recommends a tool if SPEC names none.'
argument-hint: '"부하 테스트 해" | "성능 테스트 해"'
---

# Harness Step 5.2: Performance test

Talk to me in CHAT_LANG and write documents in DOC_LANG (both in .harness/config; Korean and English if unset). Code, identifiers and the fixed tokens scripts parse stay in English. Ask questions in the question format of AGENTS.md ("Ask the user when"): the bold topic line, the open question, 🔍 with what you found, then ➡️ with your recommendation and its reason.

## Inputs
With the harness: AGENTS.md first, then targets in SPEC §10a and §10b, tools in SPEC §1, `bash scripts/hm.sh load` (each component's `<c>_PROD` command on PORT_OFFSET + 100), LOAD_LEVELS and LOAD_DURATION in .harness/config, the demo scenarios in docs/tasks/, `bash scripts/hm.sh test / e2e / check`.
Without the harness (no .harness/config): read references/no-harness.md and references/inputs.md in this skill's folder first; the latter says what stands in for each of those and what to ask for when nothing does.

## Preconditions
- Read the targets (Inputs). Pick what to run:
  - A concurrent-user target (HAS_LOAD=1 and §10a has rows): load test (sections 1–3)
  - Single-caller targets (§10b rows): benchmarks (section 1b, then section 3 with `bash scripts/hm.sh bench`)
  - Both: do both. Neither, with the harness: tell me this project has no performance targets and stop. If I still want one, ask me for the numbers and update REQUIRE NFRs, SPEC §10 (and HAS_LOAD if it is a concurrent-user target) first. Without the harness, the fallback asks for them.
- With the harness, the core task is merged into INTEGRATION (`bash scripts/harness-state.sh status`).
- Create a branch `perf/<n>` (next free n) from INTEGRATION (MERGE=pr: `<REMOTE>/<INTEGRATION>`). WORKTREES=1: in its own worktree, with PORT_OFFSET from `bash scripts/harness-state.sh worktree perf-<n>` in its `.harness/local`, then `bash scripts/hm.sh setup`. WORKTREES=0: `git switch -c perf/<n>` in the clean main worktree. Work only there.
- tests/load/targets.json mirrors the load targets and tests/bench/targets.json the benchmark targets. With the harness, SPEC wins: if they differ, fix the JSON and tell me. Without it, write them from the targets in Inputs.
- Measure on a quiet machine: other dev servers and tests compete for CPU. If `bash scripts/harness-state.sh status` shows tasks In Progress (or, without the harness, other processes of this project are running), tell me the numbers may be noisy.
- SPEC §1 (or a setup already in the repository) names the load tool and the benchmark tool. If one is missing, recommend a tool before writing anything:
  - Two options, one line each on fit, and your recommendation. Judge by: already in the repo or native to the stack; runs headless from one command and exits non-zero on a missed target; reports what the targets need (per-endpoint p50/p95/p99, error rate, RPS for load; p50/p95 over repeated runs for benchmarks); fewest new dependencies.
  - Wait for my answer, then add the tool to SPEC §1, §2 (LOAD_CMD / BENCH_CMD) and §7, and to the commands in .harness/config. Without the harness: add it as a development dependency only, and write the command that runs it into LOAD_TEST.md Conditions, so the next run repeats it.

## 1. Load scenarios (SPEC §10a)
Write or extend the load script under tests/load/ with the load tool from SPEC §1:
- One scenario per demo scenario in the merged task files (docs/tasks/), or per flow from the Scenarios input, using the same calls as the screens or clients, through the outermost component that receives user traffic
- Weights reflect realistic use (say which weights you chose and why)
- IDs and search terms sampled at startup from DATA_SOURCES if set; otherwise from tests/fixtures/ or a seeding step you describe. Never hardcode a single ID.
- Wait time between requests per user (default 1–3s)
- Reads `USERS`, `DURATION`, `OUT_DIR` from the environment (the `bash scripts/hm.sh load` contract) and writes per-endpoint results to OUT_DIR in a machine-readable file
- Target check: only when `TARGET_CHECK=1`, compare per-endpoint p95 and error rate to tests/load/targets.json at the end and exit 1 if any target is missed. Other levels only record.

## 1b. Benchmarks (SPEC §10b)
Write or extend tests/bench/ with the benchmark tool from SPEC §1:
- One benchmark per §10b row, with the input size stated in that row (generate it, or sample from DATA_SOURCES; never a 3-row fixture for a 100k-row target)
- Warm-up runs excluded, at least 10 measured runs (or the tool's default if higher)
- Compare to tests/bench/targets.json and exit 1 if any target is missed
- `bash scripts/hm.sh bench` runs it. Record per row: runs, p50, p95, max, and the input size

## 2. Baseline
- `bash scripts/hm.sh load` (every component with its production-like command on load ports, i.e. PORT_OFFSET + 100; full data, no reload, multiple workers). Without the harness: start the production-like command from Inputs on a free port, run the load script once per level with `USERS`, `DURATION` and `OUT_DIR` set (`TARGET_CHECK=1` at the target level), then stop what you started.
- Levels come from LOAD_LEVELS in .harness/config (FULL: 10 / target / 2x, HACKATHON: target only), LOAD_DURATION each; without the harness, the fallback in Inputs.
- Record per endpoint: requests, p50, p95, p99, error rate, RPS. Also CPU and memory per component if available.
- Benchmarks: `bash scripts/hm.sh bench` is the baseline.

## 3. If any target is missed
1. Find the root cause before changing anything. Evidence first: profile one slow request, find which component spends the time, check query plans, count queries and calls between components per request, check worker saturation.
2. State the hypothesis and the evidence in one paragraph.
3. Fix the smallest thing that addresses it.
4. Ask me first if the fix changes the interface contract, the data model, a dependency, or adds infrastructure (cache server, new DB).
5. `bash scripts/hm.sh test`, `bash scripts/hm.sh e2e`, `bash scripts/hm.sh check` must still pass.
6. Re-run `bash scripts/hm.sh load` (or `bash scripts/hm.sh bench`) under identical conditions.
7. Repeat at most 3 rounds. If targets are still missed, stop and report the options.
8. Commit each fix: `perf: <what>`

## 4. docs/LOAD_TEST.md

Keep the section headings for the parts that did not run and write `N/A (<reason>)`.

~~~markdown
# Performance Test

## Conditions
Date, commit, machine (CPU/RAM), OS, data size.
Load: server command and workers, load tool and version, users per level, duration, weights.
Benchmarks: tool and version, runs per benchmark, input sizes.

## Targets
(copy of SPEC §10a and §10b, or the targets from Inputs with their source)

## Results: baseline
Load:
| Level | Endpoint | Requests | p50 | p95 | p99 | Error % | RPS | Target met |
Benchmarks:
| Target | Input | Runs | p50 | p95 | Max | Target met |

## Bottlenecks
| # | Symptom | Evidence | Root cause | Fix | Commit |

## Results: after
(same table)

## Before / After
| Endpoint / benchmark | p95 before | p95 after | Target |

## Remaining risks
~~~

Commit: `docs: performance test results`
Do not merge the branch yourself: merging is the development session's step. If the branch has `perf:` fixes and I want a review first, tell me to run "Review range <INTEGRATION>...perf/<n>." in a separate session; then "Merge branch perf/<n>." (hm-dev) integrates it.

## End
Report in CHAT_LANG: pass/fail per endpoint or benchmark at target level, main bottleneck and fix, the branch and the next step (hm-dev, "Merge branch perf/<n>.", or hm-review, "Review range <A>..<B>.", first, then the other step-5 skills not run since the last merge: "누락 검토해", "보안 점검해"), anything that needs my decision. Then stop.
