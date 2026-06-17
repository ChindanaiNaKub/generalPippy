# ADR-0008: /improve-pippy Command Decision

Status: accepted

## Context

A proposal was made to add a built-in `/improve-pippy` slash command that would let Pippy improve its own prompts, config, and agent instructions based on goal-run reports. The motivation is to shorten the feedback loop between discovering Pippy-owned friction (e.g., vague acceptance criteria, missing context bundles, inefficient routing) and fixing it.

The alternative considered was an automatic self-modifying command that edits GeneralPippy's own `config/` files, `AGENTS.md`, or agent prompts without human review.

## Decision

Do not add a built-in `/improve-pippy` slash command. Improvement of Pippy itself stays a human-reviewed process driven by goal-run reports and the existing improvement-loop documentation.

Reject the alternative of an automatic self-modifying command that would edit GeneralPippy's own prompts or config without human review.

### Rationale

- CONTEXT.md defines "Pippy improvement loop" as human-reviewed, not automatic self-modification. A slash command that bypasses human review violates this boundary.
- The existing `/budget` command and goal-run "Improvement Signal" fields already surface Pippy-owned friction for maintainers to act on.
- Automatic self-modification risks cascading config changes that are hard to audit, revert, or understand after the fact.
- Human review ensures improvements are intentional, tested, and consistent with the project's direction.

## Consequences

- The improvement loop stays documented in `docs/agents/pippy-improvement-loop.md` as a human-driven process.
- The "Improvement Signal" field in goal-run reports remains the primary artifact for surfacing Pippy-owned friction.
- Maintainers review Improvement Signals, decide what to change, and edit config/docs directly or via standard PR workflow.
- No new slash command is added to `config/commands/`.
- If the improvement loop proves too slow in practice, the team may revisit with a more constrained approach (e.g., a `/propose-improvement` command that generates a diff for human review, rather than auto-applying changes).

## References

- Pippy improvement loop: `docs/agents/pippy-improvement-loop.md`
- CONTEXT.md — Pippy improvement loop glossary and Improvement Signal definition: `CONTEXT.md`
- `/budget` command: `config/commands/budget.md`
- Goal output format (Improvement Signal field): `config/commands/goal.md`
- ADR-0001: Pippy as Self-Driving Goal Agent — `docs/adr/0001-pippy-goal-self-driving-agent.md`
