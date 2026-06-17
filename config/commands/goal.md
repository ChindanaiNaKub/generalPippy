---
description: Start a self-driving goal — Pippy plans, executes, verifies, and iterates until done
agent: pippy
---

## /goal

Start the self-driving loop.

```
/goal "<verifiable objective>"
```

Pippy will:
1. Parse the objective into acceptance criteria (each must be observable and testable — e.g., "a test passes", "a file exists", "a command produces expected output"; vague criteria like "make it better" are banned)
2. Explore the codebase with jcodemunch
3. Plan step-by-step, in execution order, with a single independently verifiable deliverable per step
4. Execute and verify each step
5. Retry failures (3 cheap + 1 strong diagnosis)
6. Run the final no-mistakes gate
7. Report outcome as exactly one of `Done`, `Blocked`, or `Partial`

### Acceptance Criteria Rules

Each acceptance criterion must be **observable and testable**. Valid examples:
- "A test passes" (verifiable by running the test)
- "A file exists at path X" (verifiable by checking the filesystem)
- "A command produces expected output" (verifiable by running the command)

Banned: vague criteria like "make it better", "improve performance", "clean up the code". If a criterion cannot be checked by evidence, rewrite it until it can.

### Plan Rules

The plan must list steps **in execution order** with dependencies respected. Each step must have a **single, independently verifiable deliverable** — one clear thing that can be checked as done or not done.

### Output Format

Every `/goal` run must report three things at the end:

1. **Acceptance Criteria** — the verifiable conditions that define success, stated upfront and checked against evidence
2. **Plan** — the step-by-step execution log showing what was done and in what order
3. **Outcome** — one of:
   - `Done` — all acceptance criteria met, verification passes
   - `Blocked` — what's blocking progress, what needs human action
   - `Partial` — what was completed, what remains, why it stopped

### Verification

Verification is the **FINAL step** of `/goal`, not a standalone command. The plan must always end with this verification gate before reporting outcome. After all steps complete:
1. Cheap self-review of the full diff (use `rtk git diff` when `rtk` is installed)
2. Run the combined verification command (`rtk make all` when `rtk` and `make all` are available, otherwise `rtk test` / `rtk err` equivalents)
3. Check docs for public API changes

### Examples

```
/goal "add input validation to the signup endpoint"
/goal "refactor the auth module to use dependency injection"
/goal "fix the flaky test in orders.test.ts"
```

### Notes

- YOLO mode is on by default (auto-allow reads, subagent routing, unrestricted bash, and implementation edits inside `pippy-build`; command output should go through `rtk` when installed).
- Pippy stops only when acceptance criteria are met by evidence.
- Use `/ship` as a shortcut for PR prep.
- Use OpenCode's session usage display for exact tokens/cost, and `/budget` for routing and efficiency guidance.
