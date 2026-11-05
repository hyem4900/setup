# SPEC

## 1. Tech Stack
| Layer | Choice | Major version (current stable, or the one the repo pins) | Rationale (D-xx) |

Also the rows `Deployment` (where it runs and how a new version gets there, or `local only`) and, for REQUIRE §1 `Access: public internet`, `Domain and HTTPS`. The harness records them; deploying is done by hand.

## 2. Runtime & Commands
| Item | Value |
|---|---|
| Install | (all components) |
| Unit test command | (all components; may chain per-component commands) |
| Lint (LINT_CMD) | the linter and the formatter's check mode, taking files as `"$@"`; empty only if the stack has no such tool. The pre-commit hook runs it on the staged code files; a direct `check` on the whole project |
| Type check (TYPECHECK_CMD) | the type checker over the whole project; runs only at the gates (a direct `check`), never per commit. Empty if the language has none |
| Format (FORMAT_CMD) | the formatter, rewriting the files given as `"$@"` and skipping file types it does not handle. The pre-commit hook runs it on staged code files |
| Test directories (TEST_DIRS) | every directory holding unit or E2E tests, across components |
| E2E directories (E2E_DIRS) | (HAS_UI=1) where UI E2E tests live |
| E2E tool setup (E2E_SETUP_CMD) | one-time install the E2E tool needs (e.g. browser or emulator download), run by `bash scripts/hm.sh setup`; empty if none |
| E2E command | |
| Skip-marker pattern (regex for skipped tests in this stack) | |
| Per-worktree resources (HM_SLOT) | (WORKTREES=1) each mutable resource parallel worktrees must not share, and its per-worktree form from `$HM_SLOT` (0 in the main worktree), e.g. database `myapp_$HM_SLOT`, cache prefix `myapp:$HM_SLOT:`; `none` if nothing is shared |
| Service name (SERVICE) | (HAS_SERVER=1) kebab-case project name; each component's health check proves it is `<SERVICE>-<component>`, so harness targets never reuse another project's process on the same port |
| Run command (DEV_CMD) | (HAS_SERVER=0: how a user runs the CLI or imports the library; DEV_CMD is one sample invocation) |
| Launcher (UP_CMD / DOWN_CMD) | (optional) an existing command that starts / stops all components at once and returns; empty if the harness starts each component |
| Load test command (LOAD_CMD) | (HAS_LOAD=1) one headless run of the load tool. Reads `USERS`, `DURATION`, `OUT_DIR` from the environment; with `TARGET_CHECK=1` it exits 1 if any target in tests/load/targets.json is missed |
| Benchmark command (BENCH_CMD) | (§10b has targets) exits 1 if any target in tests/bench/targets.json is missed; empty otherwise |
| Migration command (MIGRATE_CMD) | (a database) applies pending migrations to this worktree's database, idempotently; empty if there is no database |
| Security scan command (SECURITY_CMD) | the dependency audit from §1 (hm-security later chains static analysis and a history secret scan onto it); exits non-zero at the severity §12 sets, counting only the dependencies the product ships with (development-only tools are reported, never fail it); reports to artifacts/security/ |
| Secret pattern (SECRET_PATTERN) | the key and token formats of the services this project uses, added to the harness default (private keys, cloud access keys, quoted password/secret/key/token values) |

Components (HAS_SERVER=1; long-running processes only, in start order: a component's dependencies first; one row for a single-process app):
| Component (letters, digits, `_`) | Kind (http / ui / worker / other) | Directory | Base port | Dev command (with reload) | Production-like command (no reload, N workers) | Health check (proves it is `<SERVICE>-<component>`) | Talks to |

Ports are bases: the harness adds a per-worktree PORT_OFFSET, so commands take their port (and the ports of components they call) from `$<component>_PORT`, never hardcoded. HTTP components expose GET /healthz → 200 {"status":"ok", "service":"<SERVICE>-<component>", ...}.

## 3. Data Model
Per table/entity: its key, the relations, and the rules the schema must enforce (unique, not null, foreign keys, checks), plus any column that carries a decision (money, time, a stored format, a value derived from DATA_SOURCES and how). Other columns are decided while developing.
Then indexes, and the loading process if DATA_SOURCES is set: when it runs, how it is idempotent, how each rule in REQUIRE §4 is applied, expected load time.
Migrations (if there is a database): the stack's usual migration method, its folder, and file names that cannot collide between parallel branches (timestamps, not sequential numbers); MIGRATE_CMD in §2.
Repeated and concurrent writes: list the writes where a duplicate does real harm (payments, bookings, stock, anything unique) and the simplest guard for each (a unique constraint, an idempotency key, or a lock). Other writes need nothing.
For GREENFIELD=0: mark each table as Existing / Changed / New.

## 4. Interface Contract
The product's outer interface. Use the subsection that applies.
Examples: write a full example (JSON, output) for every entry when there is more than one component or PARALLEL > 1, because separate tasks build the two sides from it. Otherwise give the fields with their types, and an example only where the shape is not obvious.

### 4a. HTTP API (HTTP components)
Per component. Common error format: {"error": {"code": "...", "message": "..."}}. Include GET /healthz.
#### {component}: {METHOD} {path}
- Requirements: R-xx
- Request: params/body fields with types (example: see above)
- Response 200: fields with types (example: see above)
- Errors: | HTTP | code | when |

### 4b. CLI / library (HAS_SERVER=0)
#### {command or function}
- Requirements: R-xx
- Input: args/flags/parameters with types
- Output: stdout/return value shape (example: see above)
- Errors: | exit code or exception | when | message |

### 4c. Between components (more than one component)
Contracts that are not the product's outer interface: internal APIs, events/messages, shared tables, files.
#### {producer} → {consumer}: {name}
- Transport: HTTP / RPC / queue topic / table / file
- Payload: example, with version or compatibility rule
- Failure: what the consumer does when the producer is down or sends something invalid

For GREENFIELD=0: mark each entry Existing / Changed / New. Changed entries must state backward compatibility (REQUIRE §5).

### 4d. External services
(only if the product calls services it does not own: payment, mail, maps, identity, other teams' APIs)
| Service | What we call | Test double (a fake in tests, or the provider's sandbox) | Timeout and retry | Credentials (env key name) |

## 5. Screens (HAS_UI=1)
Platform: browser / mobile / desktop. Mobile priority: phone first / desktop first / both (the narrowest width every screen must work at).
One short block per screen: what a user must be able to see and do there, not its layout or look. A few lines each. The look comes from the design D-xx in DECISIONS if there is one, otherwise from docs/STANDARDS.md (UI baseline).
#### {Screen}: {route or entry}
- Requirements: R-xx
- Who: the roles that may open it, and what anyone else gets (redirect to sign-in, 403 screen)
- Shows: each piece of information that must be visible, with its format where it matters (e.g. boarding time `HH:MM`, cost in won with thousands separators) and its test id; the AC it comes from after each one, e.g. `(R-02/AC-1)`
- Can do: each action, what happens after it, and its test id; per role if roles differ; the AC after each one
- States: what the screen shows when empty, loading, and on an error
- APIs: the endpoints it calls (§4)

Flow: Screen A → Screen B → ...
Each Shows and Can do item is built and tested by one task: its E2E asserts the item through its test id (§7). An item no AC asks for is a design choice recorded here; adding, removing or changing an item later goes through hm-change.
Test-id rule: every interactive element and every region an E2E test asserts on has a test id in kebab-case, in the platform's test-id attribute (web: `data-testid`; other platforms: the attribute the chosen E2E tool reads as its test id). Name it here.
Selector policy: `test-id`, `test-id+role` or `none` (the decision above). With `test-id`, E2E tests select only by test id; with `test-id+role`, also by role with an accessible name. The test-id rule above holds either way.

## 6. Core Logic
One entry per core computation decided in the core logic questions (N/A if the product has none). Where each other DR-xx lives is decided while developing (one place per rule, unit tested).
### {computation}: {name of the approach}
- Requirements: R-xx, DR-xx, NFR-xx
- Model: how the domain becomes the algorithm's input (e.g. what the nodes, edges and weights of a graph are)
- Algorithm: the base algorithm and every change to it, and how each domain rule enters (cost, constraint, pruning, post-processing)
- Result: what "best" means (single or several criteria, their order), tie-breaking, limits (how many results, cut-offs), what happens when there is no result
- Reach: what the approach can change while it searches and what it never changes (e.g. it can move a person to another existing route but never opens a new one), and the better results that limit rules out, if any
- Quality: how good is good enough (a number on the "best" criterion, or a comparison with a simple baseline or a bound), and what it is compared against; `not set` if REQUIRE has no such target
- Cost: expected time and memory at the REQUIRE §4 data size, against its NFR; what is precomputed and when
- Checked by: the cases that prove it (a small hand-checkable example with the expected answer, the edge cases, and one case where the simple approach, such as greedy, nearest-first or first-fit, gives the wrong answer), at its §7 seam (D-xx)

## 7. Test Strategy
- Test seams: for each kind of behavior, where its tests attach. Prefer seams that already exist, the highest level that still runs fast (the outer interface before internals), and as few new seams as possible. One line per seam: what is tested there (e.g. "domain rules: the pricing module's public functions, unit tests"; "each R-xx flow: the HTTP API, E2E"). Development, review and debugging use these seams.
- Unit: framework and location per component (co-located or separate test folders, as the stack prefers), what to cover (domain rules, loaders, handlers)
- Fixtures: a small subset that includes every known data quality issue. Unit tests never read DATA_SOURCES directly.
- Test data isolation: each test creates the data it needs (unique names or IDs) or runs in a transaction that is rolled back, so tests pass in any order and on components that are already running. No shared reset step between tests.
- External services (§4d): tests use their doubles, never the real service.
- E2E: black-box tests through the outer interface, one spec file per task.
  - HAS_UI=1: the UI E2E tool from §1; select per the selector policy in §5; every Shows and Can do item of the screens a task builds (§5) is asserted through its test id, for each role listed in Who; screenshots to artifacts/e2e/screenshots/task-<id>/
  - HAS_SERVER=1 and HAS_UI=0: client tests against the running components
  - More than one component: at least one E2E per task crosses the component boundary it touches; §4c contracts get a contract test on each side
  - HAS_SERVER=0: run the CLI as a subprocess, or call the public API from a fresh process
- Characterization tests (GREENFIELD=0): lock current behavior of any existing code a task will change, before changing it
- Load (HAS_LOAD=1): the load tool from §1, scenarios under tests/load/, targets mirrored in tests/load/targets.json
- Benchmark (§10b): the benchmark tool from §1, under tests/bench/, targets mirrored in tests/bench/targets.json. Kept out of the unit suite so timing never makes `bash scripts/hm.sh test` flaky.
- Security: each SEC-xx and each §12 control gets a test through the outer interface or a unit test (negative cases: wrong user, no session, malicious input, same password twice); scans run by `bash scripts/hm.sh security`
- For each tool: the alternative considered and why it lost (one line)

## 8. Folder Structure
(top-level folders per component, and where tests go; deeper layout is Task 0's and the codebase notes'. For GREENFIELD=0, only what is added or changed)

## 10. Performance Targets
### 10a. Load (HAS_LOAD=1)
| Component: endpoint | p95 (ms) | Target concurrent users | Max error rate | Source NFR |

### 10b. Benchmarks (single caller, no concurrency)
For latency or throughput NFRs that are not load tested: CLI commands, library functions, batch jobs, or a server endpoint when HAS_LOAD=0.
| Command / function / endpoint | Input (size, fixture) | Metric (p95 ms, rows/s, total s) | Target | Source NFR |

## 12. Security
Keep this section short: it sets defaults for development. The full attack-surface mapping and testing happen in hm-security.

### 12a. Top threats
The few threats that matter most for this product (at most 5 rows in FULL, 3 in HACKATHON): what an attacker wants and how they would try.
| Threat | Where (entry point or boundary) | Control (12b) | SEC-xx |

### 12b. Controls
| Area | Control in this project | Verified by |
One row per area that applies. For an area where the docs/STANDARDS.md Security baseline is enough, write `baseline` instead of restating it; write details only where the project needs more or different. Areas (skip those that do not apply, in one line):
- Password storage (if the product stores passwords): a slow, salted, adaptive hash (Argon2id preferred; scrypt or bcrypt where the stack lacks it) with a unique random salt per password, its parameters (memory, iterations, parallelism or cost) meeting current OWASP Password Storage guidance, and rehash-on-login when parameters rise. Never plain text, reversible encryption, or a fast or unsalted hash (MD5, SHA-1, plain SHA-256). Prefer an external identity provider when it fits.
- Other credentials: tokens and keys from a cryptographically secure random generator (at least 128 bits), stored hashed, compared in constant time, expiring; reset and invite tokens single-use.
- Sign-in abuse: rate limits or backoff on sign-in, sign-up, reset and code entry, per account and per source address (credential stuffing: one try on each of many accounts); messages that do not reveal whether an account exists; a check against known breached passwords and multi-factor sign-in when a SEC-xx asks.
- Sessions and tokens: lifetime, rotation on sign-in, invalidation on sign-out; cookies HttpOnly, Secure, SameSite.
- Access control: deny by default; the role matrix, each role checked on the server; ownership checked on the server for every object.
- Input and injection: parameterized queries, programs run with an argument list (no shell from input), path confinement (canonical path inside the allowed folder), size limits, safe parsers.
- Files (uploads and downloads): allowed types and sizes, where files are stored (outside served and executable paths), how they are named and served.
- Web (HAS_UI=1 or HTTP): output encoding, CSRF protection for cookie sessions, CORS allow-list, security headers (CSP, HSTS in production, frame protection against clickjacking), no open redirects.
- Outgoing requests (any component that requests a URL or host from input: link previews, webhooks, imports by URL): SSRF allow-list; internal and metadata addresses refused, also after redirects.
- Language model calls (if the product sends input or fetched content to a model): what the model may read and do (tools, data scope), which actions need the user's confirmation, how its output is shown; no secrets in prompts (prompt injection).
- Availability: request size limits and rate limits in the app (which endpoints, what limits); who handles floods at the network level (the hosting, a CDN, or `not handled` with the reason).
- Secrets: where each lives per environment; none in the repo or in code shipped to the client; SECRET_PATTERN.
- Errors and logs: generic errors to users; no secrets, passwords, tokens or personal data in logs; security events logged.
- Between components: how internal calls are authenticated or confined; least-privilege database accounts; internal ports not exposed.
- Data protection: encryption at rest or field-level encryption when a SEC-xx requires it; retention and deletion.
- Dependencies: lockfiles committed; SECURITY_CMD fails at severity `High` (or the level chosen here) in the dependencies the product ships with; development-only tools are reported only.
