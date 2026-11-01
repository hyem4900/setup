# Harness: Test-first loop (part of hm-dev)

Read this before the first test of a feature or bug task. It is the loop the task's test list runs through, and what makes a test worth keeping.

## The loop: tracer bullets
Work one **tracer bullet** at a time: one test, then the least code that makes it pass, then the next. Each test answers what the last cycle taught you.
1. Pick the next test from the task's test list: riskiest first, or the one the demo scenario needs next.
2. Write it at its SPEC §7 seam, named after its full AC ID (or DQ). Run it alone (`bash scripts/hm.sh test <file>`, or `e2e <file>`) and see it go **red** for the reason the AC states: an assertion about the missing behavior, not an import error or a typo.
3. Write the least code that turns it **green**. Run it alone again.
4. Every few cycles, and before you commit, run the files you touched. The full suites run once, at the end of the task.
Refactoring is not a step of this loop: write the code the next test needs. Structural cleanup comes from the review's Standards axis.

## What a good test is
- It checks behavior through the seam's public interface: what a user or a caller can observe. It reads like the AC it is named after, and it survives a rewrite of the internals.
- Its expected value comes from an independent source: the AC's concrete values, a worked example, the spec. Never from computing it the way the code does.
- It sets up its own data (this worktree's HM_SLOT resources) and leaves nothing another test depends on.
- One behavior per test. Many small tests name what broke better than one large one.

## Anti-patterns
- **Implementation-coupled**: mocks internal collaborators, tests private functions, asserts on call counts or call order, or verifies through a side channel (querying the database instead of reading back through the interface). The tell: it breaks on a refactor that changed no behavior.
- **Tautological**: the assertion recomputes the expected value the way the code does, or compares a value with itself, so it passes by construction.
- **Horizontal slicing**: all the tests first, then all the code. Those tests check imagined behavior and lock in a structure before you understand it.

## Test doubles
Replace only what sits outside the system's boundary: the external services in SPEC §4d (with the doubles Task 0 wired), the clock, and randomness (a fixed seed). Inside the boundary, use the real modules and this worktree's real database. A test that needs a double inside the boundary is a sign the seam is in the wrong place: note it in Issues found.
