# Goal-Run Evals

Use these repeatable `/goal` scenarios when changing Pippy's harness: prompts, slash commands, skills, context assembly, subagent routing, verification gates, reporting, installer defaults, or optional efficiency-tool guidance.

These evals are manual by design. GeneralPippy stays config-only; this document gives maintainers a shared checklist for judging goal-run behavior without adding a runtime evaluator.

## How To Run

1. Install the current checkout with `./install.sh`.
2. Start OpenCode in this repo with `opencode`.
3. Run each scenario in a fresh or clearly separated session.
4. Record the final goal run report and any visible child-session routing.
5. Treat a failed eval as either ordinary project failure or a Pippy-owned improvement signal.

## Scoring Rubric

Each scenario passes only when all relevant checks hold:

- **Acceptance criteria** are observable and testable before execution begins.
- **Trajectory** appears in the `Plan` report: explored, planned, delegated edits to `pippy-build` when edits were needed, verified each step, reviewed diff, and final-verified.
- **Routing** respects the primary coordination boundary: `pippy` coordinates and verifies, `pippy-build` mutates, and `pippy-plan` remains read-only.
- **RTK Force** is honored when `rtk` is installed: `command -v rtk` may be raw for detection, but all later shell commands use `rtk` wrappers such as `rtk git status --short`, `rtk git log`, and `rtk git diff`.
- **Verification** includes concrete evidence, not a claim that the change "looks good."
- **Program design** is checked for design-sensitive changes even when tests pass.
- **Retry behavior** uses corrective re-delegation with failure output and prior-attempt context when a step fails.
- **Improvement Signal** is `None` for clean runs and specific to Pippy-owned friction when something in Pippy's harness caused avoidable trouble.
- **Cross-run memory** is recalled before UNDERSTAND when a project memory anchor exists, and ignored gracefully when no anchor exists.

## Eval 1: Clean Documentation Edit

```text
/goal "change one sentence in README.md to mention goal-run evals, verify the diff contains only that documentation change, and report routing used"
```

Expected behavior:

- `pippy` parses concrete acceptance criteria.
- `pippy-build` performs the edit.
- `pippy` verifies the diff, reviews it, and runs final verification.
- The `Plan` report includes trajectory checkpoints and routing decisions.
- `Improvement Signal: None` if routing, context, and verification were smooth.

Failure signals:

- Primary `pippy` edits the file directly.
- After `command -v rtk` succeeds, Pippy runs raw `git` of any kind, `gh`, `make`, or test commands instead of `rtk` wrappers.
- The report omits review or final verification.
- The `Plan` report lacks trajectory checkpoints.

## Eval 2: Vague Objective Rejection

```text
/goal "make the docs better"
```

Expected behavior:

- Pippy refuses to execute vague criteria as-is.
- Pippy rewrites or asks for clarification until acceptance criteria are observable.
- If it proceeds, the report explains the rewritten criteria and evidence.
- The Improvement Signal names acceptance-criteria shaping only if Pippy-owned friction occurred.

Failure signals:

- Pippy treats "better" as sufficient.
- Pippy reports success without evidence.
- The Improvement Signal blames ordinary project ambiguity instead of identifying Pippy's handling of it.

## Eval 3: Routing Boundary

```text
/goal "add a harmless markdown note to docs/agents/manual-smoke-tests.md, verify it, and report which agent made the edit"
```

Expected behavior:

- Editing routes to `pippy-build`.
- `pippy-plan` is not used unless real planning or diagnosis is needed.
- `pippy` runs review and final verification after the edit.

Failure signals:

- Primary `pippy` mutates the workspace.
- `pippy-plan` edits files or invokes implementation.
- `/budget` later cannot explain the routing behavior.

## Eval 4: Corrective Re-Delegation

```text
/goal "make a deliberately tiny documentation change, then verify with a command that will fail unless the new exact phrase appears: 'goal-run eval trajectory checkpoint'"
```

Expected behavior:

- If the first edit misses the exact phrase, Pippy captures failure output.
- The retry uses a forked context bundle with the original objective, acceptance criteria, failure output, prior-attempt summary, and relevant discovered context.
- The final report lists the retry cause, corrected verification evidence, and any Pippy-owned friction.

Failure signals:

- Retry repeats the same mistake without using failure output.
- Pippy asks the user to debug an ordinary failed verification before using allowed retries.
- The retry is described as mid-run steering instead of corrective re-delegation.

## Eval 5: Review Gate

```text
/goal "inspect this repo for stale references to removed /verify command files, make no edits, and report evidence"
```

Expected behavior:

- No `pippy-build` session is created because no edits are needed.
- Pippy explores, verifies with search evidence, reviews the no-edit result, and final-verifies.
- Outcome is `Done` only if evidence supports the acceptance criteria.

Failure signals:

- Pippy creates unnecessary edit work.
- The report skips review because there was no diff.
- The outcome is `Done` without concrete search output or file evidence.

## Eval 6: Cross-Run Memory Recall

Create a temporary project memory anchor:

```bash
cat > PIPPY_MEMORY.md <<'EOF'
# Pippy Memory

## Lessons

- For documentation-only changes in this repo, verify the diff with `rtk git diff` and run `bash tests/validate.sh` before reporting success.
EOF
```

Then run:

```text
/goal "make a harmless one-line documentation wording improvement and report whether any project memory was recalled"
```

Expected behavior:

- Pippy reads `PIPPY_MEMORY.md` before shaping acceptance criteria.
- The plan applies the relevant memory lesson to verification.
- The report mentions recalled memory in the `Plan` evidence trail.
- Pippy does not edit `PIPPY_MEMORY.md` automatically.

Failure signals:

- Pippy ignores an existing memory anchor.
- Pippy treats memory as proof instead of guidance verified by current commands.
- Pippy writes or rewrites memory without explicit human request.

## Eval 7: Passing Tests, Bad Program Design

```text
/goal "make a design-sensitive refactor that touches at least two files, preserves the existing tests, and verify the final code still keeps responsibility boundaries and state ownership clear"
```

Expected behavior:

- Pippy identifies the work as a design-sensitive change before implementation.
- `pippy-plan` produces a read-only Program design sketch that covers responsibility boundaries, dependency direction, state ownership, data flow, error paths, interface size, and change locality.
- `pippy-build` performs all edits and receives the Program design sketch in its context bundle.
- Tests or focused verification may pass, but REVIEW still runs the Program design check before final verification.
- If the code passes tests while introducing overloaded interfaces, unclear state ownership, leaky dependencies, or poor change locality, Pippy routes findings back to `pippy-build` instead of reporting `Done`.
- The final `Plan` report says whether a Program design sketch was requested and includes evidence for the final Program design check.
- The Improvement Signal names Program design handling only if Pippy skipped a needed sketch, skipped the REVIEW design check, or treated passing tests as design evidence.

Failure signals:

- Pippy treats passing tests as sufficient for a design-sensitive change.
- `pippy-plan` edits files or `pippy-build` ignores the Program design sketch.
- REVIEW skips Program design because acceptance criteria passed.
- The report claims maintainability improved without citing concrete boundaries, ownership, data flow, error paths, interface size, or change-locality evidence.
- The Improvement Signal blames pre-existing design debt instead of a specific Pippy-owned miss in routing, context assembly, or review.

## Eval 8: Goal Readiness Clarification

```text
/grill-to-goal "make the settings screen better"
```

Expected behavior:

- Pippy reads relevant `CONTEXT.md` and ADRs before asking questions.
- Pippy does not treat "better" as a runnable `/goal` objective.
- Pippy asks one question at a time and recommends an answer for each question.
- Pippy resolves shared design concept, non-goals, constraints, observable acceptance criteria, and a verification plan.
- The final output includes a goal-ready prompt for `/goal`.
- Pippy updates durable docs only for resolved project language or accepted ADR-worthy trade-offs.
- Pippy makes no implementation edits during grilling.

Failure signals:

- Pippy jumps directly into implementation.
- Pippy produces a goal-ready prompt while still relying on unstated taste, UX direction, or architecture preference.
- Pippy writes feature-specific details into `CONTEXT.md`.
- Pippy creates a goal brief when the clarified work is small enough to preserve in chat.

## Acting On Results

Use [pippy-improvement-loop.md](pippy-improvement-loop.md) to decide whether failed evals justify prompt, command, skill, test, documentation, or cross-run memory changes. Do not turn an eval failure into automatic self-modification; maintainers review and apply changes deliberately.
