# ADR-0001: Pippy as Self-Driving Goal Agent

## Status

Accepted

## Context

GeneralPippy v1 was a routing agent — the user described what they wanted, and the orchestrator delegated to the right subagent/model. This worked but still required the user to iterate: describe, review, correct, repeat.

The user wants a **self-driving agent** that takes a verifiable objective, plans it, executes it, verifies each step, and stops only when the objective is met. The agent should require minimal human intervention.

Key constraints:
- OpenCode runs on opencode-go with limited token budgets
- Code navigation is expensive without jcodemunch
- Cheap models can implement; strong models are needed for planning and stuck-step diagnosis
- The agent must degrade gracefully when optional tools are missing

## Decision

Pippy becomes the default agent with a `/goal` command as the primary interface. The self-driving loop replaces manual routing.

### Agent Identity

- Repo stays `generalPippy`
- Default agent: `pippy` (was `orchestrator`)
- Subagents: `pippy-plan` (was `orchestrator-plan`), `pippy-build` (was `orchestrator-build`)
- Skill: `config/skills/pippy/` (was `config/skills/orchestrate/`)

### Command Surface

| Command | Purpose |
|---------|---------|
| `/goal "<objective>"` | Primary self-driving mode — plan, execute, verify, iterate |
| `/ship` | Alias for `/goal "review, verify, and prepare this branch for PR"` |
| `/budget` | Audit budget health and routing behavior |

Removed: `/think`, `/verify`, `/cheap`, `/smart`.

### `/goal` Contract

1. Parse the objective into verifiable acceptance criteria
2. Explore codebase (jcodemunch + rtk)
3. Plan with acceptance criteria and step-by-step breakdown
4. Execute each step, verify after each step
5. On failure: retry up to 3 cheap attempts + 1 strong-model diagnosis
6. Final verification against acceptance criteria
7. Report: done / blocked / partial

### Self-Driving Loop

```
UNDERSTAND → EXPLORE → PLAN → [EXECUTE → VERIFY → RETRY?] → FINAL → REPORT
```

- Max 50 iterations, 30 minutes wall time, 5 consecutive failures → escalate
- Strong model only for: planning, stuck-step diagnosis
- Cheap model for everything else

### YOLO Mode (Default Permissions)

| Category | Behavior |
|----------|----------|
| File reads | Auto-allow |
| File edits (in workspace) | Auto-allow |
| Read-only bash | Auto-allow |
| Destructive bash | Ask first |
| git push/commit | Ask first |
| Dependency installs | Ask first |
| External API/cloud | Ask first |
| Out-of-workspace edits | Ask first |

User can promote any category to permanent auto-allow via `Y` + "always".

### Stop / Escalate Rules

**Stop on success:**
- All acceptance criteria met
- Final verification passes

**Escalate to user:**
- Retries exhausted (3 cheap + 1 strong per step)
- Plan becomes invalid mid-execution
- Gated action needed (git push, destructive bash)
- Domain-doc conflict detected
- Token/time limit hit

**Hard limits:**
- 50 iterations total
- 30 minutes wall time
- 5 consecutive failures

### Token-Efficiency Stack

| Tool | Role |
|------|------|
| jcodemunch-mcp | All code navigation (AST indexing) |
| opencode-dcp | Conversation pruning |
| rtk | Wraps every bash command |
| caveman | Build/verify output (full level) |
| ponytail | Planning constraint — reuse stdlib/existing deps |

### Budget Policy

- Default: cheap model
- Strong model: planning + stuck-step diagnosis only
- Warn at 50k input / 20k output tokens
- Exact tokens and cost are authoritative only when shown by OpenCode's own session usage display
- `/budget` must not estimate spend from conversation volume; it reports routing and efficiency guidance instead

### Operational Defaults

- Dirty workspace: proceed with warning, never auto-commit pre-existing changes
- Branching: work on current branch; branching is user's job

## Consequences

### Positive
- User describes objective once, agent drives to completion
- Minimal manual intervention
- Token-efficient by default
- Graceful degradation when optional tools are missing

### Negative
- Complex internal state machine
- May need tuning for retry limits and time budgets
- YOLO mode reduces safety guardrails (mitigated by category-based permission gates)

### Risks
- Agent may loop without progress (mitigated by hard limits)
- Strong-model diagnosis may be expensive (mitigated by only using it when stuck)
- Optional tool degradation may reduce capability (acceptable — graceful)
