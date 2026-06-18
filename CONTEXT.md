# Context: GeneralPippy

## Purpose

GeneralPippy is a configuration package that turns [OpenCode](https://opencode.ai) into a self-driving goal agent. It ships agent prompts, slash commands, skills, and an installer so users can run `/goal "<verifiable objective>"` and have Pippy plan, execute, verify, and iterate until the objective is met.

## Glossary

| Term | Definition |
|------|------------|
| **Agent** | A configured OpenCode role/persona with permissions and instructions. Its model may be supplied by the selected model profile. Pippy is the primary agent; `pippy-plan` and `pippy-build` are subagents. |
| **Advisor agent** | An external AI coding tool that Pippy may ask for read-only plans, critiques, diagnoses, or context summaries while Pippy remains responsible for execution. _Avoid_: external executor, delegated editor |
| **Advisor adapter** | A configured command template that lets Pippy request read-only advice from an advisor agent. _Avoid_: runtime broker, execution adapter |
| **Advisor context bundle** | The Pippy-prepared objective, plan, constraints, and relevant repo context sent to an advisor agent for read-only advice. _Avoid_: full-repo handoff |
| **Acceptance criteria** | Observable conditions that define whether a `/goal` objective or plan step has succeeded. _Avoid_: goal rubric, vague success condition |
| **Assumption audit** | A REVIEW sub-step where Pippy checks every claim it is about to report against an authoritative source, executable evidence, or a concrete scenario. _Avoid_: intuition check, confidence boost |
| **Command** | A slash command registered with OpenCode (e.g., `/goal`, `/ship`, `/budget`). |
| **Budget guidance** | Non-authoritative advice from `/budget` about model routing and token efficiency. Exact token usage and cost belong to OpenCode's own session usage display. |
| **Context compression hygiene** | The budget-guidance practice of closing finished exploration, planning, shipping, or issue-management work into compact summaries before context pressure degrades coordination. _Avoid_: exact token accounting, cost measurement |
| **External trigger recipe** | Documentation that shows how an outside system can invoke `/goal` for recurring or event-driven work while Pippy remains config-only. _Avoid_: built-in scheduler, event runtime |
| **Goal-run eval suite** | A small set of repeatable human-run `/goal` scenarios used to judge Pippy's trajectory, routing, verification, retry behavior, and improvement-signal quality. _Avoid_: runtime evaluator, automated self-test, model benchmark |
| **Goal run report** | The structured final report from a `/goal` run: acceptance criteria, execution plan/log, evidence, outcome, and improvement signal. It is Pippy's first learning artifact for human-reviewed improvement. _Avoid_: raw trace, telemetry store |
| **Goal run state** | The authoritative working state for a `/goal` run, owned by `pippy` while child subagents remain temporary task executors or advisors. _Avoid_: subagent memory, worker-owned state |
| **Guardrail candidate** | A proposed deterministic safety or workflow rule for the Pippy harness, backed by repeated run evidence and reviewed before becoming any runtime hook, script, or platform-specific enforcement. _Avoid_: prompt preference, automatic blocker |
| **Guardrail plugin** | A default platform-level OpenCode plugin that enforces a reviewed deterministic safety rule around Pippy's YOLO mode. _Avoid_: prompt-only guardrail, optional efficiency tool |
| **Flat subagent merge** | The coordination pattern where each child subagent returns results to `pippy`, and `pippy` integrates findings, resolves conflicts, and chooses the next step. _Avoid_: hierarchical worker merge, subagent chain |
| **Improvement signal** | A concise, always-present goal run report field that identifies Pippy-owned friction in prompts, routing, acceptance-criteria shaping, context handling, or verification habits; it may be `None`. _Avoid_: ordinary project failure, automatic patch, model self-training signal |
| **Pippy improvement loop** | The human-reviewed process of using goal run reports to propose better Pippy prompts, tools, acceptance-criteria guidance, or verification habits. _Avoid_: automatic self-modification, prompt auto-rewrite |
| **Pippy harness** | The full configuration system that surrounds Pippy's models: prompts, slash commands, skills, context assembly, subagent routing, verification gates, reporting, installer defaults, and optional efficiency tools. _Avoid_: model, runtime service, raw prompt |
| **Model profile** | A beginner-friendly bundle of model choices for Pippy's planning, implementation, and system-task roles. _Avoid_: hardcoded model, provider lock-in |
| **Primary coordination boundary** | The rule that Pippy coordinates, plans, and verifies while delegating workspace mutation to `pippy-build`. _Avoid_: primary implementation, tiny-edit exception, manager/worker hierarchy |
| **Pippy loop stack** | The product framing for stacking loops around Pippy while keeping GeneralPippy config-only: the self-driving loop, verification feedback, optional external triggering, and human-reviewed improvement from run evidence. _Avoid_: runtime loop engine, built-in scheduler |
| **Review and critique** | Fresh-context inspection of a diff, touched files, acceptance criteria, verification output, and AI-generated-code failure modes before final verification. It produces findings for `pippy-build` to fix but is not a separate agent role. _Avoid_: Critic agent, cheap critic |
| **Review checklist** | The Pippy review heuristic for catching the last-20% failures that shallow tests may miss: edge cases, error handling, integration assumptions, hallucinated dependencies, and clever-looking generated code. _Avoid_: separate reviewer agent, style-only review |
| **Run evidence** | The compact evidence trail included in a goal run report: commands run, verification outputs, routing decisions, retry causes, and final evidence for each acceptance criterion. _Avoid_: raw trace, telemetry store, persistent observability system |
| **Skill** | A reusable instruction card loaded by agent skills (e.g., `pippy`). |
| **OpenCode reference pack** | A packaged local `references/opencode` directory registered as `@opencode-docs`, used when Pippy edits OpenCode config, provider, reference, permission, troubleshooting, or installer behavior. _Avoid_: web-only dependency, hidden prompt memory |
| **Self-driving loop** | The fixed workflow `UNDERSTAND → EXPLORE → PLAN → [EXECUTE → VERIFY → RETRY?] → REVIEW → FINAL → REPORT`. |
| **Verification rigor** | The amount of evidence Pippy requires before reporting success, scaled to task risk during acceptance-criteria shaping. Higher rigor is expected for release prep, auth, security, data loss, installer behavior, permissions, and public docs/config; lightweight evidence is acceptable for low-risk prototype or documentation work. _Avoid_: new mode flag, separate command |
| **YOLO mode** | Default permission mode that auto-allows file reads, subagent routing, unrestricted bash, and implementation edits inside `pippy-build`. Safety comes from scoped agent workflow and reporting, not command approval prompts. |
| **Hard limits** | The safety bounds: 50 iterations, 30 minutes wall time, 5 consecutive failures before escalation. |
| **jcodemunch** | The MCP server that indexes the codebase for token-efficient navigation. |
| **Caveman mode** | An OpenCode prompt/command compression mode that makes Pippy and its subagents communicate tersely while preserving technical accuracy. _Avoid_: caveman CLI, build-output compressor |
| **Caveman CLI** | An optional shell executable named `caveman`, if a user installs one separately. It is not required for Caveman mode. |
| **rtk / ponytail** | Optional efficiency tools: token-compressed bash and stdlib-reuse planning constraint. |

## Invariants

1. **Prompts are the product.** The repo's value is in the agent/command/skill prompts and the installer that places them in `~/.config/opencode/`.
2. **No runtime code.** GeneralPippy does not ship a long-running service; it ships configuration consumed by OpenCode.
3. **Graceful degradation.** Optional tools and modes (rtk, Caveman mode, Caveman CLI, ponytail) improve efficiency but are not required.
4. **Autonomy with scoped reporting.** Auto-allow commands so Pippy can drive without approval friction, but keep work scoped to the objective, route implementation edits to `pippy-build`, and report risky actions clearly.
5. **Versioned backups.** The installer must back up existing user config before overwriting it and must be able to roll back on failure.

## Decisions

See `docs/adr/0001-pippy-goal-self-driving-agent.md` for the original v1→v2 decision.
