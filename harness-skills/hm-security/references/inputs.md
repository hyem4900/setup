# Inputs without the harness (part of hm-security)

Read this with references/no-harness.md when `.harness/config` does not exist. Find each input in this order, and name in the review the file that served (e.g. `Security requirements: docs/security-policy.md (stand-in for REQUIRE §10)`): a file I name → the harness file → a file in the repository that plays the same role (ask once if several fit) → the fallback.

| Input | Harness file | Stand-ins to look for | Fallback |
|---|---|---|---|
| Security requirements | REQUIRE §10 (SEC-xx) | a security policy, compliance notes, the README's security section | the checklist in SKILL.md section 3 is the baseline |
| Contracts, threats and controls | SPEC §4 and §12 | API descriptions (an OpenAPI file and the like), design docs, ADRs | the attack surface from the code (SKILL.md section 1) alone |
| Security baseline | docs/STANDARDS.md "Security baseline" (older projects: AGENTS.md "Security") | CONTRIBUTING.md, a security guide | `templates/STANDARDS.template.md` in the hm-setup skill folder (`../hm-setup/`) |
| Where tests live | SPEC §7 | the folders the repository's tests are already in | ask |
| Scans | SECURITY_CMD | the repository's audit scripts | recommend tools (SKILL.md precondition 5) and run them directly |
| Secret pattern | SECRET_PATTERN in .harness/config | — | the SECRET_PATTERN line of `templates/config-commands.template` in the hm-setup skill folder |
| Earlier reviews | docs/security/review-*.md | — | none: this is the first |
