# Requirements

Status: Draft (questions in docs/QUESTION.md)

## 1. Scope summary
(3–5 lines: what is built, for whom, the main constraint. No rules here; they live in §3)
Access: local demo / team-internal / public internet (who uses it from where; hm-setup decides the deployment from it)

## 2. Functional requirements
### R-01 {title}
- Source: <file> §x / Q-xx / CR-xx
- Priority: Must | Should | Could
- Acceptance criteria: (Must: listed below; Should and Could: `when tasked`)
  - R-01/AC-1: Given … When … Then … (a rule from §3 is cited by its ID, e.g. "per DR-02", with the values this test checks; never restated)
  - R-01/AC-2: …

## 3. Domain rules
### DR-01 {rule}
- The rule with concrete values and an example. The one place it is written; ACs, §4 and the Glossary cite it

## 4. Data handling rules
Facts per file or table, from a script: rows, the keys that matter, relations, quality issues with counts. A few lines each; only facts a later step uses (a treatment, a test's expected value), no column lists or counts nothing depends on.
| Issue | Count | Treatment (drop / default / flag / show as-is) | R-xx |
(N/A if DATA_SOURCES is empty)

## 5. Compatibility constraints
What must keep working: existing behavior, APIs, data formats, contracts between components. Name a contract the sources fix by its source section; do not copy it.
(N/A if GREENFIELD=1 and the sources fix no contract)

## 6. Non-functional requirements
| NFR-ID | Requirement | Measurable target | Source |
(latency p95, concurrent users, error rate, data size, supported browsers/OS/devices/runtimes; nothing an R-xx already requires)

## 7. Assumptions
| ID (A-01) | Assumption (how it is handled) | Evidence (file §, count, example) | Status (proposed / confirmed / changed by Q-xx) |
(only defaults the sources or data support, and Low questions; a decision left to you is in QUESTION.md, not here)

## 8. Out of scope
| Item | Reason |

## 9. Glossary
| Term | Definition | Not to be called | Example | Source |
(pinned terms and the terms the sources define; empty table if none)

## 10. Security requirements
| SEC-ID | Requirement (what must hold, in product terms) | How verified (test, scan, or review) | Source |
(N/A only with a reason, e.g. "local CLI, no users, no network, no stored data")
