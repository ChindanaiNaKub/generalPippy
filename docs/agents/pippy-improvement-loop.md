# Pippy Improvement Loop

The Pippy improvement loop is a human-reviewed process for refining Pippy's prompts, routing, acceptance-criteria guidance, context handling, and verification habits based on evidence from `/goal` run reports.

## How It Works

1. **Collect goal run reports.** Each `/goal` run produces a structured report with acceptance criteria, execution plan/log, evidence, routing decisions, retry causes, improvement signal, and outcome.
2. **Review the Improvement Signal.** The Improvement Signal field identifies Pippy-owned friction — problems in Pippy's own prompts, routing logic, acceptance-criteria shaping, context assembly, or verification habits. It is always present and limited to Pippy-owned friction.
3. **Distinguish Pippy-owned friction from ordinary project failure.** Pippy-owned friction is things like: acceptance criteria were vague and had to be rewritten mid-run, a file was read multiple times because context was not compressed, the retry bundle omitted failure context so the first retry failed identically, or review routing produced findings but the final verification gate was skipped. Ordinary project failure is things like: the user's objective was genuinely blocked by a missing dependency, the codebase had a pre-existing bug unrelated to Pippy, or the task required human judgment that no agent could resolve.
4. **Turn accepted signals into changes.** A maintainer reviews accepted signals and decides whether to modify Pippy's prompts (pippy.md, SKILL.md, goal.md), add or adjust commands, update skills, write new tests, or update documentation. Each change should be scoped to one signal and verifiable.
5. **Verify the change.** After modifying Pippy config, run `bash tests/validate.sh` and `bash scripts/doctor.sh` to confirm nothing broke. Run a `/goal` smoke test if the change affects routing or verification behavior.

## What This Loop Does Not Do

- It does **not** automatically modify Pippy. All changes are human-reviewed and manually applied.
- It does **not** train or fine-tune any model. Signals inform prompt and config changes only.
- It does **not** replace ordinary project debugging. If a `/goal` run fails due to a codebase bug, that is not an improvement signal.

## Relationship to the Pippy Loop Stack

The improvement loop is one layer of the [Pippy loop stack](../../README.md#pippy-loop-stack), sitting alongside the self-driving loop, verification feedback, and external trigger recipes. It closes the loop between run evidence and prompt evolution.

## See Also

- [External Trigger Recipe](external-trigger-recipe.md) — invoking `/goal` from outside Pippy
- [Manual Smoke Tests](manual-smoke-tests.md) — Improvement Signal smoke test examples
- [ADR-0006](../adr/0006-dynamic-subagent-dispatch.md) — context bundles and corrective re-delegation
