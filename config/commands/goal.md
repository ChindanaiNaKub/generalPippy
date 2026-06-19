---
description: Start a self-driving goal — Pippy plans, executes, verifies, and iterates until done
agent: pippy
---

## /goal

Start the self-driving loop.

```
/goal "<verifiable objective>"
```

`/goal` runs a Closed goal loop by default. It is for verifiable objectives, not open-ended exploration. When the objective needs product direction, broad ideation, or unresolved trade-offs before it can be verified, recommend `/grill-to-goal` instead of widening `/goal` into an open loop.

Pippy will:
1. Recall human-approved cross-run memory from the first existing project anchor: `PIPPY_MEMORY.md`, `.pippy/memory.md`, or `docs/agents/pippy-memory.md`
2. Check Goal readiness, then parse the objective into acceptance criteria (each must be observable and testable — e.g., "a test passes", "a file exists", "a command produces expected output"; vague criteria like "make it better" are banned)
3. Explore the codebase with jcodemunch
4. Plan step-by-step, in execution order, with a single independently verifiable deliverable per step
5. Request a read-only Program design sketch from `pippy-plan` before design-sensitive changes
6. Assemble a context bundle (fresh or forked) for each delegation
7. Execute and verify each step
8. Corrective re-delegate failures (3 cheap + 1 strong diagnosis)
9. Review the diff and verification evidence
10. Run final verification
11. Report outcome as exactly one of `Done`, `Blocked`, or `Partial`

### Acceptance Criteria Rules

Each acceptance criterion must be **observable and testable**. Valid examples:
- "A test passes" (verifiable by running the test)
- "A file exists at path X" (verifiable by checking the filesystem)
- "A command produces expected output" (verifiable by running the command)

Banned: vague criteria like "make it better", "improve performance", "clean up the code". If a criterion cannot be checked by evidence, rewrite it until it can.

### Goal Readiness Rules

Before planning, check whether the objective has enough shared intent for Pippy to execute without inventing product direction. Recommend `/grill-to-goal` when the work depends on subjective taste, UX direction, architecture preference, non-goals, constraints, or trade-offs that are not stated.

Hard block only when Pippy cannot form observable acceptance criteria without guessing the user's intent. Otherwise, ask one clarifying question, soft-recommend `/grill-to-goal`, or proceed when the user explicitly accepts listed assumptions. If proceeding with assumptions, include those assumptions in the plan and verify them during REVIEW.

Scale verification rigor to task risk while shaping acceptance criteria. Use higher rigor when the objective touches release prep, auth, security, data loss, installer behavior, permissions, or public docs/config: require stronger evidence such as targeted tests, full validation commands, diff review, and docs checks. For low-risk prototype or small documentation work, lightweight evidence such as a focused diff or file check is acceptable. Do not introduce a separate mode flag; express the rigor through the acceptance criteria and plan.

### Plan Rules

The plan must list steps **in execution order** with dependencies respected. Each step must have a **single, independently verifiable deliverable** — one clear thing that can be checked as done or not done.

Before implementation, route design-sensitive changes to `pippy-plan` for a read-only Program design sketch. A change is design-sensitive when it is multi-file, refactor-heavy, touches core abstractions, changes state ownership or error paths, or introduces a new interface. Skip the sketch for small mechanical edits. Include any sketch in the `pippy-build` context bundle.

### Output Format

Every `/goal` run must report four things at the end:

1. **Acceptance Criteria** — the verifiable conditions that define success, stated upfront and checked against run evidence; each criterion must include final evidence (command output, test result, file path, diff)
2. **Plan** — the compact run evidence trail showing what was done and in what order; include whether cross-run memory was recalled, commands run, verification outputs, trajectory checkpoints for recalled memory when present, explored, planned, requested a Program design sketch when used, delegated edits to `pippy-build`, verified each step, reviewed diff, ran the Assumption audit, and final-verified. Include routing decisions for pippy/pippy-plan/pippy-build when used, and retry causes or `None` when no retry happened. Include a compact `Verification gates` trail inside this field: acceptance criteria shaped, each step verification, REVIEW, Assumption audit, and final verification, each with pass/fail/retry/partial status and evidence. Gate statuses must agree with the Acceptance Criteria table and Outcome: if any acceptance criterion is failed or partial, the final verification gate cannot be `pass` and the Outcome cannot be `Done`. Do not imply a raw trace, telemetry store, durable memory write, or persistent observability system.
3. **Improvement Signal** — Pippy-owned friction in prompts, routing, acceptance-criteria shaping, context handling, Program design handling, Verification gates, Verifier mismatch, or verification habits; use `None` when there is no actionable signal. Before reporting `None`, audit the full run command history, including exploration commands omitted from the Plan, for harness violations. Raw `git`, `gh`, `make`, or test commands after `rtk` was detected must be named even when the Outcome is `Done`; omitting such a command from the Plan is also Pippy-owned friction. Never claim RTK Force was used throughout unless the actual command history supports it. Program design failures are Pippy-owned only when Pippy skipped a needed sketch, skipped the Program design REVIEW check, accepted passing tests without design evidence, or made maintainability claims without concrete boundaries/ownership/data-flow evidence; messy pre-existing code is not a Pippy-owned signal.
4. **Outcome** — one of:
   - `Done` — all acceptance criteria met, verification passes
   - `Blocked` — what's blocking progress, what needs human action
   - `Partial` — what was completed, what remains, why it stopped

### Review And Verification

Review and final verification are the closing gates of `/goal`, not standalone commands. The plan must always end with review followed by final verification before reporting outcome. After all execution steps complete:
1. Cheap self-review of the full diff (use `rtk git diff` when `rtk` is installed)
2. Apply the review checklist for last-20% failures: edge cases, error handling, integration assumptions, hallucinated dependencies, program design regressions, and clever-looking generated code that passes shallow tests but may be conceptually wrong
3. Run a **Program design** check inside REVIEW: inspect responsibility boundaries, dependency direction, state ownership, data flow, error paths, interface size, and change locality; route findings to `pippy-build`, then re-verify and rerun REVIEW
4. Run an **Assumption audit** before reporting: check each claim Pippy is about to make against an authoritative source, executable evidence, or a concrete scenario; source-check external links/package metadata, scenario-check behavior claims, and dry-run runnable docs. Scale depth to verification rigor: quick for low-risk work, deeper for installer, permissions, dependencies, external links, public docs, security, or data-loss risks. Put audit evidence in the existing Plan evidence trail, not in a fifth report field.
5. Run the combined verification command (`rtk make all` when `rtk` and `make all` are available, otherwise `rtk test` / `rtk err` equivalents)
6. Check docs for public API changes

### Examples

```
/goal "add input validation to the signup endpoint"
/goal "refactor the auth module to use dependency injection"
/goal "fix the flaky test in orders.test.ts"
```

### Notes

- YOLO mode is on by default (auto-allow reads, subagent routing, unrestricted bash, and implementation edits inside `pippy-build`).
- RTK Force is mandatory when `rtk` is installed: `command -v rtk` is the only allowed raw detection command, then the run is **RTK-locked** and every later shell command must go through `rtk` (`rtk git status --short`, `rtk git log`, `rtk git diff`, `rtk proxy git diff -- <paths>` for path-scoped diffs, `rtk make all`, `rtk run command -v caveman`, or `rtk run` / `rtk proxy`). There is no exploration grace period: baseline dirty-workspace checks, git status/log/diff, optional-tool probes, validation, and final verification all use `rtk` after the lock. Raw `git` of any kind, `gh`, `make`, or test commands after rtk was found are Pippy-owned routing failures and must appear in the Improvement Signal.
- Recalled cross-run memory is guidance, not proof; Pippy must verify it against the current objective, repo docs, and code, and must not write memory automatically.
- Pippy stops only when acceptance criteria are met by evidence.
- Use `/ship` as a shortcut for PR prep.
- Use OpenCode's session usage display for exact tokens/cost, and `/budget` for routing and efficiency guidance.
