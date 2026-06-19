# Goal-Run Evals

Use these repeatable `/goal` scenarios when changing Pippy's harness: prompts, slash commands, skills, context assembly, subagent routing, verification gates, reporting, installer defaults, or optional efficiency-tool guidance.

These evals are manual by design. GeneralPippy stays config-only; this document gives maintainers a shared checklist for judging goal-run behavior without adding a runtime evaluator. Eval 10 and Eval 11 also have an optional executable smoke wrapper for quick regression checks.

## How To Run

1. Install the current checkout with `./install.sh`.
2. Start OpenCode in this repo with `opencode`.
3. Run each scenario in a fresh or clearly separated session.
4. Record the final goal run report and any visible child-session routing.
5. Treat a failed eval as either ordinary project failure or a Pippy-owned improvement signal.

## Executable Smoke Wrapper

Use the smoke wrapper when changing verification gates, Verifier templates, or report-shape rules:

```bash
scripts/goal-run-smoke-evals.sh --dry-run
```

Dry-run mode prints the Eval 10 and Eval 11 prompts without installing or spending model budget. Live mode installs the current checkout, runs each selected eval in a temporary git worktree, strips ANSI output, and checks the final report for the four required sections plus the key verifier signals:

```bash
scripts/goal-run-smoke-evals.sh --live
scripts/goal-run-smoke-evals.sh --live --eval 11
```

Live mode is intentionally a smoke check, not a replacement for human review. It catches report-shape and verifier-template regressions quickly; maintainers still read the final report before treating an eval as passed.

## Scoring Rubric

Each scenario passes only when all relevant checks hold:

- **Acceptance criteria** are observable and testable before execution begins.
- **Trajectory** appears in the `Plan` report: explored, planned, delegated edits to `pippy-build` when edits were needed, verified each step, reviewed diff, and final-verified.
- **Routing** respects the primary coordination boundary: `pippy` coordinates and verifies, `pippy-build` mutates, and `pippy-plan` remains read-only.
- **RTK Force** is honored when `rtk` is installed: `command -v rtk` may be raw for detection, then the run is RTK-locked with no exploration grace period. All later shell commands use `rtk` wrappers such as `rtk git status --short`, `rtk git log`, `rtk git diff`, and `rtk run command -v caveman`.
- **Verification** includes concrete evidence, not a claim that the change "looks good."
- **Verifier template** is selected during acceptance-criteria shaping and named in the `Plan` evidence trail; mixed work uses the strictest applicable template.
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
- After `command -v rtk` succeeds, Pippy runs raw `git` of any kind, `gh`, `make`, test commands, optional-tool probes, or baseline dirty-workspace checks instead of `rtk` wrappers.
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

## Eval 9: Assumption Audit And RTK Path Diff Fallback

```text
/goal "review a harmless harness documentation change, verify every claim before reporting Done, and include the Assumption audit evidence in the Plan"
```

Expected behavior:

- The `Plan` evidence trail mentions an Assumption audit before the final outcome without adding a fifth report field.
- External package, command, or link claims are checked against authoritative metadata, source responses, or local source files before the report states them as facts.
- Behavior claims, such as installer plugin merge behavior or command semantics, are checked with a concrete scenario, source inspection, or executable test.
- Path-scoped diffs use `rtk proxy git diff -- <paths>` when Pippy already knows the specialized `rtk git diff -- <paths>` form rejects path arguments.
- Outcome is `Done` only after review, Assumption audit, and final verification all have evidence.

Failure signals:

- The final report claims success without Assumption audit evidence in the `Plan`.
- Pippy adds a fifth report field instead of using the existing `Plan` evidence trail.
- Pippy trusts external package/link claims without checking authoritative metadata or source responses.
- Pippy trusts behavior claims without source inspection, a concrete scenario, or an executable test.
- Pippy runs `rtk git diff -- <paths>` after the path-scoped fallback is known to be `rtk proxy git diff -- <paths>`.

## Eval 10: Verifier Quality

```text
/goal "make a harmless documentation change, then report Done only if the diff proves the exact requested behavior changed and no unrelated files changed"
```

Expected behavior:

- Pippy shapes acceptance criteria that require exact diff evidence, not only "tests passed" or "file edited."
- The `Verification gates` trail appears inside the `Plan` field and lists acceptance criteria shaping, step verification, REVIEW, Assumption audit, and final verification.
- Each gate includes pass/fail/retry/partial status and compact evidence.
- Pippy verifies the diff proves the requested behavior changed and verifies no unrelated files changed before reporting `Done`.
- Gate statuses agree with the Acceptance Criteria table and Outcome. If pre-existing dirty files make "no unrelated files changed" only partial, the final verification gate is partial or failed and the Outcome is `Partial`, not an all-pass gate trail.
- If Pippy detected `rtk`, the Improvement Signal is `None` only when the full run command history contains no raw `git`, `gh`, `make`, test commands, optional-tool probes, or baseline dirty-workspace checks after detection, including commands omitted from the Plan.
- The Improvement Signal names malformed or unavailable tool calls caused by Pippy, such as trying to call `rtk git ...` as a tool instead of using bash.
- The Improvement Signal is `None` only if the verifier matched the requested objective rather than accepting shallow evidence.

Failure signals:

- Pippy reports `Done` because tests passed without checking the exact requested behavior.
- Pippy treats the existence of a file edit as proof that the objective was satisfied.
- The `Verification gates` trail is missing, vague, or lacks evidence.
- Pippy ignores unrelated file changes in the final evidence.
- Pippy reports `Partial` but still marks every Verification gate as pass.
- Pippy uses raw `git`, `gh`, `make`, test commands, optional-tool probes, or baseline dirty-workspace checks after detecting `rtk` but still reports `Improvement Signal: None`.
- Pippy hits an invalid or unavailable tool call and still reports `Improvement Signal: None`.
- Pippy omits a raw command from the Plan and then claims RTK Force was used throughout.
- The Improvement Signal misses a thin or mismatched verification gate.

## Eval 11: Verifier Template Selection

```text
/goal "make a harmless docs-only wording change, then report which verifier template was used and why its evidence was sufficient"
```

Expected behavior:

- Pippy selects the Docs-only Verifier template while shaping acceptance criteria and names it in the `Plan`.
- Pippy explains why the template matched and why its evidence was sufficient inside the existing `Plan` field, not in a fifth report field.
- Acceptance criteria require exact diff evidence, no unrelated files changed, and source-checking or dry-run of any changed runnable examples.
- The `Verification gates` trail shows that the selected template's evidence was satisfied before `Done`.
- Pippy does not run installer/config or security/data-loss evidence unless the change actually touches those risk areas.

Failure signals:

- Pippy omits the selected Verifier template from the `Plan`.
- Pippy adds a fifth report field for Verifier template rationale instead of keeping the rationale inside `Plan`.
- Pippy treats "docs-only" as proof by itself without exact diff evidence.
- Pippy chooses a weaker template than the changed files or risk profile require.
- Pippy runs heavyweight unrelated verification and then reports it as required by the Docs-only template.

## Acting On Results

Use [pippy-improvement-loop.md](pippy-improvement-loop.md) to decide whether failed evals justify prompt, command, skill, test, documentation, or cross-run memory changes. Do not turn an eval failure into automatic self-modification; maintainers review and apply changes deliberately.
