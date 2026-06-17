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
- **Retry behavior** uses corrective re-delegation with failure output and prior-attempt context when a step fails.
- **Improvement Signal** is `None` for clean runs and specific to Pippy-owned friction when something in Pippy's harness caused avoidable trouble.

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

## Acting On Results

Use [pippy-improvement-loop.md](pippy-improvement-loop.md) to decide whether failed evals justify prompt, command, skill, test, or documentation changes. Do not turn an eval failure into automatic self-modification; maintainers review and apply changes deliberately.
