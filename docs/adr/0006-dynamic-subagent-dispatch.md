# ADR-0006: Context Bundles and Corrective Re-Delegation

Status: accepted

Pippy will improve subagent dispatch by assembling an explicit context bundle before each Task delegation and by treating failed or misdirected child work as corrective re-delegation, not true mid-run steering. This keeps GeneralPippy inside its current OpenCode primitives: `pippy` coordinates, `pippy-build` mutates the workspace, `pippy-plan` handles planning and stuck-step diagnosis, and the Task tool remains the only dispatch mechanism.

The rejected alternative was to model Pippy after richer multi-agent systems that can message running workers, switch models per invocation, or maintain durable ledgers. Competitors show why those patterns are attractive: Devin can manage child Devins in isolated VMs, Cognition recommends manager/worker patterns with single-threaded writes and clean-context reviewers, Goose exposes ACP-based agent integration, OpenHands Agent Canvas can switch agents and models per conversation, and Magentic-One uses Task and Progress Ledgers for dynamic orchestration. Pippy should learn from those patterns, but it should not pretend OpenCode currently gives Pippy true mid-session steering or per-Task model override.

For each executable plan step, Pippy should decide what context the child receives:

| Scenario | Context mode | Bundle contents |
|----------|--------------|-----------------|
| First implementation attempt | Fresh | Objective, acceptance criteria, relevant file paths, constraints, Program design sketch when present |
| Retry or bug fix | Forked | Fresh bundle plus failure output, prior attempt summary, and relevant discovered context |
| Review or critique | Fresh | Diff, touched files, acceptance criteria, verification command output |
| Stuck-step diagnosis | Forked | Failure history, current plan step, constraints, and ranked code context |

The context bundle is prompt text, not a new runtime subsystem. Pippy may assemble it from `jcodemunch`, previous verification output, and compressed conversation summaries. Caveman mode and `opencode-dcp` remain optional compression aids; absence of either must degrade gracefully.

Dynamic model selection is deferred to ADR-0005's model profile work. Until OpenCode exposes a stable per-Task model override, Pippy will not route complex implementation directly to the strong planning model. Strong models remain reserved for planning, Program design sketches, review, and stuck-step diagnosis; workspace mutation remains delegated to `pippy-build`.

True mid-run steer and queue are also deferred. If a child goes in the wrong direction, Pippy verifies the result, summarizes the correction, and starts a new `pippy-build` delegation with a forked context bundle. This may waste a failed child run, but it preserves the primary coordination boundary and works with today's Task tool.

## Consequences

- Add a "Context Assembly" step between PLAN and EXECUTE in Pippy's prompt and skill instructions.
- Add lightweight step classification language only where it affects context mode and review/diagnosis routing.
- Do not add `context_mode` frontmatter fields that OpenCode ignores.
- Do not add a persistent step manifest yet; revisit only if prompt-level bundles prove insufficient.
- Keep future per-Task model override, true mid-session steering, parallel children, and recipe-style dynamic subagents as deferred platform-dependent work.

## References

- ADR-0001: Pippy as Self-Driving Goal Agent — `docs/adr/0001-pippy-goal-self-driving-agent.md`
- ADR-0002: Primary Coordination Boundary — `docs/adr/0002-primary-coordination-boundary.md`
- ADR-0005: Model Profiles and Read-Only Advisor Agents — `docs/adr/0005-model-profiles-and-read-only-advisor-agents.md`
- Cognition, "Devin can now Manage Devins" — https://cognition.ai/blog/devin-can-now-manage-devins
- Cognition, "Multi-Agents: What's Actually Working" — https://cognition.ai/blog/multi-agents-working
- Goose ACP client docs — https://goose-docs.ai/docs/guides/acp-clients/
- OpenHands Agent Canvas overview — https://docs.openhands.dev/openhands/usage/agent-canvas/overview
- AutoGen Magentic-One docs — https://microsoft.github.io/autogen/stable/user-guide/agentchat-user-guide/magentic-one.html
