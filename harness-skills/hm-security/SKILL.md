---
name: hm-security
description: 'Step 6-3 of the harness flow. Use for "보안 점검해", "보안 테스트 해", "보안 리뷰해", "security review", or any request to test or harden security. In a separate session: maps the attack surface, runs the scans, writes security tests against the local components, and writes docs/security/review-<k>.md (findings with evidence and severity, improvements). Works without the harness. Does not fix product code or merge; findings become tasks through hm-change.'
argument-hint: '"보안 점검해" | "보안 점검해: Task <id>"'
---

# Harness Step 6-3: Security test and review

Talk to me in CHAT_LANG and write documents in DOC_LANG (both in .harness/config; Korean and English if unset). Code, identifiers and the fixed tokens scripts parse stay in English. Ask questions in the question format of AGENTS.md ("Ask the user when"): ❓ question with a bold topic, then ➡️ your recommendation.

You did not write this code. Look at it the way an attacker would, and report the way a reviewer does: evidence first, no guesses.
You do not fix product code. You add security tests, scan, and write the review; the fixes go through hm-change as tasks.

Attack only what is yours to attack: this project's code, and its components started from this worktree on this worktree's ports. Never send test traffic to production, staging, shared or third-party systems, never use real user data or real credentials, and never run denial-of-service or brute-force volumes beyond what a test needs to show a limit.

## Inputs
With the harness: AGENTS.md first, then REQUIRE §10 (SEC-xx), SPEC §4 and §12, docs/STANDARDS.md "Security baseline" (older projects: AGENTS.md "Security"), SPEC §7 for where tests live, SECURITY_CMD and SECRET_PATTERN in .harness/config, earlier reviews in docs/security/review-*.md.
Without the harness (no .harness/config): read references/no-harness.md and references/inputs.md in this skill's folder first; the latter says what stands in for each of those and what to do when nothing does.

## Preconditions
1. Fresh session: this session has not written or reviewed code for any task. If it has, tell me to start a new session and stop.
2. Target: INTEGRATION by default (MERGE=pr: `<REMOTE>/<INTEGRATION>` after `git fetch`). "보안 점검해: Task <id>" targets task/<id> instead: test the whole product, and look hardest at that task's diff (`git diff <INTEGRATION>...task/<id>`). A branch I name is the target the same way. Record the exact commit.
3. Create a branch `security/<n>` (next free n) from the target. WORKTREES=1: in its own worktree, with PORT_OFFSET from `bash scripts/harness-state.sh worktree security-<n>` in its `.harness/local`, then `bash scripts/hm.sh setup`. WORKTREES=0: `git switch -c security/<n>` in the clean main worktree. Work only there.
4. Read the inputs above, and every earlier review in docs/security/. A harness project set up before these sections existed: report the missing sections under Improvements.
5. SECURITY_CMD covers all three scans: dependency vulnerability audit per package manager, static security analysis per language, and a secret scan over the git history. Setup usually leaves only the dependency audit, so on the first run recommend tools for the missing ones before anything else: for each, two options with one line each, and your recommendation. Judge by: already in the repo or native to the stack; runs headless and exits non-zero at a chosen severity; writes a machine-readable report; fewest new dependencies. Wait for my answer, then add the tools to SPEC §1, §2 (SECURITY_CMD) and §7, and SECURITY_CMD to .harness/config, on this branch. Without the harness: run the chosen tools directly, and write their commands into the review's Scan results so the next review runs the same ones.

## 1. Map the attack surface
From the code, not from SPEC:
- Entry points: every route or handler, CLI command and flag, message consumer, file or upload input, webhook, and scheduled job that reads outside data. For each: authentication required, roles allowed, inputs.
- Assets: where passwords, tokens, API keys, personal data and secrets live (tables, files, caches, logs, backups, fixtures, seed scripts).
- Trust boundaries: browser ↔ server, component ↔ component, server ↔ database and third parties.
Compare with SPEC §4 and §12a, or their stand-ins (with none, skip the comparison and say so). An entry point SPEC does not list, or one with weaker protection than SPEC says, is a finding.

## 2. Scans
- `bash scripts/hm.sh security`. Triage every result: confirmed (reachable in shipped code), not exploitable here (with the reason), or false positive (with the reason). Never drop a result silently.
- Secrets in history: if SECURITY_CMD has no history scan, search every commit with SECRET_PATTERN (`git log -p --all`, printing only commit and file, never the value). A secret that was ever committed is a finding even if it was deleted later: it must be rotated.
- `bash scripts/hm.sh check` for the current tree (without the harness: the secret pattern over the tracked files with `git grep -nIiE`, printing only file:line).

## 3. Security tests
Write tests where SPEC §7 (or its stand-in, Inputs) says tests live (e.g. a `security` folder in the test directories), named after the area or the SEC-xx they cover (`test_sec03_...`, `sec-03: ...`, or the stack's naming style). Prefer the outer interface against the local components (`bash scripts/hm.sh dev-bg`); use unit tests for hashing, token and validation functions. Each test asserts the secure behavior.

Run them. Then:
- Passing tests stay as regression tests for controls that hold.
- A failing test shows a problem. Do not commit it (a failing or skipped test breaks `test` and `check` for everyone). Put its code in the finding, so the fix task starts from it, and remove it from the worktree.

Checklist. For every area that applies, record pass, fail or N/A with evidence (a test name, or file:line):

A. Password storage (rainbow tables and offline cracking)
- Find every place a password is written: sign-up, reset, change, admin creation, seed and fixture scripts, imports.
- Test: create two users with the same password. Their stored values differ (unique salt). The stored value has the format of the hash SPEC §12 names, with parameters at or above SPEC's. The plain password appears nowhere in the database, logs or responses afterwards (search them).
- No fast or unsalted hash (MD5, SHA-1, plain SHA-256), no reversible encryption, no custom scheme. Legacy hashes are upgraded on sign-in or wrapped in the strong hash.
- Verification uses the library's verify function (constant time), not string comparison.
B. Sign-in and credentials
- Repeated failed sign-ins are slowed or blocked; reset and code entry too.
- An unknown account and a wrong password give the same message (no account enumeration).
- Reset and invite tokens are random, single-use and expire; sessions rotate on sign-in and end on sign-out.
- Tokens and API keys are stored hashed.
C. Access control
- Call each entry point with no session, with another user's session, and with a lower role.
- Change object IDs in requests (another user's record). Send fields the user must not set (role, owner, price).
D. Injection and input
- SQL or NoSQL, shell command, path traversal, template injection, header injection, unsafe deserialization.
- Oversized bodies, deeply nested data, inputs that make a regex backtrack.
E. Web (HTTP components and screens)
- Stored and reflected XSS: the payload is shown as text, not run.
- CSRF on state-changing requests with cookie sessions. CORS with a foreign origin and credentials.
- Security headers present; cookie flags HttpOnly, Secure, SameSite; no open redirects.
- SSRF: if the app fetches URLs, internal addresses (127.0.0.1, private ranges, cloud metadata addresses) are refused.
F. Files: upload type and size checks, storage outside served paths, sanitized names, downloads confined to their folder.
G. Secrets and configuration: none in the repo or its history; the production-like commands do not run in debug mode; no default credentials; generic error pages.
H. Errors and logs: trigger errors and failed sign-ins. Logs record the event, with no password, token or personal data; responses show no stack traces or internals.
I. Between components: internal endpoints reject unauthenticated calls or are not reachable from outside; database accounts have only the rights they need.
J. Dependencies and supply chain: the scan results; lockfiles committed; unmaintained or unnecessary packages; install-time scripts.
K. Data protection: what each SEC-xx demands (encryption at rest, retention, deletion, export).
L. Resource abuse: rate limits, page size caps, request size limits, timeouts.

## 4. Earlier findings
For every finding in earlier reviews in docs/security/ that is not `Fixed` or `Accepted risk`: re-run its reproducing test or steps, and record Fixed (with the commit that fixed it) or still open.

## 5. The review
Write `docs/security/review-<k>.md` (next free k; never overwrite an earlier review), in DOC_LANG with the field names below in English:

~~~markdown
# Security review <k>
- Commit: <full sha of the target>
- Branch: security/<n>
- Date: YYYY-MM-DD
- Verdict: Pass | Pass with issues | Fail
- Scope: <entry points, components, areas N/A and why>

## Summary
(3–5 lines: the overall state, the worst problem, the most important improvement)

## Attack surface
| Entry point | Auth | Roles | Inputs | In SPEC §4/§12a |

## Scan results
| Scan | Tool | Critical | High | Medium | Low | Confirmed | Report |

## Checklist results
| Area | Result (pass / fail / N/A) | Evidence (test name or file:line) |

## Findings
### S-1: <title>
- Severity: Critical | High | Medium | Low
- Area: <checklist letter and name>; SEC-xx: <id or none>; CWE: <id if known>
- Where: <file:line, entry point>
- Evidence: <how it was shown: failing test output, request and response; never a real secret>
- Impact: <what an attacker gets>
- Fix direction: <what to change in this stack, and the SPEC §12 control it restores>
- Reproducing test:
  (code block with the failing test)
- Status: Open

## Earlier findings
| Finding (review-<k> S-n) | Status now | Evidence |

## Improvements
Hardening that is not a vulnerability today, and gaps: missing SEC-xx, SPEC §12 controls to add or tighten, tooling (SECURITY_CMD, SECRET_PATTERN), process (e.g. security tests in the DoD of tasks that touch sign-in). Suspicions you could not prove go here as "to verify".
| # | Improvement | Why | Effort (S / M / L) | Priority |

## Tests added
| Test | Area | SEC-xx | Result |
~~~

Severity:
- Critical: works without credentials or for any user, and leads to account takeover, many users' data, code execution, or recoverable passwords.
- High: needs a precondition, or exposes one user's data, a secret, or one control.
- Medium: a missing defense that makes another flaw worse, or a limited exposure.
- Low: hardening, best practice, information.

Every Critical and High needs evidence: a failing test or a concrete reproduction. Do not inflate severities.
Verdict: Fail if any Critical or High is open (new or earlier); Pass with issues if only Medium or Low are open; Pass otherwise.

## 6. Commit
- `bash scripts/hm.sh test`, `bash scripts/hm.sh e2e` and `bash scripts/hm.sh check` pass with the new tests.
- Commit the passing tests and the review: `test(security): security tests and review <k>` (and `chore(security): security scan tools` first, if precondition 5 added them).
- `bash scripts/hm.sh stop`, and stop anything else you started.
- Do not merge the branch yourself: merging is the development session's step. The branch holds only tests, docs and tool settings, so it needs no separate review.

## End
Report in CHAT_LANG:
- Verdict, open findings by severity, and the worst findings in one line each
- The top three improvements
- Earlier findings now fixed or still open
- The review file and the branch
- Next:
  - "Merge branch security/<n>." (hm-dev) to integrate the tests and the review
  - "보안 리뷰 반영해: docs/security/review-<k>.md" (hm-change): findings become tasks (Critical and High first), and the rest become tasks or accepted risks I decide on. Without the harness: "리뷰 반영해: docs/security/review-<k>.md" (hm-dev) fixes them on a branch instead
  - After the fixes merge, "보안 점검해" again: the next review re-checks every open finding
Then stop.
