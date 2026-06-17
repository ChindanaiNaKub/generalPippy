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
4. Assemble a context bundle (fresh or forked) for each delegation
5. Execute and verify each step
6. Corrective re-delegate failures (3 cheap + 1 strong diagnosis)
7. Review the diff and verification evidence
8. Run final verification
9. Report outcome as exactly one of `Done`, `Blocked`, or `Partial`

### Acceptance Criteria Rules

Each acceptance criterion must be **observable and testable**. Valid examples:
- "A test passes" (verifiable by running the test)
- "A file exists at path X" (verifiable by checking the filesystem)
- "A command produces expected output" (verifiable by running the command)

Banned: vague criteria like "make it better", "improve performance", "clean up the code". If a criterion cannot be checked by evidence, rewrite it until it can.

### Plan Rules

The plan must list steps **in execution order** with dependencies respected. Each step must have a **single, independently verifiable deliverable** — one clear thing that can be checked as done or not done.

### Output Format

Every `/goal` run must report four things at the end:

1. **Acceptance Criteria** — the verifiable conditions that define success, stated upfront and checked against evidence; each criterion must include the evidence (command output, test result, file path, diff)
2. **Plan** — the step-by-step execution log showing what was done and in what order; include routing decisions for pippy/pippy-plan/pippy-build when used, and retry causes or `None` when no retry happened
3. **Improvement Signal** — Pippy-owned friction in prompts, routing, acceptance-criteria shaping, context handling, or verification habits; use `None` when there is no actionable signal
4. **Outcome** — one of:
   - `Done` — all acceptance criteria met, verification passes
   - `Blocked` — what's blocking progress, what needs human action
   - `Partial` — what was completed, what remains, why it stopped

### Review And Verification

Review and final verification are the closing gates of `/goal`, not standalone commands. The plan must always end with review followed by final verification before reporting outcome. After all execution steps complete:
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
