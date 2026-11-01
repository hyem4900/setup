# Requirements

## 1. Scope summary
(3–5 lines)

## 2. Functional requirements
### R-01 {title}
- Source: <file> §x / Q-xx / CR-xx
- Priority: Must | Should | Could
- Acceptance criteria: (Must: listed below; Should and Could: `when tasked`)
  - R-01/AC-1: Given … When … Then …
  - R-01/AC-2: …
- Notes: [ASSUMPTION] …

## 3. Domain rules
### DR-01 {rule}
- Rule, examples with concrete values, used by R-xx

## 4. Data handling rules
Facts per file or table, from a script: rows, the columns and keys that matter, relations, quality issues with counts. A few lines each.
| Issue | Count | Treatment (drop / default / flag / show as-is) | R-xx |
(N/A if DATA_SOURCES is empty)

## 5. Compatibility constraints
What must keep working: existing behavior, APIs, data formats, contracts between components.
(N/A if GREENFIELD=1)

## 6. Non-functional requirements
| NFR-ID | Requirement | Measurable target | Source |
(latency p95, concurrent users, error rate, data size, supported browsers/OS/devices/runtimes)

## 7. Assumptions
| ID (A-01) | Assumption (how it is handled) | Evidence (file §, count, example) | Status (proposed / confirmed / changed by Q-xx) |

## 8. Out of scope
| Item | Reason |

## 9. Glossary
| Term | Definition | Not to be called | Example | Source |
(pinned terms and the terms the sources define; empty table if none)

## 10. Security requirements
| SEC-ID | Requirement (what must hold, in product terms) | How verified (test, scan, or review) | Priority | Source |
(N/A only with a reason, e.g. "local CLI, no users, no network, no stored data")

## 11. Questions
(every question as a block in the format of Step 3, sorted by impact; answered ones keep their `- decision:` line as the record)
