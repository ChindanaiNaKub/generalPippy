# ADR-0009: Agentic Engineering Harness Adaptation

Status: accepted

## Context

The agentic-engineering material in `notrelated/newsdlc.md` describes a shift from ad-hoc prompting toward disciplined harness design: context engineering, trajectory evidence, evals, verification rigor, review of AI-generated-code failure modes, observability, and guardrails.

GeneralPippy already has a self-driving loop, context bundles, role-based subagent routing, verification gates, and a human-reviewed improvement loop. The question was whether to adapt the remaining ideas as runtime infrastructure (hooks, telemetry, schedulers, evaluators) or as GeneralPippy harness language, prompts, docs, and validation.

## Decision

Adapt the SDLC ideas as config-only Pippy harness improvements, not runtime infrastructure.

Specifically:

- Define `Pippy harness`, `Goal-run eval suite`, `Verification rigor`, `Review checklist`, `Run evidence`, and `Guardrail candidate` in `CONTEXT.md`.
- Strengthen `/goal` reporting so the existing `Plan` field carries trajectory checkpoints and compact run evidence, without adding a fifth report field.
- Scale acceptance criteria by task risk instead of adding a prototype/production mode flag.
- Add a review checklist for edge cases, error handling, integration assumptions, hallucinated dependencies, and clever-looking generated code.
- Add manual goal-run evals and a Pippy harness inventory doc.
- Treat guardrails as candidates backed by repeated run evidence, not runtime hooks added from generic concern.

Rejected alternatives:

- Do not add runtime telemetry or raw traces.
- Do not add a runtime evaluator or model benchmark harness.
- Do not add OpenCode hook infrastructure for guardrails yet.
- Do not add a new rigor mode flag or command surface.

## Consequences

- Pippy gets more disciplined agentic-engineering behavior while preserving GeneralPippy's config-only invariant.
- Maintainers have shared vocabulary and docs for harness changes without implying a service, telemetry store, scheduler, or automatic self-modification.
- Goal-run reports become more useful for human-reviewed improvement because they include trajectory checkpoints, compact run evidence, and clearer improvement signals.
- The trade-off is that evals and guardrail decisions remain manual for now. Runtime hooks, persistent traces, and automated evaluators can be revisited only if repeated run evidence justifies a specific platform-level commitment.

## References

- Source material: `notrelated/newsdlc.md`
- Pippy harness inventory: `docs/agents/pippy-harness.md`
- Goal-run eval suite: `docs/agents/goal-run-evals.md`
- Pippy improvement loop: `docs/agents/pippy-improvement-loop.md`
- `/goal` command: `config/commands/goal.md`
- Pippy agent prompt: `config/agents/pippy.md`
- Pippy skill: `config/skills/pippy/SKILL.md`
- ADR-0008: `/improve-pippy` command decision
