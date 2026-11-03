# Coding Standards

How code is built in this project. The reviewer checks every diff against this file (docs/REVIEW.md, Standards axis); the developer reads the section AGENTS.md "Standards" points to before writing that kind of code.
Order of precedence: Project rules, then the baselines, then the smell baseline. A rule a linter or a grep can enforce belongs in `bash scripts/hm.sh check` (LINT_CMD or a guardrail pattern) instead of here: this file holds what needs judgement.

## Security baseline
REQUIRE §10 lists the security requirements (SEC-xx); SPEC §12 lists the threats and the controls this project uses. Whatever the stack:
- Passwords: store only the password hash SPEC §12 names (a slow, salted, adaptive hash such as Argon2id, scrypt or bcrypt, with a unique random salt per password and the parameters SPEC states), so a leaked database cannot be cracked with precomputed (rainbow) tables. Never store, log or return a password in plain text, encrypted, or as a fast or unsalted hash. Two users with the same password must get different stored values.
- Other credentials (API keys, reset, invite and session tokens): from a cryptographically secure random generator, stored hashed, compared in constant time, with an expiry.
- Secrets: read from the environment or a secret store; never in code, in committed config, in fixtures or in logs. `bash scripts/hm.sh check` blocks likely secrets; a fake secret in a test carries `harness:allow-secret` on its line. Anything shipped to the client (a web bundle, a mobile or desktop app, environment values the build exposes to the client) is public: secret keys (database, payment, language model API keys) stay on the server, and the client calls the server.
- Input: parameterized queries; never build shell commands, queries or file paths by concatenating input; validate input at the trust boundary.
- Commands: run a program with an argument list, never through a shell; put the end-of-options marker (`--`) before arguments from input, or refuse input that starts with `-`.
- Paths (a file name or path from input): prefer names the code generates; otherwise resolve the path to its canonical form and check it is still inside the allowed folder. Joining a base folder with input does not confine it (`../`, absolute paths, encoded separators).
- Sign-in abuse: limit failed attempts per account and per source address, so one try on each of many accounts from one source (credential stuffing) is slowed too; sign-up, password reset and code entry are rate limited per source address too; the same message for an unknown account and a wrong password.
- Access: deny by default; every request for an object checks on the server that this user may access that object. Admin and other role-limited actions check the role on the server on every request; hiding a button or a page on the client is not a check.
- Uploads: check the size before reading the body in full, and the type against an allow-list by content as well as extension; store files outside served and executable paths under a generated name; serve them with an explicit content type, as a download where they are not meant to be shown.
- Output (XSS): text from input reaches a screen only through the UI framework's default escaping or the encoder for its context (HTML body, attribute, URL, script); never insert it as raw HTML. Rich text that must keep markup goes through an allow-list sanitizer. Links from input allow only http and https.
- Cross-site requests (CSRF, with cookie sessions): every request that changes state needs a CSRF token or the stack's built-in equivalent, on top of SameSite cookies; GET and HEAD never change state.
- Session cookies: HttpOnly, Secure (in production), SameSite.
- CORS (HTTP components called from browsers): an allow-list of origins; never `*` with credentials, never the request's own Origin echoed back.
- Outgoing requests (SSRF, when a URL or host comes from input): allow only the schemes and hosts the feature needs (an allow-list where possible); resolve the name and refuse loopback, private, link-local and cloud metadata addresses, again after every redirect; set a timeout and a response size limit.
- Headers (web screens): other sites may not frame the pages (clickjacking: CSP `frame-ancestors`, or the frame options header); a CSP, and HSTS in production.
- Language model calls (if the product sends input or fetched content to a model): instructions hidden in that text may steer the model (prompt injection), so its output is untrusted input: shown encoded, never run as code, a query or a command. Its tools get only the rights the feature needs and only the current user's data; an action that is hard to undo needs the user's confirmation; no secret or another user's data goes into the prompt.
- Errors: no stack traces, internals, secrets or personal data in responses or logs.
- Crypto and randomness: the stack's standard libraries only; never a homemade scheme.

## Backend baseline
Wherever they fit the product (a CLI or a library uses the ones that apply):
- Transactions: a write that spans several rows, tables or calls runs in one transaction, so a failure leaves no half-written data.
- Database constraints: NOT NULL, foreign keys, UNIQUE and CHECK in the schema for the rules the data must obey, not only checks in code.
- Timeouts: every call out of the process (database, other components, external services) has a timeout; database access goes through a connection pool.
- Bounded reads: list endpoints and queries have a maximum page size; never load a whole table into memory on a request path; columns used to filter, join or sort have an index.
- Request limits (network-facing components): a maximum request body and upload size, refused before it is read in full; rate limits per client on public or costly endpoints (sign-in, search, exports, uploads, calls to paid services). Floods at the network level are the hosting's job (SPEC §12).
- Money and time: no floating point for money (integer minor units or a decimal type); store times in UTC with the zone made explicit, and convert only at the edge (display, input).
- Exceptions: never swallow one. Handle it, or log it with context and the request ID and let it propagate. Every log line of a request carries its request ID.
- HTTP semantics (HTTP components): GET and HEAD change nothing; validation errors are 4xx, server faults 5xx; never a 200 that carries an error.
- Timestamps: tables whose rows change have `created_at` and `updated_at`, set by the database or one shared place in code.
- Resources: connections, files, streams and locks are always released (the language's scoped or `finally` construct), also on errors.

## Smell baseline
Judgement calls, never hard violations: a finding names the smell as a possibility ("possible Feature Envy") and quotes the hunk. Minor at most, unless a Project rule makes it a rule. A Project rule that endorses the pattern suppresses the smell; skip what LINT_CMD already enforces. Each reads: what it is → how to fix.
- Mysterious Name: a name that does not say what the thing does or holds → rename it; if no honest name comes, the design is murky.
- Duplicated Code: the same logic shape in more than one hunk or file → extract it and call it from both.
- Feature Envy: a function that uses another module's data more than its own → move it next to that data.
- Data Clumps: the same few fields or parameters always travel together → give them one type.
- Primitive Obsession: a string or number standing in for a domain concept (a REQUIRE §9 term) → give the concept its own small type.
- Repeated Switches: the same branching on the same type in several places → one shared map or polymorphism.
- Shotgun Surgery: one logical change forces edits scattered across many files → gather what changes together into one module.
- Divergent Change: one module edited for several unrelated reasons → split it so each part changes for one reason.
- Speculative Generality: parameters, hooks or abstractions no AC needs → delete them; inline until a real need shows.
- Message Chains: long navigation through objects the caller should not know → one method on the first object.
- Middle Man: a module that only forwards calls → call the real target.
- Refused Bequest: a subtype that ignores or overrides most of what it inherits → composition instead of inheritance.

## Project rules
Judgement rules this project adopted, one line each, with their source (e.g. `RV-3, docs/reviews/task-2-review-1.md`). The apply-review step adds one when the same kind of finding comes back; a mechanical one becomes a check instead.
- (none yet)
