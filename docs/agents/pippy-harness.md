# Pippy Harness

The Pippy harness is the full configuration system around Pippy's models. It is what maintainers tune when improving how `/goal` plans, delegates, verifies, reports, and learns from run evidence. See [ADR-0009](../adr/0009-agentic-engineering-harness-adaptation.md) for the decision to adapt agentic-engineering ideas as config-only harness improvements.

GeneralPippy remains config-only. This inventory names harness components; it does not add runtime services, hooks, schedulers, telemetry stores, or model training.

## Inventory

| Component | Files | What It Controls |
|-----------|-------|------------------|
| Agent prompts | `config/agents/pippy.md`, `config/agents/pippy-plan.md`, `config/agents/pippy-build.md` | Role boundaries, model roles, permissions, self-driving loop behavior, review behavior, and reporting expectations |
| Slash commands | `config/commands/goal.md`, `config/commands/grill-to-goal.md`, `config/commands/ship.md`, `config/commands/budget.md` | User-facing entry points, output contracts, Goal readiness clarification, role usage accounting plus budget guidance, and green-gate PR creation |
| Skills | `config/skills/pippy/SKILL.md`, `config/skills/grill-to-goal/SKILL.md` | Portable `/goal` and `/grill-to-goal` behavior and progressive-disclosure guidance for OpenCode skill loading |
| Cross-run memory | `docs/agents/cross-run-memory.md`, optional project anchors such as `PIPPY_MEMORY.md`, `.pippy/memory.md`, or `docs/agents/pippy-memory.md` | Human-approved lessons recalled before `/goal` planning without adding raw traces, telemetry, or automatic memory writes |
| Context assembly | `config/agents/pippy.md`, `config/skills/pippy/SKILL.md`, `docs/adr/0006-dynamic-subagent-dispatch.md` | Fresh and forked bundles for implementation, retry, review, stuck-step diagnosis, and Program design sketches when present |
| Subagent routing | `config/agents/pippy.md`, `config/agents/pippy-build.md`, `config/agents/pippy-plan.md`, `docs/adr/0002-primary-coordination-boundary.md` | Primary coordination boundary, read-only planning, read-only Program design sketches, implementation delegation, and corrective re-delegation |
| Goal readiness | `config/commands/grill-to-goal.md`, `config/skills/grill-to-goal/SKILL.md`, `config/commands/goal.md`, `config/agents/pippy.md`, `docs/adr/0012-goal-readiness-and-grill-to-goal.md` | Pre-`/goal` clarification for intent, non-goals, constraints, acceptance criteria, verification expectations, and goal-ready prompts |
| Verification gates | `config/commands/goal.md`, `config/agents/pippy.md`, `config/skills/pippy/SKILL.md` | Acceptance criteria, verification rigor, REVIEW, final verification, the review checklist, Program design check, and the Assumption audit |
| Reporting | `config/commands/goal.md`, `config/agents/pippy.md`, `config/skills/pippy/SKILL.md` | Acceptance Criteria, Plan with run evidence including Assumption audit checkpoints, Improvement Signal, and exact Outcome labels |
| Model profiles | `config/model-profiles/balanced.json`, `install.sh`, `docs/adr/0005-model-profiles-and-read-only-advisor-agents.md`, `docs/adr/0013-remove-advisor-adapters.md` | Planning/implementation/system model defaults |
| Installer defaults | `install.sh`, `config/opencode.jsonc`, `config/references/opencode/REFERENCE.md` | Installed OpenCode configuration, backups, profile metadata, and local OpenCode reference packaging |
| Optional efficiency tools | `config/commands/budget.md`, `config/commands/ship.md`, `config/agents/pippy.md`, `config/skills/pippy/SKILL.md` | rtk usage, Caveman mode, context compression hygiene, jcodemunch guidance, and ponytail reuse guidance |
| Goal-run evals | `docs/agents/goal-run-evals.md`, `docs/agents/manual-smoke-tests.md`, `docs/agents/subagent-routing-smoke-test.md`, `docs/agents/caveman-mode-smoke-test.md` | Human-run checks for trajectory, routing, verification, retry behavior, improvement-signal quality, and installed behavior |
| Improvement loop | `docs/agents/pippy-improvement-loop.md`, `CONTEXT.md`, `docs/adr/0008-improve-pippy-command-decision.md` | How run evidence becomes human-reviewed prompt, command, skill, test, or documentation changes |

## Change Rule

When changing the Pippy harness, update the smallest component that owns the behavior:

- Change prompts or skills when the behavior is agent judgment.
- Change commands when the user-facing contract changes.
- Change docs when maintainers need shared language or repeatable evals.
- Change validation when the behavior should not regress.
- Change cross-run memory when a human-approved lesson should guide future runs but is not yet stable enough for prompts, commands, skills, ADRs, or validation.
- Consider an ADR only for hard-to-reverse, surprising trade-offs.

Do not add runtime hooks, schedulers, telemetry stores, or automatic self-modification as harness changes unless a separate decision record accepts that platform-level commitment. The accepted exception is `cc-safety-net`, a reviewed guardrail plugin added per [ADR-0010](../adr/0010-default-cc-safety-net-guardrail-plugin.md).
